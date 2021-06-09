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

sudo userdel -r nomad 1>/dev/null 2>/dev/null
sudo useradd --system --home /etc/nomad.d --shell /bin/false nomad
sudo mkdir --parents /opt/nomad

#----------------------------------------+
# Docker Engine
#----------------------------------------+
sudo apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
echo Y | curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

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
echo nameserver 172.17.0.1 > /etc/resolvconf/resolv.conf.d/tail #docker

sleep 5
systemctl enable dnsmasq
systemctl restart dnsmasq
systemctl status dnsmasq
# important
systemctl restart docker
systemctl status docker

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
# Weave
#----------------------------------------+
mkdir -p /opt/cni/config

cat <<EOF > /opt/cni/config/10-weave.conflist
{
	"cniVersion": "0.3.0",
	"name": "weave",
	"plugins": [
		{
      "name": "weave",
			"type": "weave-net"
		}
	]
}

EOF

#----------------------------------------+
# Configure and start
#----------------------------------------+
sudo touch /etc/systemd/system/nomad.service
sudo cat <<EOF > /etc/systemd/system/nomad.service
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs
Wants=network-online.target
After=network-online.target

[Service]
ExecReload=/bin/kill -HUP $MAINPID
#ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d -network-interface ens10
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d
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

# assemble nomad leaders
retry_cluster=""
num_nomad_leader="$(cat $CONFIG | yq eval '.Nomad.Leader | length' -)"
for ((i=0;i<=$num_nomad_leader-2;i++)); do
    addr="$(cat $CONFIG | yq eval ".Nomad.Leader.$i.InternalAddr" -)"
    retry_cluster="${retry_cluster},${addr}:4647,"
done
addr="$(cat $CONFIG | yq eval ".Nomad.Leader.$((num_nomad_leader-1)).InternalAddr" -)"
retry_cluster="${retry_cluster}${addr}:4647"

address_internal="$(cat $CONFIG | yq eval ".Nomad.Follower.${1}.InternalAddr" -)"

cat <<EOF > /etc/nomad.d/client.hcl
# Increase log verbosity
log_level = "DEBUG"

# Setup data dir
data_dir = "/opt/$DATACENTER"

# Enable the client
client {
  enabled = true
  # cni config
  cni_config_dir = "/opt/cni/config"
  servers = ["$retry_cluster"]
  #network_interface = "ens10"
  options = {
    docker.privileged.enabled = true
    docker.volumes.enabled = true 
  }
}

# NOT optional
advertise {
  # Defaults to the first private IP address.
  http = "$address_internal"
  rpc  = "$address_internal"
  serf = "$address_internal" 
}

ports {
  http = 5656
}

# Require TLS
tls {
  http = true
  rpc  = true

  ca_file   = "/opt/nomad/nomad-ca.pem"
  cert_file = "/opt/nomad/client.pem"
  key_file  = "/opt/nomad/client-key.pem"

  verify_server_hostname = true
  verify_https_client    = true
}
EOF

mv /tmp/nomad-ca.pem /opt/nomad/nomad-ca.pem
mv /tmp/client.pem /opt/nomad/client.pem
mv /tmp/client-key.pem /opt/nomad/client-key.pem

sudo systemctl enable nomad
sudo systemctl start nomad
sudo systemctl status nomad
