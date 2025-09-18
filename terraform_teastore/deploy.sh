set -e  # abort on first error 

terraform init
terraform apply -auto-approve -var-file="experiment/memory_allocator_teastore_without_resource.tfvars" -replace="module.noise-neighbor.kubernetes_deployment_v1.memory-allocator[0]" -replace="module.noise-neighbor.kubernetes_deployment_v1.cpu-load-generator[0]"
