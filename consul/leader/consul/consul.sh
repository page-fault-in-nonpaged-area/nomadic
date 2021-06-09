DEBUG=0
CONFIG="../../../config.yml"
OUTPUT="../../../output/consul/"

num_consul_leader="$(cat $CONFIG | yq eval '.Consul.Leader | length' -)"

function clear_logs {
    rm -rf *.txt
}

function abs_path {
  (cd "$(dirname '$1')" &>/dev/null && printf "%s/%s" "$PWD" "${1##*/}")
}

function install {
    user="$1"
    addr="$2"
    kind="$3"
    printf '%-25s: %-35s\n' "Installing on" "$user@$addr Standby..."
    ssh -o StrictHostKeychecking=no -o BatchMode=yes $user@$addr "bash -s" < consul_aux.sh > consul_$user@$addr.txt 2>&1
    printf '%-25s: %-35s\n' "installing on" "$user@$addr DONE!"
    if [ $DEBUG -eq 0 ]; then
        rm -rf "consul_$user@$addr.txt"
    fi
}

function clean {
    user="$1"
    addr="$2"
    printf '%-25s: %-35s\n' "Cleaning" "$user@$addr Standby..."
    ssh -o StrictHostKeychecking=no -o BatchMode=yes $user@$addr "bash -s" < consul_aux_clean.sh > /dev/null 2>&1
    printf '%-25s: %-35s\n' "Cleaning" "$user@$addr DONE!"
}

function install_all {
    for ((i=0;i<=$num_consul_leader-1;i++)); do
    (
        user="$(cat $CONFIG | yq eval ".Consul.Leader.$i.User" -)"
        addr="$(cat $CONFIG | yq eval ".Consul.Leader.$i.Addr" -)"
        scp -q -o StrictHostKeychecking=no $CONFIG $user@$addr:/tmp/config.yml
        install "$user" "$addr" "consul leader" 
        # Todo: multiple hosts
        scp -q -r -o StrictHostKeychecking=no $user@$addr:consul_output $OUTPUT
    ) & 
    done
    wait
}

function clean_all {
    for ((i=0;i<=$num_consul_leader-1;i++)); do
    (
        user="$(cat $CONFIG | yq eval ".Consul.Leader.$i.User" -)"
        addr="$(cat $CONFIG | yq eval ".Consul.Leader.$i.Addr" -)"
        clean "$user" "$addr" 
    ) & 
    done
    wait
}

function main {
    clear_logs
    printf "\nInstalling consul leaders...\n"
    install_all
    clean_all
    printf "Done!\n"
    #printf "\nConsul certs and keys are in $(abs_path $OUTPUT)\n"
}

main

