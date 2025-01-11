#!/bin/bash

echo "Creating directory for experimental data and results"

base_dir="experiment_$(date +%Y-%m-%d)"
counter=0
target_dir=$base_dir
while [ -d "$target_dir" ]; do
    ((counter++))
    target_dir="${base_dir}_${counter}"
done
mkdir -v "$target_dir"
echo "Created directory: $target_dir"

cd "$target_dir"

