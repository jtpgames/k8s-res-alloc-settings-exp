#!/bin/sh

# First destroy resources
terraform destroy

# Remove the .terraform directory (cached providers/modules)
rm -rfv .terraform/

# Remove the terraform state files if you want to start fresh
rm -fv terraform.tfstate
rm -fv terraform.tfstate.backup

# Remove any Terraform lock files
rm -fv .terraform.lock.hcl


