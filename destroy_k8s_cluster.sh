#!/bin/bash

echo "Destroying kubernetes cluster"

terraform destroy --auto-approve

doctl kubernetes cluster delete k8s-experiments-cluster
