CONFIG="config.yml"

if [ -n "$1" ]; then
    export NOMAD_NAMESPACE=${1}
fi

NOMAD_OUTPUT="$(pwd)/output/nomad/nomad_output"
export NOMAD_CACERT="$NOMAD_OUTPUT/nomad-ca.pem"

function download_ui {
    if [ "$(uname)" == "Darwin" ]; then
        wget -q https://github.com/jippi/hashi-ui/releases/download/v1.3.8/hashi-ui-darwin-amd64 -O hui
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        wget -q https://github.com/jippi/hashi-ui/releases/download/v1.3.8/hashi-ui-linux-amd64 -O hui
    fi
    chmod +x hui
}

funtction main {

    kill -9 $(lsof -i:3000 -t) 2> /dev/null
    printf "\n"
    printf +
    printf %58s |tr " " "-"
    printf +
    printf "\n|  Powered By Hashi-UI: https://github.com/jippi/hashi-ui  |\n"
    printf +
    printf %58s |tr " " "-"
    printf +
    printf "\n\n"

    address="$(cat $CONFIG | yq eval ".Nomad.Leader.0.Addr" -)"
    ./hui --nomad-enable --nomad-address https://$address:4646 --nomad-client-cert $NOMAD_OUTPUT/cli.pem --nomad-client-key $NOMAD_OUTPUT/cli-key.pem
}
