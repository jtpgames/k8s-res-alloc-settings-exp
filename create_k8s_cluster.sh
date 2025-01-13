#!/bin/bash

install_metrics_server=false
skip_query_info=false

for arg in "$@"; do
    if [ "$arg" = "--install-metrics" ]; then
        install_metrics=true
        echo "Will install metrics after creation"
    elif [ "$arg" = "--skip-query-info" ]; then
        skip_query_info=true
        echo "Will skip querying cluster information"
    fi
done

echo "Creating kubernetes cluster"

doctl kubernetes cluster create k8s-experiments-cluster --region fra1 --version 1.30.5-do.5 --count 2 --size s-2vcpu-4gb --verbose

echo "Kubernetes cluster created, copying kubeconfig to terraform folder"

cp -v ~/.kube/config "terraform/config/kube-config"

if [ "$skip_query_info" = false ]; then

    if ! experiment_dir=$(find . -maxdepth 1 -type d -name "experiment_$(date +%Y-%m-%d)*" | sort -V | tail -n1) || [ -z "$experiment_dir" ]; then
        echo "Experiment directory not found. Creating it now."
        ./prepare_experiment.sh
    fi

    experiment_dir=$(find . -maxdepth 1 -type d -name "experiment_$(date +%Y-%m-%d)*" | sort -V | tail -n1) || [ -z "$experiment_dir" ]
    echo "Using experiment directory: $experiment_dir"
    cd "$experiment_dir"

    echo "Retrieving information about the cluster."
    kubectl describe node > nodes_description.txt

    hostnames=($(cat nodes_description.txt | grep Hostname | awk '{print $2}'))
    node1=${hostnames[0]}
    node2=${hostnames[1]}
    echo "Node 1: $node1"
    echo "Node 2: $node2"

    kubectl get --raw "/api/v1/nodes/$node1/proxy/configz" | jq > kubelet_config_node1.txt
    kubectl get --raw "/api/v1/nodes/$node2/proxy/configz" | jq > kubelet_config_node2.txt

fi

if [ "$install_metrics_server" = true ]; then
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
fi

