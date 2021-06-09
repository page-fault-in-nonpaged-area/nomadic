# This script is used to incrementally build and debug nomadic
# restores cluster to previously captured state

declare -a machines=(
    "consul-leader-0"
    "nomad-leader-0" 
    "nomad-worker-0"
    "nomad-worker-1"
    "nomad-worker-2"
)

declare -a images=(
    "39820687"
    "39820690" 
    "39820693"
    "39820696"
    "39820699"
)

function rebuild 
{
    for ((i=0;i<=5-1;i++)); do
    (
        echo "${machines[$i]} with ${images[$i]}"
        hcloud server rebuild --image "${images[$i]}" "${machines[$i]}";
    ) & 
    done
    wait
    sleep 2
}

rebuild
