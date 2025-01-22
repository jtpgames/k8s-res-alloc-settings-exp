#!/bin/bash

# Default values
namespace_arg="-n kube-system"
namespace="kube-system"
node_selector=""
total_cpu=0
total_memory=0

# Process command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -n|--namespace)
            if [ -z "$2" ]; then
                echo "Error: Namespace argument is missing" >&2
                echo "Usage: $0 [-n|--namespace NAMESPACE]" >&2
                exit 1
            fi
            namespace_arg="-n $2"
            namespace="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: $0 [-n|--namespace NAMESPACE]" >&2
            exit 1
            ;;
    esac
done

# Verify kubectl is available
if ! command -v kubectl >/dev/null 2>&1; then
    echo "Error: kubectl is not installed or not in PATH" >&2
    exit 1
fi

node_selector=$(grep 'main.*=' terraform/variables.tf | awk -F'"' '{print $2}')

# Check if node_selector is empty or not set
if [ -z "$node_selector" ]; then
    echo "Error: Failed to get node_selector from terraform/variables.tf" >&2
    exit 1
fi

echo "Get list of running pods in namespace $namespace on the main node $node_selector"

pods=$(kubectl get pods ${namespace_arg} -o wide --field-selector "spec.nodeName=${node_selector},status.phase=Running" 2>/dev/null | awk 'NR>1 {print $1}')

if [ -z "$pods" ]; then
    echo "No running pods found on node: ${node_selector}" >&2
    exit 1
fi

# Print header
printf "%-40s %-15s %-15s\n" "POD NAME" "CPU (cores)" "MEMORY"
printf "%s\n" "---------------------------------------- --------------- ---------------"

# Process each pod
while IFS= read -r pod; do
    # Get resource usage for the pod
    if ! pod_usage=$(kubectl top pod "$pod" ${namespace_arg} 2>/dev/null | awk 'NR>1'); then
        echo "Warning: Could not get metrics for pod: $pod" >&2
        continue
    fi
 
    # Parse CPU and memory values
    pod_cpu=$(echo "$pod_usage" | awk '{print substr($2, 1, length($2)-1)}')
    pod_memory=$(echo "$pod_usage" | awk '{print $3}')

    # Convert CPU from millicores to cores
    #pod_cpu_cores=$(echo "scale=3; $pod_cpu/1000" | bc)
    
    # Add to totals
    total_cpu=$(echo "$total_cpu + ${pod_cpu}" | bc)
    total_memory=$(echo "$total_memory + ${pod_memory%Mi}" | bc)
   
    # Print pod metrics
    printf "%-40s %-15s %-15s\n" "$pod" "${pod_cpu}m" "$pod_memory"
done <<< "$pods"

# Format total memory to appropriate unit
if [ "$total_memory" -ge 1024 ]; then
    total_memory_formatted=$(echo "scale=1; $total_memory/1024" | bc)
    total_memory_unit="Gi"
else
    total_memory_formatted=$total_memory
    total_memory_unit="Mi"
fi

# Print summary
printf "\nResource Usage Summary:\n"
printf "%-40s %-15s %-15s\n" "TOTAL:" "${total_cpu}m" "${total_memory_formatted}${total_memory_unit}"
