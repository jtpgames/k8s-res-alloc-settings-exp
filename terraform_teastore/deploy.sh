set -e  # abort on first error 

# Check if argument is provided
if [ $# -eq 0 ]; then
    echo "Error: No deployment type specified"
    echo "Usage: $0 <deployment-type>"
    echo "Available deployment types:"
    echo "  mem-without-resources    - Memory allocator without resource limits"
    echo "  mem-with-resources       - Memory allocator with resource limits"
    echo "  cpu-without-resources    - CPU load generator without resource limits"
    echo "  cpu-with-resources       - CPU load generator with resource limits"
    exit 1
fi

DEPLOYMENT_TYPE="$1"

# Validate deployment type
case "$DEPLOYMENT_TYPE" in
    "mem-without-resources"|"mem-with-resources"|"cpu-without-resources"|"cpu-with-resources")
        echo "Deploying with configuration: $DEPLOYMENT_TYPE"
        ;;
    *)
        echo "Error: Invalid deployment type '$DEPLOYMENT_TYPE'"
        echo "Valid options are: mem-without-resources, mem-with-resources, cpu-without-resources, cpu-with-resources"
        exit 1
        ;;
esac

terraform init

# Select and execute the appropriate terraform apply command based on the argument
case "$DEPLOYMENT_TYPE" in
    "mem-without-resources")
        terraform apply -auto-approve -var-file="experiment/memory_allocator_teastore_without_resource.tfvars" -replace="module.noise-neighbor.kubernetes_deployment_v1.memory-allocator[0]" -replace="module.noise-neighbor.kubernetes_deployment_v1.cpu-load-generator[0]"
        ;;
    "mem-with-resources")
        terraform apply -auto-approve -var-file="experiment/memory_allocator_teastore_with_resource.tfvars" -replace="module.noise-neighbor.kubernetes_deployment_v1.memory-allocator[0]" -replace="module.noise-neighbor.kubernetes_deployment_v1.cpu-load-generator[0]"
        ;;
    "cpu-without-resources")
        terraform apply -auto-approve -var-file="experiment/cpu_load_generator_teastore_without_resources.tfvars" -replace="module.noise-neighbor.kubernetes_deployment_v1.memory-allocator[0]" -replace="module.noise-neighbor.kubernetes_deployment_v1.cpu-load-generator[0]"
        ;;
    "cpu-with-resources")
        terraform apply -auto-approve -var-file="experiment/cpu_load_generator_teastore_with_resources.tfvars" -replace="module.noise-neighbor.kubernetes_deployment_v1.memory-allocator[0]" -replace="module.noise-neighbor.kubernetes_deployment_v1.cpu-load-generator[0]"
        ;;
esac
