#!/bin/bash

echo "Destroying kubernetes cluster"

cd terraform
terraform destroy --auto-approve
cd ..

doctl kubernetes cluster delete k8s-experiments-cluster
