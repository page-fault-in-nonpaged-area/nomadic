DEBUG=1
CONFIG="../../../config.yml"
OUTPUT_NOMAD="../../../output/nomad/nomad_output"

DATACENTER="$(cat $CONFIG | yq eval ".Nomad.Datacenter" -)"
num_nomad_follower="$(cat $CONFIG | yq eval '.Nomad.Follower | length' -)"

function clear_logs {
    rm -rf *.txt
}

function abs_path {
  (cd "$(dirname '$1')" &>/dev/null && printf "%s/%s" "$PWD" "${1##*/}")
}

function clean {
    user="$1"
    addr="$2"
    printf '%-25s: %-35s\n' "Cleaning:" "$user@$addr Standby..."
    ssh -o StrictHostKeychecking=no -o BatchMode=yes $user@$addr "bash -s" < nomad_aux_clean.sh > /dev/null 2>&1
    printf '%-25s: %-35s\n' "Cleaning:" "$user@$addr DONE!"
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
        $user@$addr "bash -s" < nomad_aux.sh "$node_idx" \
        > nomad_$user@$addr.txt 2>&1
    printf '%-25s: %-35s\n' "Installing on" "$user@$addr DONE!"
    if [ $DEBUG -eq 0 ]; then
        rm -rf "nomad_$user@$addr.txt"
    fi
}

function install_all {
    for ((i=0;i<=$num_nomad_follower-1;i++)); do
        (
            user="$(cat $CONFIG | yq eval ".Nomad.Follower.$i.User" -)"
            addr="$(cat $CONFIG | yq eval ".Nomad.Follower.$i.Addr" -)"
            scp -q -o StrictHostKeychecking=no $CONFIG $user@$addr:/tmp/config.yml
            scp -q -o StrictHostKeychecking=no $OUTPUT_NOMAD/nomad-ca.pem $user@$addr:/tmp/nomad-ca.pem
            scp -q -o StrictHostKeychecking=no $OUTPUT_NOMAD/client$i.pem $user@$addr:/tmp/client.pem
            scp -q -o StrictHostKeychecking=no $OUTPUT_NOMAD/client$i-key.pem $user@$addr:/tmp/client-key.pem
            install "$user" "$addr" "$i"
        ) & 
    done
    wait
}

function main {
    clear_logs
    printf "\nInstalling nomad followers...\n"
    install_all
    clean_all
    printf "Done!\n"
    #printf "\nNomad certs and keys are in $(abs_path $OUTPUT_NOMAD)\n"
}

main
