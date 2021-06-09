DEBUG=1
CONFIG="../../../config.yml"
OUTPUT_NOMAD="../../../output/nomad/"

DATACENTER="$(cat $CONFIG | yq eval ".Nomad.Datacenter" -)"
num_nomad_leader="$(cat $CONFIG | yq eval '.Nomad.Leader | length' -)"

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
    for ((i=0;i<=$num_nomad_leader-1;i++)); do
    (
        user="$(cat $CONFIG | yq eval ".Nomad.Leader.$i.User" -)"
        addr="$(cat $CONFIG | yq eval ".Nomad.Leader.$i.Addr" -)"
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
    for ((i=0;i<=$num_nomad_leader-1;i++)); do
        (
            user="$(cat $CONFIG | yq eval ".Nomad.Leader.$i.User" -)"
            addr="$(cat $CONFIG | yq eval ".Nomad.Leader.$i.Addr" -)"
            scp -q -o StrictHostKeychecking=no $CONFIG $user@$addr:/tmp/config.yml
            install "$user" "$addr" "$i"
            # Todo: multiple hosts
            scp -q -r -o StrictHostKeychecking=no $user@$addr:nomad_output $OUTPUT_NOMAD
        ) & 
    done
    wait
}

function main {
    clear_logs
    printf "\nInstalling nomad leaders...\n"
    install_all
    clean_all
    printf "Done!\n"
    #printf "\nNomad certs and keys are in $(abs_path $OUTPUT_NOMAD)\n"
}

main
