function create_and_activate_venv_in_current_dir {
  # Check if the "venv" folder exists
  if [ ! -d "venv" ]; then
      echo "The 'venv' folder does not exist. Creating a virtual environment..."
      # Create a virtual environment named "venv"
      python3 -m venv venv

      # Check if the virtual environment was created successfully
      if [ $? -eq 0 ]; then
          echo "Virtual environment 'venv' created successfully."
      else
          echo "Failed to create virtual environment 'venv'. Exiting."
          exit 1
      fi
  else
      echo "The 'venv' folder already exists."
  fi

  # Activate the virtual environment
  source venv/bin/activate

  echo "installing python requirements"
  pip install wheel
  pip install --upgrade pip setuptools
  if [ -f local_requirements.txt ]; then
    pip install -r local_requirements.txt
  else
    pip install -r requirements.txt
  fi

  # Check if the virtual environment was activated successfully
  if [ $? -eq 0 ]; then
      echo "Virtual environment 'venv' activated successfully."
  else
      echo "Failed to activate the virtual environment 'venv'. Exiting."
      exit 2
  fi
}

# Parse command line arguments
skip_warmup=false
experiment_type="training"  # default to training
teastore_with_resource_configurations=false
skip_cluster_destruction=true

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-warmup)
      skip_warmup=true
      shift # past argument
      ;;
    --ts-with-res-conf)
      teastore_with_resource_configurations=true
      shift # past argument
      ;;
    --destroy-cluster)
      skip_cluster_destruction=false
      shift # past argument
      ;;
    --experiment-type)
      experiment_type="$2"
      if [[ "$experiment_type" != "training" && "$experiment_type" != "memory-noisy-neighbor" && "$experiment_type" != "cpu-noisy-neighbor" ]]; then
        echo "Error: Invalid experiment type '$experiment_type'. Valid types are: training, memory-noisy-neighbor, cpu-noisy-neighbor"
        exit 1
      fi
      shift # past argument
      shift # past value
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --skip-warmup               Skip the warmup phase"
      echo "  --ts-with-res-conf          Start TeaStore with resource allocation configurations"
      echo "  --experiment-type TYPE      Specify experiment type: training (default), memory-noisy-neighbor, cpu-noisy-neighbor"
      echo "  --destroy-cluster           Destroy the Kubernetes cluster at the end"
      echo "  -h, --help                  Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

echo "locust_scripts:"
cd locust_scripts
create_and_activate_venv_in_current_dir

cd ..

echo "All Python virtual environments created and requirements installed."

echo "Creating testbed k8s cluster"
./create_k8s_cluster.sh

cd terraform_teastore

set -e  # abort on first error inside this block
./prepare_terraform_scripts.sh

# Determine deployment type based on experiment type and resource configuration
if [ "$experiment_type" = "memory-noisy-neighbor" ]; then
  if [ "$teastore_with_resource_configurations" = true ]; then
    deployment_type="mem-with-resources"
  else
    deployment_type="mem-without-resources"
  fi
elif [ "$experiment_type" = "cpu-noisy-neighbor" ]; then
  if [ "$teastore_with_resource_configurations" = true ]; then
    deployment_type="cpu-with-resources"
  else
    deployment_type="cpu-without-resources"
  fi
else
  # For training or any other experiment type, use default
  deployment_type="default"
fi

echo "Using deployment type: $deployment_type"
echo "$deployment_type" > "current_deployment_type.txt"
./deploy.sh "$deployment_type"
set +e  # back to normal (script won't exit on error anymore)

cd ..

# Executing TeaStore Load Tests for training data

# PROFILES_FULL="low low_2 med high"
PROFILES_FULL="med"
PROFILES_TRAINING="med med med"

# Set profiles based on experiment type
if [ "$experiment_type" = "training" ]; then
  PROFILES_TO_USE=$PROFILES_TRAINING
else
  PROFILES_TO_USE=$PROFILES_FULL
fi

echo "Experiment type: $experiment_type"
echo "Using profiles: $PROFILES_TO_USE"

cluster_public_ip=$(kubectl get ingress -A -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

# Check if the kubectl command failed
if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve cluster IP from kubectl"
    exit 1
fi

# Check if IP is empty
if [ -z "$cluster_public_ip" ]; then
    echo "Error: No cluster IP found in ingress"
    exit 1
fi

echo $cluster_public_ip
echo $cluster_public_ip > "cluster_public_ip.txt"

# explicitly format the time without colons so that is can be used in bash commands as a valid path without the need to escape the colons
START_TIME="$(date +"%FT%H%M%S")"

root_folder=$(pwd)

experiment_dir=$(find . -maxdepth 1 -type d -name "experiment_$(date +%Y-%m-%d)*" | sort -V | tail -n1) || [ -z "$experiment_dir" ]
echo "Using experiment directory: $experiment_dir"

training_experiment_directory="$root_folder/$experiment_dir/Training_Data"
memory_noisy_neighbor_experiment_dir="$root_folder/$experiment_dir/Memory_experiment/$deployment_type"
cpu_noisy_neighbor_experiment_dir="$root_folder/$experiment_dir/CPU_experiment/$deployment_type"
locust_directory="$root_folder/locust_scripts"

echo "Waiting for 60 seconds for TeaStore to start up"
sleep 60

# Retry TeaStore status request until successful
max_retries=20
retry_count=0
while [ $retry_count -lt $max_retries ]; do
  echo "Attempting to request status of TeaStore (attempt $((retry_count + 1))/$max_retries)..."
  if curl -s -f -m 10 "http://$cluster_public_ip/tools.descartes.teastore.webui/status" > /dev/null 2>&1; then
    echo "Successfully connected to TeaStore!"
    break
  else
    retry_count=$((retry_count + 1))
    if [ $retry_count -lt $max_retries ]; then
      echo "Failed, retrying in 1 second..."
      sleep 1
    else
      echo "Error: Failed to request status from TeaStore after $max_retries attempts"
      exit 1
    fi
  fi
done

# perform a few requests to warm up the service (a real warmup is performed by the load test later,
# this is just a start, because we observed that sometimes the load balancer of TeaStore gets stuck.
echo "Sending curl requests to teastore to warm it up ..."

# Retry the entire warmup sequence if any curl request fails
max_warmup_retries=5
warmup_retry_count=0
warmup_success=false

while [ $warmup_retry_count -lt $max_warmup_retries ] && [ "$warmup_success" = false ]; do
  echo "Warmup attempt $((warmup_retry_count + 1))/$max_warmup_retries"
  warmup_failed=false
  
  for i in {1..5}; do
    echo "  Warmup request $i/5"
    
    # Test each endpoint and break the loop if any fails

    curl -s -f -m 10 -o /dev/null "http://$cluster_public_ip/tools.descartes.teastore.webui/status"
    if [ $? -ne 0 ]; then
      echo "    Failed: status endpoint"
      warmup_failed=true
      break
    fi
    sleep 0.1
    
    curl -s -f -m 10 -o /dev/null "http://$cluster_public_ip/tools.descartes.teastore.webui/"
    if [ $? -ne 0 ]; then
      echo "    Failed: home endpoint"
      warmup_failed=true
      break
    fi
    sleep 0.1
    
    curl -s -f -m 10 -o /dev/null "http://$cluster_public_ip/tools.descartes.teastore.webui/login"
    if [ $? -ne 0 ]; then
      echo "    Failed: login endpoint"
      warmup_failed=true
      break
    fi
    sleep 0.1
    
    curl -s -f -m 10 -o /dev/null "http://$cluster_public_ip/tools.descartes.teastore.webui/category?category=2&page=1"
    if [ $? -ne 0 ]; then
      echo "    Failed: category endpoint"
      warmup_failed=true
      break
    fi
    sleep 0.1
    
    curl -s -f -m 10 -o /dev/null "http://$cluster_public_ip/tools.descartes.teastore.webui/product?id=7"
    if [ $? -ne 0 ]; then
      echo "    Failed: product endpoint"
      warmup_failed=true
      break
    fi
    sleep 0.1
    
    curl -s -f -m 10 -o /dev/null "http://$cluster_public_ip/tools.descartes.teastore.webui/profile"
    if [ $? -ne 0 ]; then
      echo "    Failed: profile endpoint"
      warmup_failed=true
      break
    fi
    sleep 0.1
  done
  
  if [ "$warmup_failed" = true ]; then
    warmup_retry_count=$((warmup_retry_count + 1))
    if [ $warmup_retry_count -lt $max_warmup_retries ]; then
      echo "  Warmup failed, retrying in 3 seconds..."
      sleep 3
    else
      echo "Error: Warmup failed after $max_warmup_retries attempts"
      exit 1
    fi
  else
    warmup_success=true
    echo "  Warmup completed successfully!"
  fi
done

# Set first_iteration based on command line argument
if [ "$skip_warmup" = true ]; then
  first_iteration=false
  echo "Skipping warmup phase (--skip-warmup flag provided)"
else
  first_iteration=true
  echo "Warmup phase will be performed on first iteration"
fi

# Start memory experiment if experiment type is memory-noisy-neighbor
if [ "$experiment_type" = "memory-noisy-neighbor" ]; then
  target_directory="$memory_noisy_neighbor_experiment_dir/LoadTester_Logs_${START_TIME}"
  mkdir -pv "$target_directory"

  echo "Starting memory experiment in background..."
  memory_log_file="$memory_noisy_neighbor_experiment_dir/memory_experiment_${START_TIME}.log"
  ./run_memory_experiment.sh --skip-modules-modification > "$memory_log_file" 2>&1 &
  memory_experiment_pid=$!
  echo "Memory experiment started with PID $memory_experiment_pid, logging to $memory_log_file"
elif [ "$experiment_type" = "cpu-noisy-neighbor" ]; then
  target_directory="$cpu_noisy_neighbor_experiment_dir/LoadTester_Logs_${START_TIME}"
  mkdir -pv "$target_directory"

  echo "Starting CPU experiment in background..."
  cpu_log_file="$cpu_noisy_neighbor_experiment_dir/cpu_experiment_${START_TIME}.log"
  ./run_cpu_experiment.sh > "$cpu_log_file" 2>&1 &
  cpu_experiment_pid=$!
  echo "CPU experiment started with PID $cpu_experiment_pid, logging to $cpu_log_file"
else
  target_directory="$training_experiment_directory/LoadTester_Logs_${START_TIME}"
  mkdir -pv "$target_directory"
fi

for profile in $PROFILES_TO_USE; do
  echo $profile

  echo "move to locust folder and clean old results"
  cd "$locust_directory"
  ./delete_results.sh

  export KEEP_TEASTORE_LOGS=True

  # Perform the warmup phase on the first load test
  if [ "$first_iteration" = true ]; then
    echo "Perform warmup phase"
    export WARMUP_PHASE=True
    first_iteration=false
  else
    export WARMUP_PHASE=False
  fi

  export LOAD_INTENSITY_PROFILE=$profile
  ./start_teastore_loadtest.sh --ip $cluster_public_ip --no_port

  mv -v locust_log.log "$target_directory/locust_log_$profile.log"

  # sleep for a few seconds for any residual processing in the TeaStore to finish
  echo "*** Starting next load test in 10 seconds\n"
  sleep 10

  echo "move back to root folder"
  cd "$root_folder"

done

echo "*** All load intensity profiles have been executed\n"
echo "******* Remember to download the recorded resource usages before exiting *******\n"
echo "*** Navigate to http://$cluster_public_ip/grafana to download them\n"

# Check if cluster destruction should be skipped
if [ "$skip_cluster_destruction" = true ]; then
  echo "*** Cluster destruction skipped (--skip-cluster-destruction flag provided) ***"
  echo "*** To manually destroy the cluster later, run: ***"
  echo "***   cd terraform_teastore && terraform destroy && cd .. && ./destroy_k8s_cluster.sh ***"
  echo "*** Remember to download resource usage data from http://$cluster_public_ip/grafana ***"
else
  cd terraform_teastore
  terraform destroy
  cd ..
  
  ./destroy_k8s_cluster.sh
fi
