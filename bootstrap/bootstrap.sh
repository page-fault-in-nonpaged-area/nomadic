DEBUG=0
CONFIG="../config.yml"

num_consul_leader="$(cat $CONFIG | yq eval '.Consul.Leader | length' -)"
num_nomad_leader="$(cat $CONFIG | yq eval '.Nomad.Leader | length' -)"
num_nomad_follower="$(cat $CONFIG | yq eval '.Nomad.Follower | length' -)"

function info {
    printf '%-20s: %-15s\n' "Consul Leaders" "$num_consul_leader"
    printf '%-20s: %-15s\n' "Consul Followers" "0"
    printf '%-20s: %-15s\n' "Nomad Leaders" "$num_nomad_leader"
    printf '%-20s: %-15s\n\n' "Nomad followers" "$num_nomad_follower"
}

function clear_logs {
    rm -rf *.txt
}

function strap {
    user="$1"
    addr="$2"
    kind="$3"
    printf '%-25s: %-35s\n' "Strapping $kind" "$user@$addr Standby..."
    ssh -o StrictHostKeychecking=no -o BatchMode=yes $user@$addr "bash -s" < bootstrap_aux.sh > strap_$user@$addr.txt 2>&1
    printf '%-25s: %-35s\n' "Strapped $kind" "$user@$addr DONE!"
    if [ $DEBUG -eq 0 ]; then
        rm -rf "strap_$user@$addr.txt"
    fi
}

function bootstrap_consul_leader {
    for ((i=0;i<=$num_consul_leader-1;i++)); do
        (
            user="$(cat $CONFIG | yq eval ".Consul.Leader.$i.User" -)"
            addr="$(cat $CONFIG | yq eval ".Consul.Leader.$i.Addr" -)"
            strap "$user" "$addr" "consul leader" 
        ) & 
    done
    wait
}

function bootstrap_nomad_leader {
    for ((i=0;i<=$num_nomad_leader-1;i++)); do
        (
            user="$(cat $CONFIG | yq eval ".Nomad.Leader.$i.User" -)"
            addr="$(cat $CONFIG | yq eval ".Nomad.Leader.$i.Addr" -)"
            strap "$user" "$addr" "nomad leader" 
        ) & 
    done
    wait
}

function bootstrap_nomad_follower {
    for ((i=0;i<=$num_nomad_follower-1;i++)); do
        (
            user="$(cat $CONFIG | yq eval ".Nomad.Follower.$i.User" -)"
            addr="$(cat $CONFIG | yq eval ".Nomad.Follower.$i.Addr" -)"
            strap "$user" "$addr" "nomad follower" 
        ) & 
    done
    wait
}

function main {
    ./hcloud/hcloud.sh
    printf "\n"
    sleep 20 # give time for vm to boot
    clear_logs
    bootstrap_consul_leader &
    bootstrap_nomad_leader &
    bootstrap_nomad_follower &
    wait
}

main
