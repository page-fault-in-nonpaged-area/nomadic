# This file is to be executed inside a remote machine
CONFIG="/tmp/config.yml"

CONSUL_URL="$(cat $CONFIG | yq eval ".Consul.Components.Consul.Repo" -)"
CONSUL_VERSION="$(cat $CONFIG | yq eval ".Consul.Components.Consul.Version" -)"
DATACENTER="$(cat $CONFIG | yq eval ".Consul.Datacenter" -)"

#------------------------------------------------+
# Stage 1: install & certs
#------------------------------------------------+

curl --silent --remote-name \
  ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip

unzip consul_${CONSUL_VERSION}_linux_amd64.zip
sudo chown root:root consul
sudo mv consul /usr/bin/
consul --version

# User
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo chown --recursive consul:consul /opt/consul

# Main output folder
mkdir -p consul_output

# Key
consul keygen > consul_key

# CA cert
consul tls ca create

# 1 to n instances of server certs
consul tls cert create -server -dc $DATACENTER

# 1 to n instances of consul client certs
num_nomad_leader="$(cat $CONFIG | yq eval '.Nomad.Leader | length' -)"
num_nomad_follower="$(cat $CONFIG | yq eval '.Nomad.Follower | length' -)"
num_total_certs=$((num_nomad_leader + num_nomad_follower))

for (( i=0; i<$num_total_certs; ++i)); do
    consul tls cert create -client -dc $DATACENTER
done

mv -f consul-agent-ca.pem ./consul_output/
mv -f consul-agent-ca-key.pem ./consul_output/
mv -f $DATACENTER-server-consul*.pem ./consul_output/
mv -f $DATACENTER-client-consul*.pem ./consul_output/
mv consul_key ./consul_output/

sudo mkdir --parents /etc/consul.d

#------------------------------------------------+
# Stage 2: etc & run
#------------------------------------------------+

cp ./consul_output/consul-agent-ca.pem /etc/consul.d/
cp ./consul_output/$DATACENTER-server-consul-0.pem /etc/consul.d/
cp ./consul_output/$DATACENTER-server-consul-0-key.pem /etc/consul.d/

consul_key="$(cat ./consul_output/consul_key)"

sudo touch /etc/consul.d/consul.hcl
sudo chown --recursive consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/consul.hcl

# /etc/consul.d/consul.hcl
cat <<EOF > /etc/consul.d/consul.hcl
datacenter = "$DATACENTER"
data_dir = "/tmp/consul"
encrypt = "${consul_key}"
ca_file = "/etc/consul.d/consul-agent-ca.pem"
cert_file = "/etc/consul.d/$DATACENTER-server-consul-0.pem"
key_file = "/etc/consul.d/$DATACENTER-server-consul-0-key.pem"
verify_incoming = true
verify_outgoing = true
verify_server_hostname = true

performance {
  raft_multiplier = 1
}

EOF

# /etc/consul.d/server.hcl
cat <<EOF > /etc/consul.d/server.hcl

datacenter = "$DATACENTER"
data_dir = "/tmp/consul"
server = true
bootstrap_expect = 1
retry_join = ["127.0.0.1"]
bind_addr = "0.0.0.0"
node_name = "master"
client_addr = "0.0.0.0"


ui_config {
  enabled = true
}

acl = {
  enabled = true
  default_policy = "allow"
  enable_token_persistence = true
}

ports {
  grpc = 8502
}

connect {
  enabled = true
}

EOF

cat /etc/consul.d/server.hcl
cat /etc/consul.d/consul.hcl

sudo touch /usr/lib/systemd/system/consul.service
# /usr/lib/systemd/system/consul.service
sudo cat <<EOF > /usr/lib/systemd/system/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target

EOF

sudo chown --recursive consul:consul /etc/consul.d
consul validate /etc/consul.d/server.hcl
consul validate /etc/consul.d/consul.hcl

sudo systemctl enable consul
sudo systemctl start consul
sudo systemctl status consul
sleep 5

#------------------------------------------------+
# Stage 3: management tokens
#------------------------------------------------+

consul acl bootstrap > bootstrap.txt
cat <<EOF > node-policy.hcl
agent_prefix "" {
  policy = "write"
}
node_prefix "" {
  policy = "write"
}
service_prefix "" {
  policy = "read"
}
session_prefix "" {
  policy = "read"
}
EOF

CONSUL_MGMT_TOKEN="$(cat bootstrap.txt | grep SecretID | awk '{ print $2}')"

consul acl policy create \
  -token=${CONSUL_MGMT_TOKEN} \
  -name node-policy \
  -rules @node-policy.hcl

consul acl token create \
  -token=${CONSUL_MGMT_TOKEN} \
  -description "node token" \
  -policy-name node-policy > nodetoken.txt

mv nodetoken.txt ./consul_output/
mv bootstrap.txt ./consul_output/
