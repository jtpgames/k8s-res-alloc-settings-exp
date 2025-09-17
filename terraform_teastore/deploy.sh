set -e  # abort on first error 

terraform init
terraform apply -auto-approve -var-file="experiment/memory_allocator_teastore_without_resource.tfvars"
