#!/bin/bash

# Simple script to find and analyze all locust_*.log files in LoadTester_Logs directories

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
    elif [[ "$file_path" == *"CPU_experiment"* ]]; then
        if [[ "$file_path" == *"without_resources"* ]]; then
            echo "3"
        elif [[ "$file_path" == *"with_resources"* ]]; then
            echo "4"
        else
            echo "3"  # Default CPU to without_resources priority
        fi
    elif [[ "$file_path" == *"Memory_experiment"* ]]; then
        if [[ "$file_path" == *"without_resources"* ]]; then
            echo "5"
        elif [[ "$file_path" == *"with_resources"* ]]; then
            echo "6"
        else
            echo "5"  # Default Memory to without_resources priority
        fi
    else
        echo "9"  # Unknown files go last
    fi
}

# Create array of files with their priorities and sort
declare -a file_priority_pairs
for log_file in "${log_files[@]}"; do
    priority=$(get_sort_priority "$log_file")
    file_priority_pairs+=("$priority:$log_file")
done

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
