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

# Process each log file
for log_file in "${log_files[@]}"; do
    echo "Analyzing: $log_file"
    python analyze_logs.py "$log_file" --output-dir "$OUTPUT_DIR"
    echo "---"
done

echo "All log files processed!"
echo "Results saved to: $OUTPUT_DIR"
