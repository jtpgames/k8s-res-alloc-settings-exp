#!/bin/bash

handle_interrupt() {
    echo ""
    echo "Experiment cancelled by user (Ctrl+C)"
    echo "Terminating..."

    # Kill all child processes of this script too
    trap - SIGINT SIGTERM
    kill -- -$$ 2>/dev/null || true

    exit 130
}

# Set up signal trap
trap handle_interrupt SIGINT SIGTERM

# Parse command line arguments
experiment_sets=("all")  # Default to running all experiments

while [[ $# -gt 0 ]]; do
  case $1 in
    --experiment-set)
      # If this is the first --experiment-set argument, clear the default
      if [[ "${experiment_sets[0]}" == "all" && ${#experiment_sets[@]} -eq 1 ]]; then
        experiment_sets=()
      fi
      experiment_sets+=("$2")
      shift # past argument
      shift # past value
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --experiment-set SET        Run specific experiment set (can be used multiple times)"
      echo "                                Training - Only run Training experiment"
      echo "                                Noisy-Neighbor-Problem - Run Baseline, CPU and Memory Noisy Neighbor (ts without res conf)"
      echo "                                Noisy-Neighbor-Problem-With-Requests - Same as above but with custom resource configurations for noisy neighbors"
      echo "                                Applied-Guidelines - Run CPU and Memory Noisy Neighbor (ts with res conf)"
      echo "                                Custom-WebUI-Resources - Run Baseline experiments with custom TeaStore WebUI resource configurations"
      echo "                                all (default) - Run all experiments except Training"
      echo "  -h, --help                  Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0 --experiment-set Training --experiment-set Applied-Guidelines"
      echo "  $0 --experiment-set Noisy-Neighbor-Problem"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

# Validate experiment sets
valid_sets=("Training" "Noisy-Neighbor-Problem" "Noisy-Neighbor-Problem-With-Requests" "Applied-Guidelines" "Custom-WebUI-Resources" "all")
for experiment_set in "${experiment_sets[@]}"; do
  is_valid=false
  for valid_set in "${valid_sets[@]}"; do
    if [[ "$experiment_set" == "$valid_set" ]]; then
      is_valid=true
      break
    fi
  done
  
  if [[ "$is_valid" == "false" ]]; then
    echo "Error: Invalid experiment set '$experiment_set'"
    echo "Valid options: Training, Noisy-Neighbor-Problem, Noisy-Neighbor-Problem-With-Requests, Applied-Guidelines, Custom-WebUI-Resources, all"
    exit 1
  fi
done

# Remove duplicates from experiment_sets array
unique_sets=()
for set in "${experiment_sets[@]}"; do
  if [[ ! " ${unique_sets[@]} " =~ " ${set} " ]]; then
    unique_sets+=("$set")
  fi
done
experiment_sets=("${unique_sets[@]}")

# If 'all' is in the list, just use 'all' (it supersedes everything else)
if [[ " ${experiment_sets[@]} " =~ " all " ]]; then
  experiment_sets=("all")
fi

# Function to check if required tools are available
check_required_tools() {
    local missing_tools=()
    
    # Check for doctl
    if ! command -v doctl &> /dev/null; then
        missing_tools+=("doctl")
    fi
    
    # Check for kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    # Check for terraform
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    # Check for python (try python3 first, then python)
    if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        missing_tools+=("python")
    fi
    
    # If any tools are missing, print error and exit
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "Error: The following required tools are not available:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    echo "All required tools are available: doctl, kubectl, terraform, python"
}

# Function to create a safe filename from experiment name
create_safe_filename() {
    local experiment_name="$1"
    # Replace spaces with underscores and remove special characters
    echo "${experiment_name}" | sed 's/ /_/g' | sed 's/[^a-zA-Z0-9_-]//g'
}

# Function to format duration in human-readable format
format_duration() {
    local duration=$1
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    if [ $hours -gt 0 ]; then
        printf "%dh %dm %ds" $hours $minutes $seconds
    elif [ $minutes -gt 0 ]; then
        printf "%dm %ds" $minutes $seconds
    else
        printf "%ds" $seconds
    fi
}

# Function to run experiment and track time
run_experiment_with_timing() {
    local experiment_name="$1"
    shift  # Remove first argument, rest are the command arguments
    
    # Create log file name based on experiment name
    local safe_filename=$(create_safe_filename "$experiment_name")
    local log_file="${safe_filename}.log"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local timestamped_log_file="${timestamp}_${log_file}"
    
    echo "========================================"
    echo "Starting experiment: $experiment_name"
    echo "Time: $(date)"
    echo "Log file: $timestamped_log_file"
    echo "========================================"
    
    local start_time=$(date +%s)
    
    # Create log file header
    {
        echo "========================================"
        echo "EXPERIMENT LOG: $experiment_name"
        echo "Started: $(date)"
        echo "Arguments: $@"
        echo "========================================"
        echo ""
    } > "$timestamped_log_file"
    
    # Run the experiment and capture all output to log file
    # Use 'tee' to also display output to console while logging
    echo "./run_teastore_experiment.sh \"$@\" 2>&1 | tee -a \"$timestamped_log_file\""
    ./run_teastore_experiment.sh "$@" 2>&1 | tee -a "$timestamped_log_file"
    local exit_code=${PIPESTATUS[0]}  # Get exit code from the actual command, not tee
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Store timing information
    experiment_times["$experiment_name"]=$duration
    experiment_status["$experiment_name"]=$exit_code
    experiment_log_files["$experiment_name"]="$timestamped_log_file"
    
    # Add footer to log file
    {
        echo ""
        echo "========================================"
        echo "EXPERIMENT COMPLETED: $experiment_name"
        echo "Finished: $(date)"
        echo "Duration: $(format_duration $duration)"
        echo "Exit Code: $exit_code"
        echo "Status: $([ $exit_code -eq 0 ] && echo "SUCCESS" || echo "FAILED")"
        echo "========================================"
    } >> "$timestamped_log_file"
    
    echo "========================================"
    echo "Completed experiment: $experiment_name"
    echo "Duration: $(format_duration $duration)"
    echo "Status: $([ $exit_code -eq 0 ] && echo "SUCCESS" || echo "FAILED (exit code: $exit_code)")"
    echo "Log saved to: $timestamped_log_file"
    echo "Time: $(date)"
    echo "========================================"
    echo ""
    
    return $exit_code
}

# Check required tools before starting
check_required_tools

# Initialize arrays to store experiment times, status, and log files
declare -A experiment_times
declare -A experiment_status
declare -A experiment_log_files

# Record overall start time
overall_start_time=$(date +%s)

# Display which sets will be run
echo "Starting TeaStore experiments with sets: ${experiment_sets[*]} at $(date)"
echo ""

# Function to discover ts_*.tfvars files and add corresponding experiments
add_custom_webui_experiments() {
    local tfvars_dir="terraform_teastore/experiment"
    
    if [ ! -d "$tfvars_dir" ]; then
        echo "Warning: Directory $tfvars_dir not found. Skipping Custom-WebUI-Resources experiments."
        return
    fi
    
    # Find all ts_*.tfvars files
    local tfvars_files
    readarray -t tfvars_files < <(find "$tfvars_dir" -name "ts_*.tfvars" -type f -exec basename {} \; | sort)
    
    if [ ${#tfvars_files[@]} -eq 0 ]; then
        echo "Warning: No ts_*.tfvars files found in $tfvars_dir. Skipping Custom-WebUI-Resources experiments."
        return
    fi
    
    echo "Found ${#tfvars_files[@]} ts_*.tfvars files:"
    for tfvars_file in "${tfvars_files[@]}"; do
        echo "  - $tfvars_file"
        # Remove the .tfvars extension for the experiment name
        local experiment_name="${tfvars_file%.tfvars}"
        experiments_to_run["Baseline (custom $experiment_name)"]=1
    done
}

# Keep track of all experiments that will be run to avoid duplicates
declare -A experiments_to_run

# Process each experiment set and collect unique experiments
for experiment_set in "${experiment_sets[@]}"; do
    echo "========================================"
    echo "PROCESSING EXPERIMENT SET: $experiment_set"
    echo "========================================"
    
    # Add experiments from this set to the collection
    case "$experiment_set" in
        "Training")
            experiments_to_run["Training"]=1
            ;;
        "Noisy-Neighbor-Problem")
            experiments_to_run["Baseline"]=1
            experiments_to_run["CPU Noisy Neighbor (ts without res conf)"]=1
            experiments_to_run["Memory Noisy Neighbor (ts without res conf)"]=1
            ;;
        "Noisy-Neighbor-Problem-With-Requests")
            experiments_to_run["Baseline"]=1
            experiments_to_run["CPU Noisy Neighbor (ts without res conf, nn with res conf)"]=1
            ;;
        "Applied-Guidelines")
            experiments_to_run["CPU Noisy Neighbor (ts with res conf)"]=1
            experiments_to_run["CPU Noisy Neighbor (ts with res conf, nn with res conf)"]=1
            experiments_to_run["Memory Noisy Neighbor (ts with res conf)"]=1
            ;;
        "Custom-WebUI-Resources")
            add_custom_webui_experiments
            ;;
        "all")
            experiments_to_run["Baseline"]=1
            experiments_to_run["CPU Noisy Neighbor (ts without res conf)"]=1
            experiments_to_run["CPU Noisy Neighbor (ts without res conf, nn with res conf)"]=1
            experiments_to_run["CPU Noisy Neighbor (ts with res conf)"]=1
            experiments_to_run["CPU Noisy Neighbor (ts with res conf, nn with res conf)"]=1
            experiments_to_run["Memory Noisy Neighbor (ts without res conf)"]=1
            experiments_to_run["Memory Noisy Neighbor (ts with res conf)"]=1
            add_custom_webui_experiments
            ;;
    esac
done

echo "========================================"
echo "EXPERIMENTS TO RUN:"
for experiment in "${!experiments_to_run[@]}"; do
    echo "  - $experiment"
done
echo "========================================"
echo ""

# Run the unique experiments
if [[ -n "${experiments_to_run["Training"]}" ]]; then
    run_experiment_with_timing "Training" --experiment-type training
fi
if [[ -n "${experiments_to_run["Baseline"]}" ]]; then
    run_experiment_with_timing "Baseline" --experiment-type baseline
fi
if [[ -n "${experiments_to_run["CPU Noisy Neighbor (ts without res conf)"]}" ]]; then
    run_experiment_with_timing "CPU Noisy Neighbor (ts without res conf)" --experiment-type cpu-noisy-neighbor
fi
if [[ -n "${experiments_to_run["CPU Noisy Neighbor (ts without res conf, nn with res conf)"]}" ]]; then
    run_experiment_with_timing "CPU Noisy Neighbor (ts without res conf, nn with res conf)" --experiment-type cpu-noisy-neighbor --ts-with-custom-res-conf cpu_load_generator_resources
fi
if [[ -n "${experiments_to_run["CPU Noisy Neighbor (ts with res conf, nn with res conf)"]}" ]]; then
    run_experiment_with_timing "CPU Noisy Neighbor (ts with res conf, nn with res conf)" --experiment-type cpu-noisy-neighbor --ts-with-custom-res-conf cpu_load_generator_with_resources_teastore_with_resources
fi
if [[ -n "${experiments_to_run["CPU Noisy Neighbor (ts with res conf)"]}" ]]; then
    run_experiment_with_timing "CPU Noisy Neighbor (ts with res conf)" --experiment-type cpu-noisy-neighbor --ts-with-res-conf
fi
if [[ -n "${experiments_to_run["Memory Noisy Neighbor (ts without res conf)"]}" ]]; then
    run_experiment_with_timing "Memory Noisy Neighbor (ts without res conf)" --experiment-type memory-noisy-neighbor
fi
if [[ -n "${experiments_to_run["Memory Noisy Neighbor (ts with res conf)"]}" ]]; then
    run_experiment_with_timing "Memory Noisy Neighbor (ts with res conf)" --experiment-type memory-noisy-neighbor --ts-with-res-conf
fi

# Run all Custom-WebUI-Resources experiments dynamically
for experiment in "${!experiments_to_run[@]}"; do
    if [[ "$experiment" == "Baseline (custom "* ]]; then
        # Extract the tfvars filename from the experiment name
        # Format: "Baseline (custom ts_with_request_limit)" -> "ts_with_request_limit"
        tfvars_name=${experiment#"Baseline (custom "}
        tfvars_name=${tfvars_name%")"}
        
        # Check if tfvars_name contains "_nn_" (noisy neighbor)
        if [[ "$tfvars_name" == *"_nn_"* ]]; then
            run_experiment_with_timing "$experiment" --experiment-type cpu-noisy-neighbor --ts-with-custom-res-conf "$tfvars_name"
        else
            run_experiment_with_timing "$experiment" --experiment-type baseline --ts-with-custom-res-conf "$tfvars_name"
        fi
    fi
done

# Calculate overall duration
overall_end_time=$(date +%s)
overall_duration=$((overall_end_time - overall_start_time))

# Print summary
echo "=========================================="
echo "EXPERIMENT EXECUTION SUMMARY"
echo "=========================================="
echo "Overall execution time: $(format_duration $overall_duration)"
echo "Started: $(date -d @$overall_start_time)"
echo "Completed: $(date -d @$overall_end_time)"
echo ""
echo "Individual experiment times:"

# Build experiment list based on what was actually run
experiments_run=()
for experiment in "${!experiments_to_run[@]}"; do
    experiments_run+=("$experiment")
done

# Display results for experiments that were actually run
for experiment in "${experiments_run[@]}"; do
    duration=${experiment_times["$experiment"]}
    status=${experiment_status["$experiment"]}
    log_file=${experiment_log_files["$experiment"]}
    status_text=$([ $status -eq 0 ] && echo "SUCCESS" || echo "FAILED")
    echo "  $experiment: $(format_duration $duration) - $status_text"
    echo "    Log file: $log_file"
done

# Build list of all possible experiments (including dynamically discovered ones)
all_possible_experiments=("Training" "Baseline" \
  "CPU Noisy Neighbor (ts without res conf)" \
  "CPU Noisy Neighbor (ts without res conf, nn with res conf)" \
  "CPU Noisy Neighbor (ts with res conf)" \
  "CPU Noisy Neighbor (ts with res conf, nn with res conf)" \
  "Memory Noisy Neighbor (ts without res conf)" \
  "Memory Noisy Neighbor (ts with res conf)")

# Add dynamically discovered Custom-WebUI-Resources experiments to the list
tfvars_dir="terraform_teastore/experiment"
if [ -d "$tfvars_dir" ]; then
    readarray -t tfvars_files < <(find "$tfvars_dir" -name "ts_*.tfvars" -type f -exec basename {} \; | sort)
    for tfvars_file in "${tfvars_files[@]}"; do
        experiment_name="${tfvars_file%.tfvars}"
        all_possible_experiments+=("Baseline (custom $experiment_name)")
    done
fi

# Show what experiments are not included in the current sets
echo ""
echo "Experiments not run:"
for exp in "${all_possible_experiments[@]}"; do
    if [[ -z "${experiments_to_run[$exp]}" ]]; then
        echo "  $exp: NOT IN SELECTED SETS"
    fi
done

echo ""
echo "Log files created:"
for experiment in "${experiments_run[@]}"; do
    log_file=${experiment_log_files["$experiment"]}
    if [ -n "$log_file" ]; then
        echo "  $log_file"
    fi
done

echo "=========================================="

# Exit with non-zero code if any experiment failed
failed_experiments=0
for status in "${experiment_status[@]}"; do
    if [ $status -ne 0 ]; then
        ((failed_experiments++))
    fi
done

if [ $failed_experiments -gt 0 ]; then
    echo "WARNING: $failed_experiments experiment(s) failed!"
    exit 1
else
    echo "All experiments completed successfully!"
    exit 0
fi
