#!/bin/bash

echo "Destroying kubernetes cluster"

if [[ ! " $* " =~ " --skip-terraform " ]]; then
    cd terraform
    terraform destroy --auto-approve
    cd ..
fi

doctl kubernetes cluster delete k8s-experiments-cluster
