#!/bin/bash

# Simple signal handler for Ctrl+C - terminate immediately
handle_interrupt() {
    echo ""
    echo "Experiment cancelled by user (Ctrl+C)"
    echo "Terminating..."
    exit 130
}

# Set up signal trap
trap handle_interrupt SIGINT

# Parse command line arguments
experiment_set="all"  # Default to running all experiments

while [[ $# -gt 0 ]]; do
  case $1 in
    --experiment-set)
      experiment_set="$2"
      shift # past argument
      shift # past value
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --experiment-set SET        Run specific experiment set:"
      echo "                                Training - Only run Training experiment"
      echo "                                Noisy-Neighbor-Problem - Run Baseline, CPU and Memory Noisy Neighbor (without resources)"
      echo "                                Noisy-Neighbor-Problem-With-Requests - Same as above but with --n-with-res-conf for noisy neighbors"
      echo "                                Applied-Guidelines - Run CPU and Memory Noisy Neighbor (with resources)"
      echo "                                all (default) - Run all experiments"
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

# Validate experiment set
case "$experiment_set" in
    "Training"|"Noisy-Neighbor-Problem"|"Noisy-Neighbor-Problem-With-Requests"|"Applied-Guidelines"|"all")
        # Valid experiment set
        ;;
    *)
        echo "Error: Invalid experiment set '$experiment_set'"
        echo "Valid options: Training, Noisy-Neighbor-Problem, Noisy-Neighbor-Problem-With-Requests, Applied-Guidelines, all"
        exit 1
        ;;
esac

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

echo "Starting TeaStore experiments (set: $experiment_set) at $(date)"
echo ""

# Run experiments based on selected set
case "$experiment_set" in
    "Training")
        echo "Running Training experiment set"
        run_experiment_with_timing "Training" --experiment-type training
        ;;
    "Noisy-Neighbor-Problem")
        echo "Running Noisy-Neighbor-Problem experiment set"
        run_experiment_with_timing "Baseline" --experiment-type baseline
        run_experiment_with_timing "CPU Noisy Neighbor (without resources)" --experiment-type cpu-noisy-neighbor
        run_experiment_with_timing "Memory Noisy Neighbor (without resources)" --experiment-type memory-noisy-neighbor
        ;;
    "Noisy-Neighbor-Problem-With-Requests")
        echo "Running Noisy-Neighbor-Problem-With-Requests experiment set"
        run_experiment_with_timing "Baseline" --experiment-type baseline
        run_experiment_with_timing "CPU Noisy Neighbor (without resources)" --experiment-type cpu-noisy-neighbor --n-with-res-conf
        run_experiment_with_timing "Memory Noisy Neighbor (without resources)" --experiment-type memory-noisy-neighbor --n-with-res-conf
        ;;
    "Applied-Guidelines")
        echo "Running Applied-Guidelines experiment set"
        run_experiment_with_timing "CPU Noisy Neighbor (with resources)" --experiment-type cpu-noisy-neighbor --ts-with-res-conf
        run_experiment_with_timing "Memory Noisy Neighbor (with resources)" --experiment-type memory-noisy-neighbor --ts-with-res-conf
        ;;
    "all")
        echo "Running all experiments"
        run_experiment_with_timing "Training" --experiment-type training
        run_experiment_with_timing "Baseline" --experiment-type baseline
        run_experiment_with_timing "CPU Noisy Neighbor (without resources)" --experiment-type cpu-noisy-neighbor
        run_experiment_with_timing "CPU Noisy Neighbor (with resources)" --experiment-type cpu-noisy-neighbor --ts-with-res-conf
        run_experiment_with_timing "Memory Noisy Neighbor (without resources)" --experiment-type memory-noisy-neighbor
        run_experiment_with_timing "Memory Noisy Neighbor (with resources)" --experiment-type memory-noisy-neighbor --ts-with-res-conf
        ;;
esac

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
case "$experiment_set" in
    "Training")
        experiments_run+=("Training")
        ;;
    "Noisy-Neighbor-Problem")
        experiments_run+=("Baseline")
        experiments_run+=("CPU Noisy Neighbor (without resources)")
        experiments_run+=("Memory Noisy Neighbor (without resources)")
        ;;
    "Noisy-Neighbor-Problem-With-Requests")
        experiments_run+=("Baseline")
        experiments_run+=("CPU Noisy Neighbor (without resources)")
        experiments_run+=("Memory Noisy Neighbor (without resources)")
        ;;
    "Applied-Guidelines")
        experiments_run+=("CPU Noisy Neighbor (with resources)")
        experiments_run+=("Memory Noisy Neighbor (with resources)")
        ;;
    "all")
        experiments_run+=("Training")
        experiments_run+=("Baseline")
        experiments_run+=("CPU Noisy Neighbor (without resources)")
        experiments_run+=("CPU Noisy Neighbor (with resources)")
        experiments_run+=("Memory Noisy Neighbor (without resources)")
        experiments_run+=("Memory Noisy Neighbor (with resources)")
        ;;
esac

# Display results for experiments that were actually run
for experiment in "${experiments_run[@]}"; do
    duration=${experiment_times["$experiment"]}
    status=${experiment_status["$experiment"]}
    log_file=${experiment_log_files["$experiment"]}
    status_text=$([ $status -eq 0 ] && echo "SUCCESS" || echo "FAILED")
    echo "  $experiment: $(format_duration $duration) - $status_text"
    echo "    Log file: $log_file"
done

# Show what experiments are not included in the current set
case "$experiment_set" in
    "Training")
        echo "  Baseline: NOT IN SET"
        echo "  CPU Noisy Neighbor (without resources): NOT IN SET"
        echo "  CPU Noisy Neighbor (with resources): NOT IN SET"
        echo "  Memory Noisy Neighbor (without resources): NOT IN SET"
        echo "  Memory Noisy Neighbor (with resources): NOT IN SET"
        ;;
    "Noisy-Neighbor-Problem")
        echo "  Training: NOT IN SET"
        echo "  CPU Noisy Neighbor (with resources): NOT IN SET"
        echo "  Memory Noisy Neighbor (with resources): NOT IN SET"
        ;;
    "Noisy-Neighbor-Problem-With-Requests")
        echo "  Training: NOT IN SET"
        echo "  CPU Noisy Neighbor (with resources): NOT IN SET"
        echo "  Memory Noisy Neighbor (with resources): NOT IN SET"
        ;;
    "Applied-Guidelines")
        echo "  Training: NOT IN SET"
        echo "  Baseline: NOT IN SET"
        echo "  CPU Noisy Neighbor (without resources): NOT IN SET"
        echo "  Memory Noisy Neighbor (without resources): NOT IN SET"
        ;;
esac

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
