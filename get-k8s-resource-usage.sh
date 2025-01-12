#!/bin/sh


{ echo "List 1:"; kubectl top pod --namespace=kube-system --no-headers | awk 'NR % 2 == 1'; echo "\nList 2:"; kubectl top pod --namespace=kube-system --no-headers | awk 'NR % 2 == 0'; }
