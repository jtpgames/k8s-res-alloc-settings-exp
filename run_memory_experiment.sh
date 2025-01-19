#!/bin/sh

cd terraform

# Check if modules.tf exists
if [ ! -f modules.tf ]; then
    echo "Error: modules.tf file not found"
    exit 1
fi

# Create backup with timestamp
BACKUP="modules.tf.backup.$(date +%Y%m%d_%H%M%S)"
if ! cp modules.tf "$BACKUP"; then
    echo "Error: Failed to create backup file"
    exit 1
fi
echo "Backup created: $BACKUP"

if sed -i '' "s/memory_allocator[[:space:]]*=[[:space:]]*[0-1]/memory_allocator                  = 1/" modules.tf && \
   sed -i '' "s/cpu_load_generator[[:space:]]*=[[:space:]]*[0-1]/cpu_load_generator                = 0/" modules.tf; then
    echo "Successfully updated memory_allocator to 1 and cpu_load_generator to 0"
else
    echo "Error: Failed to update modules.tf"
    # Restore from backup
    cp "$BACKUP" modules.tf
    exit 1
fi

cd ..

# kubectl get ingress -A -o jsonpath='{range .items[*]}{.metadata.name}: {.status.loadBalancer.ingress[0].ip}{"\n"}{end}'

cluster_public_ip=$(kubectl get ingress -A -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

echo $cluster_public_ip

curl -v -X POST "http://$cluster_public_ip/memory-allocator/?memory=100" 

