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
    echo "  default                  - No noisy neighbor"
    exit 1
fi

DEPLOYMENT_TYPE="$1"

# Validate deployment type
case "$DEPLOYMENT_TYPE" in
    "mem-without-resources"|"mem-with-resources"|"cpu-without-resources"|"cpu-with-resources"|"default")
        echo "Deploying with configuration: $DEPLOYMENT_TYPE"
        ;;
    *)
        echo "Error: Invalid deployment type '$DEPLOYMENT_TYPE'"
        echo "Valid options are: mem-without-resources, mem-with-resources, cpu-without-resources, cpu-with-resources, deploy"
        exit 1
        ;;
esac

terraform init

# Define TeaStore deployment replacements
TEASTORE_REPLACEMENTS="-replace=module.teastore.kubernetes_deployment_v1.auth -replace=module.teastore.kubernetes_deployment_v1.db -replace=module.teastore.kubernetes_deployment_v1.image -replace=module.teastore.kubernetes_deployment_v1.persistence -replace=module.teastore.kubernetes_deployment_v1.rabbitmq -replace=module.teastore.kubernetes_deployment_v1.recommender -replace=module.teastore.kubernetes_deployment_v1.registry -replace=module.teastore.kubernetes_deployment_v1.webui"

# Select and execute the appropriate terraform apply command based on the argument
case "$DEPLOYMENT_TYPE" in
    "mem-without-resources")
        terraform apply -auto-approve -var-file="experiment/memory_allocator_teastore_without_resource.tfvars" -replace="module.noise-neighbor.kubernetes_deployment_v1.memory-allocator[0]" $TEASTORE_REPLACEMENTS
        ;;
    "mem-with-resources")
        terraform apply -auto-approve -var-file="experiment/memory_allocator_teastore_with_resource.tfvars" -replace="module.noise-neighbor.kubernetes_deployment_v1.memory-allocator[0]" $TEASTORE_REPLACEMENTS
        ;;
    "cpu-without-resources")
        terraform apply -auto-approve -var-file="experiment/cpu_load_generator_teastore_without_resources.tfvars" -replace="module.noise-neighbor.kubernetes_deployment_v1.cpu-load-generator[0]" $TEASTORE_REPLACEMENTS
        ;;
    "cpu-with-resources")
        terraform apply -auto-approve -var-file="experiment/cpu_load_generator_teastore_with_resources.tfvars" -replace="module.noise-neighbor.kubernetes_deployment_v1.cpu-load-generator[0]" $TEASTORE_REPLACEMENTS
        ;;
    "default")
        terraform apply -auto-approve $TEASTORE_REPLACEMENTS
      ;;
esac
