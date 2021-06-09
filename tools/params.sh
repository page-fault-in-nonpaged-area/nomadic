# This script makes nomad useful in your .bashrc

CONFIG="config.yml" # change as needed 
address="$(cat $CONFIG | yq eval ".Nomad.Leader.0.Addr" -)"
NOMAD_OUTPUT="$(pwd)/output/nomad/nomad_output" # change as needed
export NOMAD_ADDR=https://$address:4646
export NOMAD_CACERT=$NOMAD_OUTPUT/nomad-ca.pem
export NOMAD_CLIENT_CERT=$NOMAD_OUTPUT/cli.pem
export NOMAD_CLIENT_KEY=$NOMAD_OUTPUT/cli-key.pem

alias n='nomad'
alias njr='nomad run'
alias njx='nomad stop'
alias njs='nomad job status'
alias njsv='nomad job status --verbose'
alias nas='nomad alloc status'
alias nasv='nomad alloc status --verbose'
alias naex='nomad alloc exec'
alias nal='nomad alloc logs'
