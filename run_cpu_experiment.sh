#!/bin/bash

SKIP_WARMUP=false

cluster_public_ip=$(cat "cluster_public_ip.txt")

# Check if IP is empty
if [ -z "$cluster_public_ip" ]; then
  echo "Error: No cluster IP found in ingress"
  exit 1
fi

if [ "$SKIP_WARMUP" = false ]; then
  WAIT_MINUTES=5
  WAIT_SECONDS=$((WAIT_MINUTES * 60))

  echo "Waiting ${WAIT_MINUTES} minutes for TeaStore warmup to finish..."

  for i in $(seq "$WAIT_SECONDS" -1 1); do
    if [ -t 1 ]; then
      # stdout is a terminal → overwrite the same line
      printf "\rTime left: %3ds" "$i"
    fi
    sleep 1
  done

  if [ -t 1 ]; then
    echo -e "\nWarmup finished."
  else
    echo "Warmup finished."
  fi
fi

cpu_to_allocate=100
num_cores=8
sleep_time_s=$((10*60))

# Store the curl response and capture the HTTP code
response=""
http_code=""
printf "Sending request to allocate %s%% CPU Time on %s cores for %s s\n" "$cpu_to_allocate" "$num_cores" "$sleep_time_s" >&2
response=$(curl -v -X POST "http://$cluster_public_ip/cpu-load-generator/?percentage=$cpu_to_allocate&cores=$num_cores&sleepTime=$sleep_time_s" -w "%{http_code}" 2>&1)
http_code=$(echo "$response" | tail -n1)

# Check if HTTP code is successful (2xx)
if [[ $http_code -ge 200 && $http_code -lt 300 ]]; then
  printf "Request successful.\nHTTP Code: %s\n-------------------\n" "$http_code" >&2
else
  printf "Request failed with HTTP code: %s\n" "$http_code" >&2
fi
