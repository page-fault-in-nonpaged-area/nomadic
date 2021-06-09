IMAGE="ubuntu-20.04"

declare -a machines=(
    "consul-leader-0"
    "nomad-leader-0" 
    "nomad-worker-0"
    "nomad-worker-1"
    "nomad-worker-2"
)

function clear_logs {
    for i in "${machines[@]}"; do 
        rm -rf "out_$i.txt" & 
    done
}

function rebuild {
    printf "%s\n\n" "Cluster is rebuilding..."
    for i in "${machines[@]}"; do 
        sleep 1
        (
            hcloud server rebuild --image "$IMAGE" "$i" > "out_$i.txt";
        ) & 
    done
    wait
    sleep 2

    for i in "${machines[@]}"; do
        if cat "out_$i.txt" | grep -q "rebuilt with image $IMAGE"; then
            printf '%-20s: %-15s\n' "$i" "rebuild OK!"
        else 
            printf '%-20s: %-15s\n' "$i" "rebuild FAIL!"
        fi
    done
}

function main {
    rm -rf ~/.ssh/known_hosts
    clear_logs
    rebuild
    clear_logs
}

main
