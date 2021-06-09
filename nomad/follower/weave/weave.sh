DEBUG=1
CONFIG="../../../config.yml"

num_nomad_follower="$(cat $CONFIG | yq eval '.Nomad.Follower | length' -)"

function clear_logs {
    rm -rf *.txt
}

function install {
    user="$1"
    addr="$2"
    node_idx="$3"
    printf '%-25s: %-35s\n' "Installing on" "$user@$addr Standby..."
    ssh -o StrictHostKeychecking=no -o BatchMode=yes \
        $user@$addr "bash -s" < weave_aux.sh "$node_idx" \
        > weave_$user@$addr.txt 2>&1
    printf '%-25s: %-35s\n' "Installing on" "$user@$addr DONE!"
    if [ $DEBUG -eq 0 ]; then
        rm -rf "weave_$user@$addr.txt"
    fi
}

function install_all {
    for ((i=0;i<=$num_nomad_follower-1;i++)); do
        (
            user="$(cat $CONFIG | yq eval ".Nomad.Follower.$i.User" -)"
            addr="$(cat $CONFIG | yq eval ".Nomad.Follower.$i.Addr" -)"
            scp -q -o StrictHostKeychecking=no $CONFIG $user@$addr:/tmp/config.yml
            install "$user" "$addr" "$i"
        ) & 
    done
    wait
}

function main {
    clear_logs
    printf "\nInstalling weave net on nomad followers...\n"
    install_all
    printf "Done!\n"
}

main
