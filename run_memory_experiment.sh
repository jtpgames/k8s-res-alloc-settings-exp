#!/bin/bash

allocate_memory() {
    local cluster_public_ip="$1"
    local initial_memory="$2"
    local increment="$3"
    local sleep_duration="$4"

    local total_memory=$initial_memory
    local memory_to_allocate=$increment

    while true; do
        # Store the curl response and capture the HTTP code
        local response
        local http_code
        response=$(curl -v -X POST "http://$cluster_public_ip/memory-allocator/?memory=$memory_to_allocate" -w "%{http_code}" 2>&1)
        http_code=$(echo "$response" | tail -n1)

        # Check if HTTP code is successful (2xx)
        if [[ $http_code -ge 200 && $http_code -lt 300 ]]; then
            total_memory=$((total_memory + memory_to_allocate))
            printf "Request successful.\nTotal memory allocated: %dMiB\nIncrement: %dMiB\nHTTP Code: %s\n-------------------\n" "$total_memory" "$memory_to_allocate" "$http_code" >&2
            sleep "$sleep_duration"
        else
            # subtract here, because a failed request at this point means that the last allocation request caused pod eviction.
            total_memory=$((total_memory - memory_to_allocate))
            printf "Request failed with HTTP code: %s\nFinal memory allocation: %dMiB\n" "$http_code" "$total_memory" >&2
            break
        fi
    done

    # Return only the final memory allocation
    printf "%d" "$total_memory"
}

cd terraform

# Check if modules.tf exists
if [ ! -f modules.tf ]; then
    echo "Error: modules.tf file not found"
    exit 1
fi

# # Create backup with timestamp
# BACKUP="modules.tf.backup.$(date +%Y%m%d_%H%M%S)"
# if ! cp modules.tf "$BACKUP"; then
#     echo "Error: Failed to create backup file"
#     exit 1
# fi
# echo "Backup created: $BACKUP"

if sed -i "s/[[:space:]]memory_allocator[[:space:]]*=[[:space:]]*[0-1]/\tmemory_allocator\t=1/" modules.tf && \
   sed -i "s/cpu_load_generator[[:space:]]*=[[:space:]]*[0-1]/cpu_load_generator = 0/" modules.tf; then
    echo "Successfully updated memory_allocator to 1 and cpu_load_generator to 0"
else
    echo "Error: Failed to update modules.tf"
    # Restore from backup
    # cp "$BACKUP" modules.tf
    exit 1
fi

#./deploy.sh

cd ..

#sleep 5

# kubectl get ingress -A -o jsonpath='{range .items[*]}{.metadata.name}: {.status.loadBalancer.ingress[0].ip}{"\n"}{end}'

cluster_public_ip=$(kubectl get ingress -A -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

echo $cluster_public_ip

# Get initial memory usage of memory-allocator pod

output=$(./get-k8s-resource-usage.sh -n workload)
if [ $? -ne 0 ]; then
    echo "Error: Failed to execute get-k8s-resource-usage.sh" >&2
    exit 1
fi
echo "Full output:"
echo "$output"

last_line=$(echo "$output" | tail -n 1)
cpu_value=$(echo "$last_line" | awk '{print $(NF-1)}' | tr -d 'm')
memory_value=$(echo "$last_line" | awk '{print $NF}' | tr -d 'Mi')

echo -e "\nExtracted values:"
echo "CPU: ${cpu_value}m"
echo "Memory: ${memory_value}Mi"

initial_memory_usage=$memory_value
memory_to_allocate=100
total_memory=$initial_memory_usage

# Call the function and capture the result
final_memory=$(allocate_memory "$cluster_public_ip" "$initial_memory_usage" "$memory_to_allocate" "1")
echo "Function returned final memory allocation: ${final_memory}MiB"

# show resource usage of kube-system workloads
./get-k8s-resource-usage.sh

# After the pod is evicted, we have to wait a couple of minutes before kubernetes rescheduled the pod
# ten minutes
sleep 120

# TODO Repeatetly get initial memory usage of memory-allocator pod to find out when the pod was rescheduled
# get-k8s-resource-usage.sh -n workload

final_memory_allocated=$((final_memory - initial_memory_usage))

initial_memory_usage=$final_memory
memory_to_allocate=1
total_memory=$initial_memory_usage

./get-k8s-resource-usage.sh -n workload

final_memory_allocated=2000
curl -v -X POST "http://$cluster_public_ip/memory-allocator/?memory=$final_memory_allocated"

sleep 20

./get-k8s-resource-usage.sh -n workload

final_memory=$(allocate_memory "$cluster_public_ip" "$initial_memory_usage" "$memory_to_allocate" "1")
echo "Function returned final memory allocation: ${final_memory}MiB"

# show resource usage of kube-system workloads
./get-k8s-resource-usage.sh
