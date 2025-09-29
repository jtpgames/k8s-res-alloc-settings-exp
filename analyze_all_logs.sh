#!/bin/bash

# Simple script to find and analyze all locust_*.log files in LoadTester_Logs directories
# Usage: ./analyze_all_logs.sh [experiment_type1] [experiment_type2] ...
# Available experiment types:
#   - baseline
#   - training
#   - CPU_experiment without_resources
#   - CPU_experiment with_resources
#   - Memory_experiment without_resources
#   - Memory_experiment with_resources
# If no arguments provided, all logs will be analyzed.

# Parse command line arguments for experiment type filtering
SPECIFIED_EXPERIMENT_TYPES=()
if [ $# -gt 0 ]; then
    SPECIFIED_EXPERIMENT_TYPES=("$@")
    echo "Filtering logs for specified experiment types: ${SPECIFIED_EXPERIMENT_TYPES[*]}"
else
    echo "No experiment types specified - analyzing all available logs"
fi
echo

# Create output directory for analysis results
OUTPUT_DIR="log_analysis_results"
mkdir -p "$OUTPUT_DIR"
echo "Results will be stored in: $OUTPUT_DIR"
echo

# Find all locust_*.log files in directories starting with LoadTester_Logs
log_files=($(find . -type d -name "LoadTester_Logs*" -exec find {} -name "locust_*.log" -type f \;))

if [ ${#log_files[@]} -eq 0 ]; then
    echo "No locust_*.log files found in LoadTester_Logs directories"
    exit 1
fi

echo "Found ${#log_files[@]} log file(s):"
for log_file in "${log_files[@]}"; do
    echo "  $log_file"
done
echo

# Sort log files according to specified order:
# 1. Baseline
# 2. Training 
# 3. CPU_experiment (without resources first, then with resources)
# 4. Memory_experiment (without resources first, then with resources)
sorted_log_files=()

# Function to get sort priority based on file path
get_sort_priority() {
    local file_path="$1"
    
    if [[ "$file_path" == *"Baseline"* ]]; then
        echo "1"
    elif [[ "$file_path" == *"Training"* ]]; then
        echo "2"
    elif [[ "$file_path" == *"cpu-without-resources"* ]]; then
        echo "3"
    elif [[ "$file_path" == *"cpu-with-resources"* ]]; then
        echo "4"
    elif [[ "$file_path" == *"mem-without-resources"* ]]; then
        echo "5"
    elif [[ "$file_path" == *"mem-with-resources"* ]]; then
        echo "6"
    else
        echo "9"  # Unknown files go last
    fi
}

# Function to get experiment type name based on file path (for filtering)
get_experiment_type() {
    local file_path="$1"
    
    if [[ "$file_path" == *"Baseline"* ]]; then
        echo "baseline"
    elif [[ "$file_path" == *"Training"* ]]; then
        echo "training"
    elif [[ "$file_path" == *"cpu-without-resources"* ]]; then
        echo "CPU_experiment without_resources"
    elif [[ "$file_path" == *"cpu-with-resources"* ]]; then
        echo "CPU_experiment with_resources"
    elif [[ "$file_path" == *"mem-without-resources"* ]]; then
        echo "Memory_experiment without_resources"
    elif [[ "$file_path" == *"mem-with-resources"* ]]; then
        echo "Memory_experiment with_resources"
    else
        echo "unknown"
    fi
}

# Function to check if a log file should be included based on specified experiment types
should_include_log() {
    local file_path="$1"
    
    # If no experiment types specified, include all files
    if [ ${#SPECIFIED_EXPERIMENT_TYPES[@]} -eq 0 ]; then
        return 0
    fi
    
    local experiment_type=$(get_experiment_type "$file_path")
    
    # Check if this experiment type matches any of the specified types
    for type in "${SPECIFIED_EXPERIMENT_TYPES[@]}"; do
        if [[ "$experiment_type" == "$type" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Filter log files based on specified experiment types (if any) and create array with priorities
declare -a file_priority_pairs
filtered_count=0
for log_file in "${log_files[@]}"; do
    if should_include_log "$log_file"; then
        priority=$(get_sort_priority "$log_file")
        file_priority_pairs+=("$priority:$log_file")
        ((filtered_count++))
    fi
done

if [ $filtered_count -eq 0 ]; then
    echo "No log files match the specified experiment types: ${SPECIFIED_EXPERIMENT_TYPES[*]}"
    echo "Available experiment types found:"
    for log_file in "${log_files[@]}"; do
        experiment_type=$(get_experiment_type "$log_file")
        echo "  - $experiment_type (from: $log_file)"
    done
    exit 1
fi

echo "After filtering: $filtered_count log file(s) selected"
echo

# Sort by priority and extract file paths
IFS=$'\n' sorted_pairs=($(sort <<< "${file_priority_pairs[*]}"))
unset IFS

for pair in "${sorted_pairs[@]}"; do
    sorted_log_files+=("${pair#*:}")  # Remove priority prefix
done

echo "Log files will be processed in the following order:"
for i in "${!sorted_log_files[@]}"; do
    echo "  $((i+1)). ${sorted_log_files[$i]}"
done
echo

# Process all log files in a single call
echo "Analyzing all log files together..."
python analyze_logs.py "${sorted_log_files[@]}" --publication --output-dir "$OUTPUT_DIR"

echo "All log files processed!"
echo "Results saved to: $OUTPUT_DIR"
