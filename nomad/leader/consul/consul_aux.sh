# This file is to be executed inside a remote machine
# -------------------+
# PARAMS
# 1 consul key
# 2 node index
# -------------------+

CONFIG="/tmp/config.yml"
CONSUL_URL="$(cat $CONFIG | yq eval ".Nomad.Components.Consul.Repo" -)"
CONSUL_VERSION="$(cat $CONFIG | yq eval ".Nomad.Components.Consul.Version" -)"
DATACENTER="$(cat $CONFIG | yq eval ".Nomad.Datacenter" -)"

curl --silent --remote-name \
  ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip

unzip consul_${CONSUL_VERSION}_linux_amd64.zip
sudo chown root:root consul
sudo mv consul /usr/bin/
consul --version
sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo chown --recursive consul:consul /opt/consul
sudo mkdir --parents /etc/consul.d
sudo touch /etc/consul.d/consul.hcl
sudo chown --recursive consul:consul /etc/consul.d
sudo chmod 640 /etc/consul.d/consul.hcl
sudo mv /tmp/consul-agent-ca.pem /etc/consul.d/
sudo mv /tmp/$DATACENTER-client-consul.pem /etc/consul.d/
sudo mv /tmp/$DATACENTER-client-consul-key.pem /etc/consul.d/

# assemble consul leaders
retry_cluster=""
num_consul_leader="$(cat $CONFIG | yq eval '.Consul.Leader | length' -)"
for ((i=0;i<=$num_consul_leader-2;i++)); do
    addr="$(cat $CONFIG | yq eval ".Consul.Leader.$i.InternalAddr" -)"
    retry_cluster="${retry_cluster},${addr},"
done
addr="$(cat $CONFIG | yq eval ".Consul.Leader.$((num_consul_leader-1)).InternalAddr" -)"
retry_cluster="${retry_cluster}${addr}"

# internal ad addr
internal_addr="$(cat $CONFIG | yq eval ".Nomad.Leader.${2}.InternalAddr" -)"

cat <<EOF > /etc/consul.d/consul.hcl
datacenter = "$DATACENTER"
data_dir = "/tmp/consul"
encrypt = "${1}"
ca_file = "/etc/consul.d/consul-agent-ca.pem"
cert_file = "/etc/consul.d/$DATACENTER-client-consul.pem"
key_file = "/etc/consul.d/$DATACENTER-client-consul-key.pem"
verify_incoming = true
verify_outgoing = true
verify_server_hostname = true

encrypt_verify_incoming = true
encrypt_verify_outgoing = true

performance {
  raft_multiplier = 1
}

ports {
  grpc = 8502
}

connect {
  enabled = true
}

bind_addr = ["0.0.0.0"]
retry_join = ["$retry_cluster"]

EOF

sudo touch /usr/lib/systemd/system/consul.service
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
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/ -advertise=$internal_addr 
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target

EOF

sudo chown --recursive consul:consul /etc/consul.d
consul validate /etc/consul.d/consul.hcl
sudo systemctl enable consul
sudo systemctl start consul
sudo systemctl status consul
