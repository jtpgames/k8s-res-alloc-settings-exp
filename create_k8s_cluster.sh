#!/bin/bash

echo "Creating kubernetes cluster"

doctl kubernetes cluster create k8s-experiments-cluster --region fra1 --version 1.30.5-do.5 --count 2 --size s-2vcpu-4gb --verbose

echo "Kubernetes cluster created, copying kubeconfig to terraform folder"

cp -v ~/.kube/config "terraform/config/kube-config"
