# This script is used to incrementally build and debug nomadic
# Take snapshot of cluster

declare -a machines=(
    "consul-leader-0"
    "nomad-leader-0" 
    "nomad-worker-0"
    "nomad-worker-1"
    "nomad-worker-2"
)

function snap {
    printf "%s\n\n" "Snapping..."
    for i in "${machines[@]}"; do 
        sleep 1
        (
            hcloud server create-image --type snapshot --description "$i" "$i" 
        ) & 
    done
    wait
    sleep 2
}

snap