DEBUG=1
CONFIG="../../../config.yml"
OUTPUT_CONSUL="../../../output/consul/consul_output"

DATACENTER="$(cat $CONFIG | yq eval ".Nomad.Datacenter" -)"
num_nomad_leader="$(cat $CONFIG | yq eval '.Nomad.Leader | length' -)"
num_nomad_follower="$(cat $CONFIG | yq eval '.Nomad.Follower | length' -)"
consul_masterkey="$(cat $OUTPUT_CONSUL/consul_key)"

function clear_logs {
    rm -rf *.txt
}

function clean {
    user="$1"
    addr="$2"
    printf '%-25s: %-35s\n' "Cleaning" "$user@$addr Standby..."
    ssh -o StrictHostKeychecking=no -o BatchMode=yes $user@$addr "bash -s" < consul_aux_clean.sh > /dev/null 2>&1
    printf '%-25s: %-35s\n' "Cleaning" "$user@$addr DONE!"
}

function clean_all {
    for ((i=0;i<=$num_nomad_follower-1;i++)); do
    (
        user="$(cat $CONFIG | yq eval ".Nomad.Follower.$i.User" -)"
        addr="$(cat $CONFIG | yq eval ".Nomad.Follower.$i.Addr" -)"
        clean "$user" "$addr" 
    ) & 
    done
    wait
}

function install {
    user="$1"
    addr="$2"
    node_idx="$3"
    printf '%-25s: %-35s\n' "Installing on" "$user@$addr Standby..."
    ssh -o StrictHostKeychecking=no -o BatchMode=yes \
        $user@$addr "bash -s" < consul_aux.sh "$consul_masterkey" "$node_idx" \
        > consul_$user@$addr.txt 2>&1
    printf '%-25s: %-35s\n' "Installing on" "$user@$addr DONE!"
    if [ $DEBUG -eq 0 ]; then
        rm -rf "consul_$user@$addr.txt"
    fi
}

function install_all {
    for ((i=0;i<=$num_nomad_follower-1;i++)); do
        (
            user="$(cat $CONFIG | yq eval ".Nomad.Follower.$i.User" -)"
            addr="$(cat $CONFIG | yq eval ".Nomad.Follower.$i.Addr" -)"
            scp -q -o StrictHostKeychecking=no $CONFIG $user@$addr:/tmp/config.yml
            scp -q -o StrictHostKeychecking=no $OUTPUT_CONSUL/consul-agent-ca.pem $user@$addr:/tmp/consul-agent-ca.pem
            scp -q -o StrictHostKeychecking=no $OUTPUT_CONSUL/$DATACENTER-client-consul-$((i+num_nomad_leader)).pem $user@$addr:/tmp/$DATACENTER-client-consul.pem
            scp -q -o StrictHostKeychecking=no $OUTPUT_CONSUL/$DATACENTER-client-consul-$((i+num_nomad_leader))-key.pem $user@$addr:/tmp/$DATACENTER-client-consul-key.pem
            install "$user" "$addr" "$i"
        ) & 
    done
    wait
}

function main {
    clear_logs
    printf "\nInstalling consul client on nomad followers...\n"
    install_all
    clean_all
    printf "Done!\n"
}

main
