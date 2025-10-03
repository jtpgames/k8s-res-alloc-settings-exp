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
  # Check if the virtual environment was activated successfully
  if [ $? -eq 0 ]; then
      echo "Virtual environment 'venv' activated successfully."
  else
      echo "Failed to activate the virtual environment 'venv'. Exiting."
      exit 2
  fi

  # Create timestamped pip install log file
  PIP_LOG_FILE="pip_install_$(date +%Y%m%d_%H%M%S).log"
  echo "Installing python requirements (output will be logged to $PIP_LOG_FILE)..."
  
  # Log pip install commands and redirect output to timestamped file
  {
    echo "=== PIP INSTALL LOG ==="
    echo "Started: $(date)"
    echo "Working directory: $(pwd)"
    echo ""
    
    echo "Installing wheel..."
    pip install wheel
    
    echo ""
    echo "Upgrading pip and setuptools..."
    pip install --upgrade pip setuptools
    
    echo ""
    if [ -f local_requirements.txt ]; then
      echo "Installing from local_requirements.txt..."
      pip install -r local_requirements.txt
    else
      echo "Installing from requirements.txt..."
      pip install -r requirements.txt
    fi
    
    echo ""
    echo "Completed: $(date)"
    echo "=== END PIP INSTALL LOG ==="
  } >> "$PIP_LOG_FILE" 2>&1
  
  echo "Python requirements installation completed. See $PIP_LOG_FILE for details."

  # Check if pip installations completed successfully
  if [ $? -eq 0 ]; then
      echo "Virtual environment 'venv' activated and packages installed successfully."
  else
      echo "Failed to install Python packages. Check $PIP_LOG_FILE for details. Exiting."
      exit 2
  fi
}

# Function to measure TeaStore status endpoint response times
determine_status_response_times() {
  local cluster_ip="$1"
  
  echo "Measuring TeaStore status endpoint response times..."
  local STATUS_TIMING_FILE="average_status_response_time_$(date +%Y%m%d_%H%M%S).txt"
  
  # Arrays to store timing data
  local -a total_times
  local -a connect_times
  local -a transfer_times
  
  # Perform 10 timing measurements
  for i in {1..10}; do
    echo "  Response time measurement $i/10"
    
    # Use curl with timing output to measure different phases
    local timing_output
    timing_output=$(curl -s -f -m 10 -o /dev/null -w "total:%{time_total};connect:%{time_connect};transfer:%{time_starttransfer}" "http://$cluster_ip/tools.descartes.teastore.webui/status" 2>/dev/null)
    local curl_exit_code=$?
    
    if [ $curl_exit_code -eq 0 ] && [ -n "$timing_output" ]; then
      # Parse timing values
      local total_time
      local connect_time
      local transfer_time
      total_time=$(echo "$timing_output" | sed -n 's/.*total:\([0-9.]*\).*/\1/p')
      connect_time=$(echo "$timing_output" | sed -n 's/.*connect:\([0-9.]*\).*/\1/p')
      transfer_time=$(echo "$timing_output" | sed -n 's/.*transfer:\([0-9.]*\).*/\1/p')
      
      # Store values in arrays
      total_times+=($total_time)
      connect_times+=($connect_time)
      transfer_times+=($transfer_time)
      
      echo "    Total: ${total_time}s, Connect: ${connect_time}s, Transfer: ${transfer_time}s"
    else
      echo "    Failed to get timing data (curl exit code: $curl_exit_code)"
    fi
    
    # Small delay between measurements
    sleep 0.5
  done
  
  # Generate statistics and reports using Python
  if [ ${#total_times[@]} -gt 0 ]; then
    # Convert arrays to comma-separated strings for Python script
    local total_csv
    local connect_csv
    local transfer_csv
    total_csv=$(IFS=','; echo "${total_times[*]}")
    connect_csv=$(IFS=','; echo "${connect_times[*]}")
    transfer_csv=$(IFS=','; echo "${transfer_times[*]}")
    
    local endpoint="http://$cluster_ip/tools.descartes.teastore.webui/status"
    
    python calculate_response_stats.py "$total_csv" "$connect_csv" "$transfer_csv" "$endpoint" --file "$STATUS_TIMING_FILE"
  else
    echo "⚠ Warning: No successful timing measurements collected"
    echo "Failed to measure response times at $(date)" > "$STATUS_TIMING_FILE"
  fi
}

# Parse command line arguments
skip_warmup=false
only_warmup=false
experiment_type="training"  # default to training
teastore_with_resource_configurations=false
teastore_with_additional_custom_resource_configurations=false
custom_tfvars_file=""
skip_cluster_destruction=true

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-warmup)
      skip_warmup=true
      shift # past argument
      ;;
    --only-warmup)
      only_warmup=true
      shift # past argument
      ;;
    --ts-with-res-conf)
      teastore_with_resource_configurations=true
      shift # past argument
      ;;
    --ts-with-custom-res-conf)
      teastore_with_additional_custom_resource_configurations=true
      shift # past argument
      # Check if next argument exists and is not another flag
      if [[ $# -gt 0 && "$1" != --* ]]; then
        custom_tfvars_file="$1"
        shift # past value
      else
        echo "Error: --ts-with-custom-res-conf requires a .tfvars filename as the next argument"
        exit 1
      fi
      ;;
    --destroy-cluster)
      skip_cluster_destruction=false
      shift # past argument
      ;;
    --experiment-type)
      experiment_type="$2"
      if [[ "$experiment_type" != "training" && "$experiment_type" != "baseline" && "$experiment_type" != "memory-noisy-neighbor" && "$experiment_type" != "cpu-noisy-neighbor" ]]; then
        echo "Error: Invalid experiment type '$experiment_type'. Valid types are: training, baseline, memory-noisy-neighbor, cpu-noisy-neighbor"
        exit 1
      fi
      shift # past argument
      shift # past value
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --skip-warmup               Skip the warmup phase"
      echo "  --only-warmup               Only perform warmup phase and exit (skips load tests)"
      echo "  --ts-with-res-conf          Start TeaStore with resource allocation configurations"
      echo "  --ts-with-custom-res-conf FILE  Start TeaStore with custom resource configurations from FILE.tfvars in terraform_teastore/experiment/"
      echo "  --experiment-type TYPE      Specify experiment type: training (default), baseline, memory-noisy-neighbor, cpu-noisy-neighbor"
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

# Construct deploy command with additional var file if needed
if [ "$teastore_with_additional_custom_resource_configurations" = true ]; then
  # Check if the custom tfvars file exists
  if [ -f "experiment/${custom_tfvars_file}.tfvars" ]; then
    ./deploy.sh --additional-var-file "experiment/${custom_tfvars_file}.tfvars" "$deployment_type"
    # Append custom tfvars file to deployment type for directory naming
    deployment_type="${deployment_type}-${custom_tfvars_file}"
    echo "Updated deployment type with custom configuration: $deployment_type"
  else
    echo "Error: Custom tfvars file 'experiment/${custom_tfvars_file}.tfvars' not found"
    echo "Available files in terraform_teastore/experiment/:"
    ls -la experiment/*.tfvars 2>/dev/null || echo "No .tfvars files found"
    exit 1
  fi
else
  ./deploy.sh "$deployment_type"
fi
set +e  # back to normal (script won't exit on error anymore)

cd ..

# Executing TeaStore Load Tests for training data

# PROFILES_FULL="low low_2 med high"
PROFILES_FULL="low_4"
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
baseline_experiment_directory="$root_folder/$experiment_dir/Baseline_Data/$deployment_type"
memory_noisy_neighbor_experiment_dir="$root_folder/$experiment_dir/Memory_experiment/$deployment_type"
cpu_noisy_neighbor_experiment_dir="$root_folder/$experiment_dir/CPU_experiment/$deployment_type"
locust_directory="$root_folder/locust_scripts"

echo "Current time: $(date +'%H:%M:%S')"
if [ "$teastore_with_additional_custom_resource_configurations" = true ]; then
  echo "Waiting for 240 seconds for TeaStore to start up"
  sleep 240
else
  echo "Waiting for 120 seconds for TeaStore to start up"
  sleep 120
fi

# Retry TeaStore status request until all services are OK
max_retries=20
retry_count=0
while [ $retry_count -lt $max_retries ]; do
  echo "Checking TeaStore services status (attempt $((retry_count + 1))/$max_retries)..."
  
  # Get the status page response
  status_response=$(curl -s -m 10 "http://$cluster_public_ip/tools.descartes.teastore.webui/status" 2>/dev/null)
  curl_exit_code=$?
  
  if [ $curl_exit_code -eq 0 ] && [ -n "$status_response" ]; then
    # Use Python script to parse HTML and check if all services are OK
    if echo "$status_response" | python check_teastore_status.py /dev/stdin > /dev/null 2>&1; then
      # Get the detailed status output for logging
      detailed_status=$(echo "$status_response" | python check_teastore_status.py /dev/stdin 2>/dev/null)
      echo "✓ All TeaStore services are ready!"
      echo "$detailed_status" | grep -E "(Found [0-9]+ services|✓ Services OK:|\ \ - )"
      break
    else
      # Get the detailed status output for logging
      detailed_status=$(echo "$status_response" | python check_teastore_status.py /dev/stdin 2>/dev/null || echo "Failed to parse status")
      echo "✗ Not all TeaStore services are ready yet:"
      echo "$detailed_status" | head -10
    fi
  else
    echo "✗ Failed to connect to TeaStore status endpoint (curl exit code: $curl_exit_code)"
  fi
  
  retry_count=$((retry_count + 1))
  if [ $retry_count -lt $max_retries ]; then
    echo "Retrying in 5 seconds..."
    sleep 5
  else
    echo "Error: TeaStore services are not all ready after $max_retries attempts"
    echo "Last status response (first 500 chars):"
    echo "$status_response" | head -c 500
    exit 1
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

# Measure response time performance after warmup
determine_status_response_times "$cluster_public_ip"

# Check if only warmup was requested
if [ "$only_warmup" = true ]; then
  echo "Only warmup requested (--only-warmup flag provided). Exiting after warmup completion."
  exit 0
fi

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
  ./run_memory_experiment.sh --skip-modules-modification --once > "$memory_log_file" 2>&1 &
  memory_experiment_pid=$!
  echo "Memory experiment started with PID $memory_experiment_pid, logging to $memory_log_file"
# Start CPU experiment if experiment type is cpu-noisy-neighbor
elif [ "$experiment_type" = "cpu-noisy-neighbor" ]; then
  target_directory="$cpu_noisy_neighbor_experiment_dir/LoadTester_Logs_${START_TIME}"
  mkdir -pv "$target_directory"

  echo "Starting CPU experiment in background..."
  cpu_log_file="$cpu_noisy_neighbor_experiment_dir/cpu_experiment_${START_TIME}.log"
  ./run_cpu_experiment.sh > "$cpu_log_file" 2>&1 &
  cpu_experiment_pid=$!
  echo "CPU experiment started with PID $cpu_experiment_pid, logging to $cpu_log_file"
# Start Baseline experiment if experiment type is baseline
elif [ "$experiment_type" = "baseline" ]; then
  target_directory="$baseline_experiment_directory/LoadTester_Logs_${START_TIME}"
  mkdir -pv "$target_directory"
# Otherwise, start Training experiment
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
