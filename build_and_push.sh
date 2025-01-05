#!/bin/bash

cd $1
doctl registry login
cleaned_path=${1%/}
docker build -t registry.digitalocean.com/k8s-experiments-registry/experiments:$cleaned_path . && docker push registry.digitalocean.com/k8s-experiments-registry/experiments:$cleaned_path

doctl registry logout
cd ../
