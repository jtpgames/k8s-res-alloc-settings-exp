#!/bin/bash

# Create new variables.tf with replaced values
cp -v variables.tf.template variables.tf

# Retrieve worker node names

# Get the entire output and extract just the last column (Nodes), then extract content between brackets
worker_nodes=$(doctl kubernetes cluster node-pool get k8s-experiments-cluster k8s-experiments-cluster-default-pool | tail -n 1 | awk '{print $(NF-1), $NF}' | sed 's/\[//;s/\]//')

# Split the space-separated node IDs into an array
IFS=' ' read -r -a node_array <<< "$worker_nodes"

# Access individual nodes
node1="${node_array[0]}"
node2="${node_array[1]}"

# Optional: verify the results
echo "Worker 1: $node1"
echo "Worker 2: $node2"

sed -i.bak "s/<tools_node>/$node1/g" variables.tf
sed -i.bak "s/<main_node>/$node2/g" variables.tf

# Remove backup file
rm variables.tf.bak

# Query docker-config using doctl and copy it to the config folder
doctl registry login

docker_config=$(doctl registry docker-config k8s-experiments)
echo "$docker_config" > config/docker-config.json

doctl registry logout
