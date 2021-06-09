# -------------------+
# PARAMS
# 1 node index
# -------------------+

CONFIG="/tmp/config.yml"
NOMAD_URL="$(cat $CONFIG | yq eval '.Nomad.Components.Nomad.Repo' -)"
NOMAD_VERSION="$(cat $CONFIG | yq eval '.Nomad.Components.Nomad.Version' -)"
DATACENTER="$(cat $CONFIG | yq eval ".Nomad.Datacenter" -)"

curl --silent --remote-name \
  ${NOMAD_URL}/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip

unzip nomad_${NOMAD_VERSION}_linux_amd64.zip
sudo chown root:root nomad
sudo mv nomad /usr/local/bin/
nomad --version
sudo useradd --system --home /etc/nomad.d --shell /bin/false nomad
sudo mkdir --parents /opt/nomad
mkdir -p nomad_output
mkdir -p /etc/dnsmasq.d
sudo apt-get install -y golang-cfssl

#----------------------------------------+
# Consul DNS
#----------------------------------------+

# will attempt to start instantly after install
{
apt-get install -qq -y dnsmasq
} > /dev/null 2>&1

sudo systemctl stop systemd-resolved
cat <<EOF > /etc/dnsmasq.d/10-consul
server=/consul/127.0.0.1#8600
EOF

# ORDER IS IMPORTANT
echo nameserver 127.0.0.1 >> /etc/resolv.conf 
echo nameserver 8.8.8.8 >> /etc/resolv.conf
mkdir -p /etc/resolvconf/resolv.conf.d/
echo nameserver 172.17.0.1 > /etc/resolvconf/resolv.conf.d/tail

sleep 5
systemctl enable dnsmasq
systemctl restart dnsmasq
systemctl status dnsmasq

#----------------------------------------+
# Consul Connect + CNI
#----------------------------------------+
CNI_URL="$(cat $CONFIG | yq eval '.Nomad.Components.Containernetworking.Repo' -)"
CNI_VERSION="$(cat $CONFIG | yq eval '.Nomad.Components.Containernetworking.Version' -)"
curl -L -o cni-plugins.tgz "$CNI_URL/v$CNI_VERSION/cni-plugins-linux-$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)"-v$CNI_VERSION.tgz
sudo mkdir -p /opt/cni/bin
sudo mkdir -p /proc/sys/net/bridge/
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz

echo 1 > /proc/sys/net/bridge/bridge-nf-call-arptables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables

rm -rf /etc/sysctl.d/10-tables.conf
echo net.bridge.bridge-nf-call-arptables = 1 >> /etc/sysctl.d/10-tables.conf
echo net.bridge.bridge-nf-call-ip6tables = 1 >> /etc/sysctl.d/10-tables.conf
echo net.bridge.bridge-nf-call-iptables = 1 >> /etc/sysctl.d/10-tables.conf

#----------------------------------------+
# Nomad TLS
# https://learn.hashicorp.com/tutorials/nomad/security-enable-tls
#----------------------------------------+
# TODO: will be completely different for multi-leader
mkdir -p ./nomad_output
cfssl print-defaults csr | cfssl gencert -initca - | cfssljson -bare nomad-ca
cat <<EOF > cfssl.json
{
  "signing": {
    "default": {
      "expiry": "87600h",
      "usages": ["signing", "key encipherment", "server auth", "client auth"]
    }
  }
}

EOF

address="$(cat $CONFIG | yq eval ".Nomad.Leader.${1}.Addr" -)"
address_internal="$(cat $CONFIG | yq eval ".Nomad.Leader.${1}.InternalAddr" -)"

echo "Generating leader certs for $address | $address_internal"
echo '{}' | cfssl gencert -ca=nomad-ca.pem -ca-key=nomad-ca-key.pem -config=cfssl.json \
    -hostname="server.global.nomad,localhost,127.0.0.1,$address,$address_internal" - | cfssljson -bare server${1}

num_nomad_follower="$(cat $CONFIG | yq eval '.Nomad.Follower | length' -)"
for ((i=0;i<=$num_nomad_follower-1;i++)); do
    f_address="$(cat $CONFIG | yq eval ".Nomad.Follower.$i.Addr" -)"
    f_address_internal="$(cat $CONFIG | yq eval ".Nomad.Follower.$i.InternalAddr" -)"
    echo "Generating follower $i certs for $f_address"
    echo '{}' | cfssl gencert -ca=nomad-ca.pem -ca-key=nomad-ca-key.pem -config=cfssl.json \
        -hostname="client.global.nomad,localhost,127.0.0.1,$f_address,$f_address_internal" - | cfssljson -bare client$i
done
wait

echo "Generating CLI certs..."
echo '{}' | cfssl gencert -ca=nomad-ca.pem -ca-key=nomad-ca-key.pem -profile=client - | cfssljson -bare cli

mv nomad-ca.csr ./nomad_output/
mv nomad-ca-key.pem ./nomad_output/
mv nomad-ca.pem ./nomad_output/
mv client*.pem ./nomad_output/
mv client*.csr ./nomad_output/
mv server*.pem ./nomad_output/
mv server*.csr ./nomad_output/
mv cli*.pem ./nomad_output/
mv cli*.csr ./nomad_output/

#----------------------------------------+
# Configure and start
#----------------------------------------+
echo "Configuring nomad leader..."

sudo touch /etc/systemd/system/nomad.service
sudo cat <<EOF > /etc/systemd/system/nomad.service
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs
Wants=network-online.target
After=network-online.target

[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d -network-interface ens10
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
StartLimitBurst=3
StartLimitIntervalSec=10
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF

sudo mkdir --parents /etc/nomad.d
sudo chmod 700 /etc/nomad.d

sudo touch /etc/nomad.d/nomad.hcl
cat <<EOF > /etc/nomad.d/nomad.hcl
datacenter = "$DATACENTER"
data_dir = "/opt/nomad"
EOF

sudo touch /etc/nomad.d/server.hcl
cat <<EOF > /etc/nomad.d/server.hcl
# Increase log verbosity
log_level = "DEBUG"

# Setup data dir
data_dir = "/opt/$DATACENTER"

# Enable the server
server {
  enabled = true

  # Self-elect, set to 3 or 5 for production
  bootstrap_expect = 1
}

advertise {
  # Defaults to the first private IP address.
  http = "$address_internal"
  rpc  = "$address_internal"
  serf = "$address_internal" 
}

# Require TLS
tls {
  http = true
  rpc  = true

  ca_file   = "/opt/nomad/nomad-ca.pem"
  cert_file = "/opt/nomad/server.pem"
  key_file  = "/opt/nomad/server-key.pem"

  verify_server_hostname = true
  verify_https_client    = true
}
EOF

cp ./nomad_output/nomad-ca.pem /opt/nomad/nomad-ca.pem
cp ./nomad_output/server${1}.pem /opt/nomad/server.pem
cp ./nomad_output/server${1}-key.pem /opt/nomad/server-key.pem

sudo systemctl enable nomad
sudo systemctl start nomad
sudo systemctl status nomad
