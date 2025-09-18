#!/bin/bash

# Initialize variables
SKIP_MODULES_MODIFICATION=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--skip-modules-modification)
      SKIP_MODULES_MODIFICATION=true
      shift
      ;;
    *)
      # Unknown option
      echo "Unknown option: $1"
      echo "Usage: $0 [-s|--skip-modules-modification]"
      exit 1
      ;;
  esac
done

allocate_memory() {
    local cluster_public_ip="$1"
    local initial_memory="$2"
    local increment="$3"
    local sleep_duration="$4"
    local threshold="$5"  # Optional parameter

    printf "allocate_memory: ip=%s mem=%dMiB inc=%dMiB sleep=%ds thresh=%s\n" \
        "$cluster_public_ip" "$initial_memory" "$increment" "$sleep_duration" "${threshold:-none}" >&2

    local total_memory=$initial_memory
    local memory_to_allocate=$increment
    local threshold_exceeded=false

    while true; do
        # If threshold is set and total memory exceeds it, set increment to 1
        if [[ -n "$threshold" ]] && [[ $total_memory -ge $threshold ]]; then
            memory_to_allocate=1
            sleep_duration=15 # sleep for 15 seconds which is the default interval the metric server gathers resource usage.
            # show resource usage of kube-system and workload pods
            ./get-k8s-resource-usage.sh >&2
            threshold_exceeded=true
        fi

        # Store the curl response and capture the HTTP code
        local response
        local http_code
        printf "Sending request to allocate %s Mi memory" "$memory_to_allocate" >&2
        response=$(curl -v -X POST "http://$cluster_public_ip/memory-allocator/?memory=$memory_to_allocate" -w "%{http_code}" 2>&1)
        http_code=$(echo "$response" | tail -n1)

        # Check if HTTP code is successful (2xx)
        if [[ $http_code -ge 200 && $http_code -lt 300 ]]; then
            total_memory=$((total_memory + memory_to_allocate))
            
            if [ "$threshold_exceeded" = "true" ]; then
                # synchonize total memory usage with metrics server
                # Get new memory value
                new_memory=$(try_get_resource_usage "workload" "memory")

                # Update total_memory if new value is greater
                if [[ -n "$new_memory" ]] && [[ "$new_memory" -gt "$total_memory" ]]; then
                    total_memory=$new_memory
                fi
            fi

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

try_get_resource_usage() {
    local namespace="$1"
    local resource_type="$2"
    local max_attempts=30
    local attempt=1
    local sleep_duration=10 # seconds between retries

    # Validate input parameters
    if [ -z "$namespace" ] || [ -z "$resource_type" ]; then
        echo "Error: Both namespace and resource type (cpu/memory) are required" >&2
        return 1
    fi

    # Validate resource type
    if [ "$resource_type" != "cpu" ] && [ "$resource_type" != "memory" ]; then
        echo "Error: Resource type must be either 'cpu' or 'memory'" >&2
        return 1
    fi

    local output=""
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts..." >&2

        # Execute the resource usage script
        output=$(./get-k8s-resource-usage.sh -n "$namespace")
        if [ $? -ne 0 ]; then
            echo "Error: Failed to execute get-k8s-resource-usage.sh" >&2
        else
            break
        fi

        # Sleep before the next attempt
        sleep $sleep_duration
        attempt=$((attempt + 1))
    done

    if [ $attempt -ge $max_attempts ]; then
        echo "Failed after $max_attempts attempts" >&2
        return 1
    fi

    # Extract the last line and get the requested value
    local last_line
    last_line=$(echo "$output" | tail -n 1)
    
    if [ "$resource_type" = "cpu" ]; then
        # Extract CPU value (second to last column) and remove 'm' suffix
        echo "$last_line" | awk '{print $(NF-1)}' | tr -d 'm'
    else
        # Extract memory value (last column) and remove 'Mi' suffix
        echo "$last_line" | awk '{print $NF}' | tr -d 'Mi'
    fi
}

if [ "$SKIP_MODULES_MODIFICATION" = false ]; then
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
    #sleep 5
    cd ..
else
    echo "Skipping modules.tf modification as requested"
fi

echo "show resource usage of kube-system workloads before experiment."
./get-k8s-resource-usage.sh

# kubectl get ingress -A -o jsonpath='{range .items[*]}{.metadata.name}: {.status.loadBalancer.ingress[0].ip}{"\n"}{end}'

cluster_public_ip=$(kubectl get ingress -A -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

# Check if the kubectl command failed
if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve cluster IP from kubectl"
    exit 1
fi

# Check if IP is empty
if [ -z "$cluster_public_ip" ]; then
    echo "Error: No cluster IP found in ingress"
    exit 1
fi

echo "Cluster-IP: $cluster_public_ip"

# Get initial memory usage of memory-allocator pod

result=$(try_get_resource_usage "workload" "memory")
exit_code=$?

# Check the return code
if [ $exit_code -ne 0 ]; then
    echo "Could not get initial memory usage; exit code $exit_code"
    exit $exit_code
fi

./get-k8s-resource-usage.sh -n workload

initial_memory_usage=$result
memory_to_allocate=100
total_memory=$initial_memory_usage

# Call the function and capture the result
final_memory=$(allocate_memory "$cluster_public_ip" "$initial_memory_usage" "$memory_to_allocate" "1")
echo "First run: final memory allocation: ${final_memory}MiB"

echo "After the pod is evicted, we have to wait until kubernetes reschedules the pod. This can range from a couple of seconds up to ten minutes."
sleep 10

# Repeatetly get initial memory usage of memory-allocator pod to find out when the pod was rescheduled
result=$(try_get_resource_usage "workload" "memory")
exit_code=$?

# Check the return code
if [ $exit_code -ne 0 ]; then
    echo "Could not get initial memory usage; exit code $exit_code"
    exit $exit_code
fi

./get-k8s-resource-usage.sh -n workload

final_memory_allocated=$((final_memory - initial_memory_usage))

initial_memory_usage=$result
total_memory=$initial_memory_usage

final_memory=$(allocate_memory "$cluster_public_ip" "$initial_memory_usage" "$memory_to_allocate" "1" "$final_memory_allocated")
echo "Second run: final memory allocation: ${final_memory}MiB"

echo "show resource usage of kube-system workloads after experiment."
./get-k8s-resource-usage.sh
