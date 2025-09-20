#!/bin/bash

echo "======================================="
echo "DIGITALOCEAN KUBERNETES CLUSTER CHECK"
echo "======================================="
echo ""

# Check if kubectl is connected
echo "1. Checking kubectl connection..."
if kubectl cluster-info &>/dev/null; then
    echo "   ✓ Connected to Kubernetes cluster"
    kubectl cluster-info | head -2
else
    echo "   ✗ Not connected to cluster"
    echo "   Run: doctl kubernetes cluster kubeconfig save <cluster-name>"
    exit 1
fi

echo ""

# Check current kube-proxy mode
echo "2. Checking current kube-proxy mode..."
CURRENT_MODE=$(kubectl -n kube-system get cm kube-proxy -o yaml 2>/dev/null | grep -E "mode:" | head -1 | awk '{print $2}' | tr -d '"')
if [ -z "$CURRENT_MODE" ] || [ "$CURRENT_MODE" = '""' ]; then
    echo "   Current mode: iptables (default)"
else
    echo "   Current mode: $CURRENT_MODE"
fi

echo ""

# Check if memory-allocator service exists
echo "3. Checking memory-allocator service..."
if kubectl get svc memory-allocator-svc -n noisy-neighbor &>/dev/null; then
    echo "   ✓ memory-allocator-svc service found"
    kubectl get svc memory-allocator-svc -n noisy-neighbor
    echo ""
    echo "   Service endpoints:"
    kubectl get endpoints memory-allocator-svc -n noisy-neighbor
else
    echo "   ✗ memory-allocator-svc service not found"
    echo "   Run: terraform apply to create the service"
fi

echo ""

# Check memory-allocator pods
echo "4. Checking memory-allocator pods..."
PODS=$(kubectl get pods -n noisy-neighbor -l app=memory-allocator --no-headers 2>/dev/null | wc -l)
if [ "$PODS" -gt 0 ]; then
    echo "   ✓ Found $PODS memory-allocator pods"
    kubectl get pods -n noisy-neighbor -l app=memory-allocator -o wide
else
    echo "   ✗ No memory-allocator pods found"
    echo "   Check: kubectl get pods -n noisy-neighbor"
fi

echo ""

# Check node distribution
echo "5. Checking pod node distribution..."
if [ "$PODS" -gt 0 ]; then
    NODES=$(kubectl get pods -n noisy-neighbor -l app=memory-allocator --no-headers 2>/dev/null | awk '{print $7}' | sort -u | wc -l)
    echo "   Pods distributed across $NODES node(s)"
    echo "   Node distribution:"
    kubectl get pods -n noisy-neighbor -l app=memory-allocator --no-headers 2>/dev/null | awk '{print $7}' | sort | uniq -c
fi

echo ""
echo "======================================="
echo "RECOMMENDATIONS:"
echo "======================================="

if [ -z "$CURRENT_MODE" ] || [ "$CURRENT_MODE" = '""' ] || [ "$CURRENT_MODE" = "iptables" ]; then
    echo "• Enable IPVS mode for better load balancing:"
    echo "  ./enable_ipvs.sh"
fi

if [ "$PODS" -eq 0 ]; then
    echo "• Deploy memory-allocator service:"
    echo "  terraform apply"
fi

echo "• Your current service configuration with NodeSelector + Local traffic policy"
echo "  should already provide equal distribution among replicas on the same node."

echo ""
