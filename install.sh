CONFIG="config.yml"

function main {
    (cd bootstrap && ./bootstrap.sh); sleep 3
    (cd consul/leader/consul && ./consul.sh); sleep 1
    (cd nomad/leader/consul && ./consul.sh); sleep 1
    (cd nomad/leader/nomad && ./nomad.sh); sleep 1
    (cd nomad/follower/consul && ./consul.sh); sleep 1
    (cd nomad/follower/nomad && ./nomad.sh); sleep 1
    (cd nomad/follower/weave && ./weave.sh); sleep 1
}

function download_ui {
    echo 1
}

function notice {

    printf "\n"
    address="$(cat $CONFIG | yq eval ".Consul.Leader.0.Addr" -)"
    printf +
    printf %32s |tr " " "-"
    printf +
    printf "\n|\tInstallation Done!\t |\n"
    printf +
    printf %32s |tr " " "-"
    printf +
    printf '\n\n%35s: %-35s\n' "Consul certs and keys are under" "$(pwd)/output/consul/consul_output"
    printf '%35s: %-35s\n\n' "Nomad certs and keys are under" "$(pwd)/output/nomad/nomad_output"
    printf '%-42s: %-35s\n' "+ To start Nomad UI on global namespace" "simply run ui.sh"
    printf '%-42s: %-35s\n\n' "+ To start Nomad UI on a taget namespace" "simply run ui.sh <namespace>"
    printf '%-28s: %-35s\n' "+ Consul UI is available at" "http://$address:8500"
    printf '%-28s: %-35s\n\n' "+ Nomad UI is available at" "http://localhost:3000"
}

main
notice
