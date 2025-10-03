#!/bin/bash

# Script to check TeaStore services for OOMKilled status
# Usage: ./check_oomkilled.sh

set -e

# Define the namespace
NAMESPACE="teastore"

# Define the service names
SERVICES=("registry" "auth" "webui" "recommender" "image" "persistence" "db")

echo "Checking TeaStore services for OOMKilled status..."
echo "================================================"

# Function to check a single service for OOMKilled
check_service_oomkilled() {
    local service=$1
    echo -n "Checking $service... "
    
    # Get pod names for the service
    local pods=$(kubectl get pods -n $NAMESPACE -o name | grep "$service" || true)
    
    if [[ -z "$pods" ]]; then
        echo "❌ No pods found"
        return
    fi
    
    local oomkilled_found=false
    local pod_count=0
    
    # Check each pod for OOMKilled
    while IFS= read -r pod; do
        if [[ -n "$pod" ]]; then
            pod_count=$((pod_count + 1))
            local describe_output=$(kubectl describe "$pod" -n $NAMESPACE 2>/dev/null || echo "")
            
            if echo "$describe_output" | grep -q "OOMKilled"; then
                if [[ "$oomkilled_found" == false ]]; then
                    echo "🚨 OOMKilled detected!"
                    oomkilled_found=true
                fi
                echo "  └─ Pod: ${pod#pod/} has been OOMKilled"
                
                # Extract and show the last termination reason
                local termination_info=$(echo "$describe_output" | grep -A 5 "Last State:" | grep -E "(Reason|Exit Code|Started|Finished)" || true)
                if [[ -n "$termination_info" ]]; then
                    echo "     Termination details:"
                    echo "$termination_info" | sed 's/^/       /'
                fi
            fi
        fi
    done <<< "$pods"
    
    if [[ "$oomkilled_found" == false ]]; then
        echo "✅ OK ($pod_count pod(s) checked)"
    fi
}

# Check each service
for service in "${SERVICES[@]}"; do
    check_service_oomkilled "$service"
done

echo
echo "Summary:"
echo "========"
echo "Checked ${#SERVICES[@]} TeaStore services in namespace '$NAMESPACE'"
echo "Services: ${SERVICES[*]}"