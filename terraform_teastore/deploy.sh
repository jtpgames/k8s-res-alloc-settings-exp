#!/bin/bash
set -e  # abort on first error 

# Initialize variables
SKIP_TEASTORE=false
DEPLOYMENT_TYPE=""
ADDITIONAL_VAR_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-teastore)
            SKIP_TEASTORE=true
            shift
            ;;
        --additional-var-file)
            ADDITIONAL_VAR_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] <deployment-type>"
            echo "Options:"
            echo "  --skip-teastore          Skip TeaStore replacement (only replace noise-neighbor)"
            echo "  --additional-var-file FILE  Use an additional tfvars file"
            echo "  --help, -h               Show this help message"
            echo ""
            echo "Available deployment types:"
            echo "  mem-without-resources    - Memory allocator without resource limits"
            echo "  mem-with-resources       - Memory allocator with resource limits"
            echo "  cpu-without-resources    - CPU load generator without resource limits"
            echo "  cpu-with-resources       - CPU load generator with resource limits"
            echo "  default                  - No noisy neighbor"
            echo ""
            echo "Examples:"
            echo "  $0 mem-without-resources"
            echo "  $0 --skip-teastore mem-with-resources"
            exit 0
            ;;
        -*)
            echo "Error: Unknown option $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            if [[ -z "$DEPLOYMENT_TYPE" ]]; then
                DEPLOYMENT_TYPE="$1"
            else
                echo "Error: Multiple deployment types specified"
                echo "Use --help for usage information"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if deployment type is provided
if [[ -z "$DEPLOYMENT_TYPE" ]]; then
    echo "Error: No deployment type specified"
    echo "Usage: $0 [OPTIONS] <deployment-type>"
    echo "Use --help for more information"
    exit 1
fi

# Validate deployment type
case "$DEPLOYMENT_TYPE" in
    "mem-without-resources"|"mem-with-resources"|"cpu-without-resources"|"cpu-with-resources"|"default")
        if [[ "$SKIP_TEASTORE" == "true" ]]; then
            echo "Deploying with configuration: $DEPLOYMENT_TYPE (skipping TeaStore replacement)"
        else
            echo "Deploying with configuration: $DEPLOYMENT_TYPE (including TeaStore replacement)"
        fi
        ;;
    *)
        echo "Error: Invalid deployment type '$DEPLOYMENT_TYPE'"
        echo "Valid options are: mem-without-resources, mem-with-resources, cpu-without-resources, cpu-with-resources, default"
        exit 1
        ;;
esac

terraform init

# Define TeaStore deployment replacements
TEASTORE_REPLACEMENTS="-replace=module.teastore.kubernetes_deployment_v1.auth -replace=module.teastore.kubernetes_deployment_v1.db -replace=module.teastore.kubernetes_deployment_v1.image -replace=module.teastore.kubernetes_deployment_v1.persistence -replace=module.teastore.kubernetes_deployment_v1.rabbitmq -replace=module.teastore.kubernetes_deployment_v1.recommender -replace=module.teastore.kubernetes_deployment_v1.registry -replace=module.teastore.kubernetes_deployment_v1.webui"

# Conditionally include TeaStore replacements
if [[ "$SKIP_TEASTORE" == "true" ]]; then
    REPLACEMENTS=""
else
    REPLACEMENTS="$TEASTORE_REPLACEMENTS"
fi

# Construct additional var file parameter as array
if [[ -n "$ADDITIONAL_VAR_FILE" ]]; then
    ADDITIONAL_VAR_FILE_PARAM=("-var-file=$ADDITIONAL_VAR_FILE")
else
    ADDITIONAL_VAR_FILE_PARAM=()
fi

# Select and execute the appropriate terraform apply command based on the argument
case "$DEPLOYMENT_TYPE" in
    "mem-without-resources")
        terraform apply -auto-approve -var-file="experiment/memory_allocator_teastore_without_resource.tfvars" "${ADDITIONAL_VAR_FILE_PARAM[@]}" -replace="module.noisy-neighbor.kubernetes_deployment_v1.memory-allocator[0]" $REPLACEMENTS
        ;;
    "mem-with-resources")
        terraform apply -auto-approve -var-file="experiment/memory_allocator_teastore_with_resource.tfvars" "${ADDITIONAL_VAR_FILE_PARAM[@]}" -replace="module.noisy-neighbor.kubernetes_deployment_v1.memory-allocator[0]" $REPLACEMENTS
        ;;
    "cpu-without-resources")
        terraform apply -auto-approve -var-file="experiment/cpu_load_generator_teastore_without_resources.tfvars" "${ADDITIONAL_VAR_FILE_PARAM[@]}" -replace="module.noisy-neighbor.kubernetes_deployment_v1.cpu-load-generator[0]" $REPLACEMENTS
        ;;
    "cpu-with-resources")
        terraform apply -auto-approve -var-file="experiment/cpu_load_generator_teastore_with_resources.tfvars" "${ADDITIONAL_VAR_FILE_PARAM[@]}" -replace="module.noisy-neighbor.kubernetes_deployment_v1.cpu-load-generator[0]" $REPLACEMENTS
        ;;
    "default")
        terraform apply -auto-approve "${ADDITIONAL_VAR_FILE_PARAM[@]}" $REPLACEMENTS
        ;;
esac

# Clean up succeeded and failed pods in experiment namespaces
echo "Cleaning up completed and failed pods in experiment namespaces..."
kubectl delete pod --field-selector=status.phase==Succeeded -n teastore --ignore-not-found=true
kubectl delete pod --field-selector=status.phase==Failed -n teastore --ignore-not-found=true
kubectl delete pod --field-selector=status.phase==Succeeded -n noisy-neighbor --ignore-not-found=true
kubectl delete pod --field-selector=status.phase==Failed -n noisy-neighbor --ignore-not-found=true

echo "Deployment completed successfully!"
