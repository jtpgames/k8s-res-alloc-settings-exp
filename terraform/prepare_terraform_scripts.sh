#!/bin/bash

# Read credentials
read -p "Enter registry username: " REGISTRY_USER
read -sp "Enter registry password: " REGISTRY_PW
echo

# Create new variables.tf with replaced values
cp -v variables.tf.template variables.tf

# Replace username placeholder
sed -i.bak "s/<registry_user>/$REGISTRY_USER/g" variables.tf
# Replace password placeholder
sed -i.bak "s/<registry_pw>/$REGISTRY_PW/g" variables.tf

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
