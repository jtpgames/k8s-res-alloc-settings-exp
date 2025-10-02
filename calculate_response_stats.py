#!/usr/bin/env python3
"""
Response Time Statistics Calculator

Calculates comprehensive statistics for network response time measurements,
including averages, standard deviation (jitter), min/max values, and
coefficient of variation for consistency analysis.
"""

import sys
import statistics
import json
from typing import List, Dict, Any


def calculate_stats(values: List[float]) -> Dict[str, float]:
    """Calculate comprehensive statistics for a list of values."""
    if not values:
        return {}
    
    return {
        'mean': statistics.mean(values),
        'median': statistics.median(values),
        'std_dev': statistics.stdev(values) if len(values) > 1 else 0.0,
        'min': min(values),
        'max': max(values),
        'cv': (statistics.stdev(values) / statistics.mean(values) * 100) if len(values) > 1 and statistics.mean(values) > 0 else 0.0
    }


def format_time_stats(stats: Dict[str, float], label: str) -> Dict[str, Any]:
    """Format timing statistics for output."""
    return {
        'label': label,
        'seconds': {
            'mean': f"{stats['mean']:.6f}",
            'std_dev': f"{stats['std_dev']:.6f}",
            'min': f"{stats['min']:.6f}",
            'max': f"{stats['max']:.6f}",
            'cv': f"{stats['cv']:.1f}%"
        },
        'milliseconds': {
            'mean': f"{stats['mean'] * 1000:.2f}",
            'std_dev': f"{stats['std_dev'] * 1000:.2f}",
            'min': f"{stats['min'] * 1000:.2f}",
            'max': f"{stats['max'] * 1000:.2f}",
            'cv': f"{stats['cv']:.1f}%"
        }
    }


def generate_report(endpoint: str, total_times: List[float], connect_times: List[float], transfer_times: List[float]) -> str:
    """Generate a complete formatted report."""
    from datetime import datetime
    
    # Calculate statistics for each metric
    total_stats = calculate_stats(total_times)
    connect_stats = calculate_stats(connect_times)
    transfer_stats = calculate_stats(transfer_times)
    
    report = []
    report.append("=== TeaStore Status Endpoint Response Time Analysis ===")
    report.append(f"Measurement Date: {datetime.now().strftime('%a %b %d %H:%M:%S %Z %Y')}")
    report.append(f"Endpoint: {endpoint}")
    report.append(f"Number of measurements: {len(total_times)}")
    report.append("")
    
    # Average Response Times
    report.append("Average Response Times:")
    report.append(f"  Total Response Time:      {total_stats['mean']:.6f} seconds ({total_stats['mean'] * 1000:.2f} ms)")
    report.append(f"  TCP Connection Time:      {connect_stats['mean']:.6f} seconds ({connect_stats['mean'] * 1000:.2f} ms)")
    report.append(f"  Time to First Byte:       {transfer_stats['mean']:.6f} seconds ({transfer_stats['mean'] * 1000:.2f} ms)")
    report.append("")
    
    # Response Time Variations (Jitter)
    report.append("Response Time Variations (Jitter):")
    report.append(f"  Total Response Time:      ±{total_stats['std_dev']:.6f} seconds (±{total_stats['std_dev'] * 1000:.2f} ms)")
    report.append(f"  TCP Connection Time:      ±{connect_stats['std_dev']:.6f} seconds (±{connect_stats['std_dev'] * 1000:.2f} ms)")
    report.append(f"  Time to First Byte:       ±{transfer_stats['std_dev']:.6f} seconds (±{transfer_stats['std_dev'] * 1000:.2f} ms)")
    report.append("")
    
    # Min/Max Response Times
    report.append("Min/Max Response Times:")
    report.append(f"  Total Response Time:      {total_stats['min']:.6f}s - {total_stats['max']:.6f}s ({total_stats['min'] * 1000:.2f}ms - {total_stats['max'] * 1000:.2f}ms)")
    report.append(f"  TCP Connection Time:      {connect_stats['min']:.6f}s - {connect_stats['max']:.6f}s ({connect_stats['min'] * 1000:.2f}ms - {connect_stats['max'] * 1000:.2f}ms)")
    report.append(f"  Time to First Byte:       {transfer_stats['min']:.6f}s - {transfer_stats['max']:.6f}s ({transfer_stats['min'] * 1000:.2f}ms - {transfer_stats['max'] * 1000:.2f}ms)")
    report.append("")
    
    # Individual Measurements
    report.append("Individual Measurements:")
    report.append("  Measurement | Total (s) | Connect (s) | Transfer (s) | Total (ms) | Connect (ms) | Transfer (ms)")
    report.append("  ------------|-----------|-------------|-------------|------------|--------------|-------------")
    for i in range(len(total_times)):
        report.append(f"  {i+1:11d} | {total_times[i]:9.6f} | {connect_times[i]:11.6f} | {transfer_times[i]:11.6f} | {total_times[i] * 1000:10.2f} | {connect_times[i] * 1000:12.2f} | {transfer_times[i] * 1000:11.2f}")
    report.append("")
    
    # Statistical Analysis
    report.append("Statistical Analysis:")
    report.append("  - Coefficient of Variation (CV) indicates consistency: lower values = more consistent")
    report.append(f"  - Total Response CV:     {total_stats['cv']:.1f}%")
    report.append(f"  - TCP Connection CV:     {connect_stats['cv']:.1f}%")
    report.append(f"  - Transfer CV:           {transfer_stats['cv']:.1f}%")
    report.append("")
    
    # Notes
    report.append("Notes:")
    report.append("  - Total Response Time: Complete round-trip time including all network and HTTP processing")
    report.append("  - TCP Connection Time: Pure network delay (TCP handshake time)")
    report.append("  - Time to First Byte: Time until first response byte received (includes HTTP processing)")
    report.append("  - Standard Deviation (±): Measures jitter/variation in response times")
    report.append("  - Coefficient of Variation (CV): Standard deviation as percentage of mean (lower = more consistent)")
    
    return "\n".join(report)


def generate_console_summary(total_times: List[float], connect_times: List[float], transfer_times: List[float]) -> str:
    """Generate summary statistics for console output."""
    total_stats = calculate_stats(total_times)
    connect_stats = calculate_stats(connect_times)
    
    summary = []
    summary.append("✓ Response time analysis completed!")
    summary.append(f"  Average total response time: {total_stats['mean'] * 1000:.2f} ms (±{total_stats['std_dev'] * 1000:.2f} ms jitter)")
    summary.append(f"  Average TCP connection time: {connect_stats['mean'] * 1000:.2f} ms (±{connect_stats['std_dev'] * 1000:.2f} ms jitter)")
    summary.append(f"  Connection consistency: {connect_stats['cv']:.1f}% CV")
    
    return "\n".join(summary)


def main():
    """Main function to process timing data and output statistics."""
    if len(sys.argv) < 5:
        print("Usage: python3 calculate_response_stats.py 'total_times' 'connect_times' 'transfer_times' endpoint_url [--file output_file]")
        print("Example: python3 calculate_response_stats.py '0.089,0.078,0.085' '0.012,0.011,0.013' '0.067,0.056,0.061' 'http://1.2.3.4/status' --file report.txt")
        print("")
        print("Output modes:")
        print("  - Console only: python3 script.py total connect transfer endpoint")
        print("  - File output: python3 script.py total connect transfer endpoint --file output.txt")
        sys.exit(1)
    
    try:
        # Parse comma-separated timing values
        total_times = [float(x) for x in sys.argv[1].split(',') if x.strip()]
        connect_times = [float(x) for x in sys.argv[2].split(',') if x.strip()]
        transfer_times = [float(x) for x in sys.argv[3].split(',') if x.strip()]
        endpoint = sys.argv[4]
        
        # Generate console summary
        console_summary = generate_console_summary(total_times, connect_times, transfer_times)
        print(console_summary)
        
        # Check if file output is requested
        if len(sys.argv) >= 6 and '--file' in sys.argv:
            # Find the filename after --file
            try:
                file_index = sys.argv.index('--file') + 1
                if file_index < len(sys.argv):
                    output_file = sys.argv[file_index]
                    report = generate_report(endpoint, total_times, connect_times, transfer_times)
                    with open(output_file, 'w') as f:
                        f.write(report)
                    print(f"  Detailed results saved to: {output_file}")
                else:
                    print(f"  Warning: --file specified but no filename provided", file=sys.stderr)
            except (ValueError, IndexError, IOError) as e:
                print(f"  Warning: Could not save detailed report to file: {e}", file=sys.stderr)
        
    except ValueError as e:
        print(f"Error parsing timing values: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error calculating statistics: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()