#!/usr/bin/env python

"""
Locust Log Analyzer

Analyzes locust log files to extract response times and error counts,
creating bar charts for visualization with enhanced request count display.

Features:
- Response time analysis with request count visualization
- Detailed error categorization by HTTP status and functional types
- Success rate calculation and statistics
- PDF chart generation with experiment type detection
"""

import re
import typer
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Tuple
import matplotlib.pyplot as plt
import matplotlib.cm as cm
import numpy as np
import pandas as pd
from dataclasses import dataclass

@dataclass
class ErrorStats:
    """Data class to track different types of errors."""
    # HTTP Status Code Errors
    http_500_errors: int = 0  # Internal Server Error
    http_502_errors: int = 0  # Bad Gateway
    http_503_errors: int = 0  # Service Unavailable
    
    # Functional Errors
    login_errors: int = 0     # Login related errors
    logout_errors: int = 0    # Logout related errors
    profile_errors: int = 0   # Profile access errors
    product_errors: int = 0   # Product access/cart errors
    category_errors: int = 0  # Category browsing errors
    page_load_errors: int = 0 # Page loading errors
    
    # Legacy error types (for backward compatibility)
    timeout_errors: int = 0
    unknown_errors: int = 0
    connection_errors: int = 0
    other_errors: int = 0
    
    @property
    def total_errors(self) -> int:
        return (self.http_500_errors + self.http_502_errors + self.http_503_errors +
                self.login_errors + self.logout_errors + self.profile_errors +
                self.product_errors + self.category_errors + self.page_load_errors +
                self.timeout_errors + self.unknown_errors + self.connection_errors + self.other_errors)
    
    @property
    def total_http_errors(self) -> int:
        return self.http_500_errors + self.http_502_errors + self.http_503_errors
    
    @property 
    def total_functional_errors(self) -> int:
        return (self.login_errors + self.logout_errors + self.profile_errors +
                self.product_errors + self.category_errors + self.page_load_errors)
    
    def to_dict(self) -> Dict[str, int]:
        return {
            'HTTP 503 (Service Unavailable)': self.http_503_errors,
            'HTTP 502 (Bad Gateway)': self.http_502_errors,
            'HTTP 500 (Internal Server)': self.http_500_errors,
            'Login Errors': self.login_errors,
            'Logout Errors': self.logout_errors,
            'Profile Access Errors': self.profile_errors,
            'Product/Cart Errors': self.product_errors,
            'Category Browse Errors': self.category_errors,
            'Page Load Errors': self.page_load_errors,
            'Timeout Errors': self.timeout_errors,
            'Unknown/Empty Errors': self.unknown_errors,
            'Connection Errors': self.connection_errors,
            'Other Errors': self.other_errors
        }

app = typer.Typer()

def parse_log_file(file_path: Path) -> Tuple[Dict[str, List[float]], ErrorStats]:
    """
    Parse the locust log file to extract response times and categorized error counts.
    
    Returns:
        Tuple of (request_types_with_response_times, error_statistics)
    """
    response_times = defaultdict(list)
    error_stats = ErrorStats()
    
    # Pattern to match response time lines in INFO logs: (METHOD endpoint) Response time X ms
    response_pattern = re.compile(r'/INFO/root:\s+\(([A-Z]+\s+\w+)\)\s+Response\s+time\s+(\d+)\s+ms')
    
    # Pattern to match error lines and capture the error message
    error_pattern = re.compile(r'ERROR/root: user\d+: (.*)$')
   
    warmup_pattern = re.compile(r'Warm-Up finished.*Regular load profile starts', re.IGNORECASE)
    warmup_finished = False
    
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            for line_num, line in enumerate(file, 1):
                if not warmup_finished:
                    if warmup_pattern.search(line):
                        warmup_finished = True
                    continue

                # Check for response time entries
                response_match = response_pattern.search(line)
                if response_match:
                    request_type = response_match.group(1)
                    response_time = float(response_match.group(2))
                    response_times[request_type].append(response_time)
                
                # Check for error entries
                else:
                    error_match = error_pattern.search(line)
                    if error_match:
                        error_message = error_match.group(1).strip()
                        
                        # Categorize the error based on the message
                        error_type = "Unknown"
                        
                        if error_message == "":
                            error_stats.unknown_errors += 1
                            error_type = "Unknown/Empty"
                        elif "timed out" in error_message.lower():
                            error_stats.timeout_errors += 1
                            error_type = "Timeout"
                        elif any(conn_keyword in error_message.lower() for conn_keyword in 
                                ["connection", "connect", "refused", "reset", "closed"]):
                            error_stats.connection_errors += 1
                            error_type = "Connection"
                        # HTTP Status Code categorization
                        elif "status 500" in error_message or "status: 500" in error_message:
                            error_stats.http_500_errors += 1
                            error_type = "HTTP 500"
                        elif "status 502" in error_message or "status: 502" in error_message:
                            error_stats.http_502_errors += 1
                            error_type = "HTTP 502"
                        elif "status 503" in error_message or "status: 503" in error_message:
                            error_stats.http_503_errors += 1
                            error_type = "HTTP 503"
                        # Functional error categorization
                        elif "login" in error_message.lower() and "username" in error_message.lower():
                            error_stats.login_errors += 1
                            error_type = "Login"
                        elif "log out" in error_message.lower() or "logout" in error_message.lower():
                            error_stats.logout_errors += 1
                            error_type = "Logout"
                        elif "profile" in error_message.lower():
                            error_stats.profile_errors += 1
                            error_type = "Profile"
                        elif "product" in error_message.lower() or "cart" in error_message.lower():
                            error_stats.product_errors += 1
                            error_type = "Product/Cart"
                        elif "category" in error_message.lower():
                            error_stats.category_errors += 1
                            error_type = "Category"
                        elif "load" in error_message.lower() and ("page" in error_message.lower() or "landing" in error_message.lower()):
                            error_stats.page_load_errors += 1
                            error_type = "Page Load"
                        else:
                            error_stats.other_errors += 1
                            error_type = "Other"
                        
                        # typer.echo(f"Found {error_type} error at line {line_num}: {line.strip()}")
    
    except FileNotFoundError:
        typer.echo(f"Error: File '{file_path}' not found.", err=True)
        raise typer.Exit(1)
    except Exception as e:
        typer.echo(f"Error reading file: {e}", err=True)
        raise typer.Exit(1)
    
    return dict(response_times), error_stats

def calculate_statistics(response_times: Dict[str, List[float]]) -> pd.DataFrame:
    """Calculate average response times for each request type."""
    stats = []
    
    for request_type, times in response_times.items():
        if times:  # Only process if there are response times
            stats.append({
                'Request Type': request_type,
                'Average Response Time (ms)': sum(times) / len(times),
                'Min Response Time (ms)': min(times),
                'Max Response Time (ms)': max(times),
                'Count': len(times)
            })
    
    return pd.DataFrame(stats).sort_values('Average Response Time (ms)', ascending=False)

def create_bar_chart(stats_df: pd.DataFrame, error_stats: ErrorStats, output_dir: Path, log_file: Path):
    """Create and save bar charts for response times and error count."""
    
    # Create figure with subplots - optimized size for compact layout
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8))
    
    # Plot 1: Average Response Times by Request Type
    if not stats_df.empty:
        # Calculate total request count for title
        total_requests = stats_df['Count'].sum()
        
        # Create the primary bars for response times
        bars1 = ax1.bar(range(len(stats_df)), stats_df['Average Response Time (ms)'], 
                       color='skyblue', alpha=0.7)
        ax1.set_xlabel('Request Type')
        ax1.set_ylabel('Average Response Time (ms)', color='#2980b9')
        ax1.set_title(f'Average Response Times per Request Type (Total Requests: {total_requests:,})')
        ax1.set_xticks(range(len(stats_df)))
        ax1.set_xticklabels(stats_df['Request Type'], rotation=45, ha='right')
        ax1.grid(axis='y', alpha=0.3)
        
        # Add value labels on bars for response time
        for i, bar in enumerate(bars1):
            height = bar.get_height()
            ax1.text(bar.get_x() + bar.get_width()/2., height + height*0.01,
                    f'{height:.1f}ms', ha='center', va='bottom', fontsize=8, color='#2980b9')
            
            # Add request count below the bar labels
            count = stats_df.iloc[i]['Count']
            ax1.text(bar.get_x() + bar.get_width()/2., height/2,
                    f'{count:,}\nreqs', ha='center', va='center', 
                    fontsize=8, color='black', fontweight='bold', 
                    bbox=dict(facecolor='white', alpha=0.7, pad=1, boxstyle='round,pad=0.2'))
    else:
        ax1.text(0.5, 0.5, 'No response time data found', 
                ha='center', va='center', transform=ax1.transAxes)
        ax1.set_title('Average Response Times per Request Type')
    
    # Plot 2: Error Breakdown by Type
    error_dict = error_stats.to_dict()
    # Filter out error types with zero count for cleaner visualization
    filtered_errors = {k: v for k, v in error_dict.items() if v > 0}
    
    if filtered_errors:
        categories = list(filtered_errors.keys())
        counts = list(filtered_errors.values())
        
        # Use a broader color palette for different error types
        
        # Create a color map with distinct colors
        if len(categories) <= 8:
            colors = ['#ff6b6b', '#4ecdc4', '#45b7d1', '#f9ca24', '#f0932b', '#eb4d4b', '#6c5ce7', '#a29bfe']
        else:
            # Use colormap for many categories
            colors = cm.Set3(np.linspace(0, 1, len(categories)))
        
        bars2 = ax2.bar(categories, counts, color=colors[:len(categories)], alpha=0.8)
        ax2.set_ylabel('Error Count')
        ax2.set_title(f'Error Breakdown by Type (Total: {error_stats.total_errors})')
        ax2.set_xticks(range(len(categories)))
        ax2.set_xticklabels(categories, rotation=45, ha='right')
        ax2.grid(axis='y', alpha=0.3)
        
        # Add value labels on bars
        for bar, count in zip(bars2, counts):
            ax2.text(bar.get_x() + bar.get_width()/2., count + count*0.01,
                    f'{count}', ha='center', va='bottom', fontsize=10, fontweight='bold')
    else:
        ax2.text(0.5, 0.5, 'No errors found', 
                ha='center', va='center', transform=ax2.transAxes, fontsize=14)
        ax2.set_title('Error Breakdown by Type')
        ax2.set_ylabel('Error Count')
    
    # Optimize spacing between subplots for compact layout
    plt.subplots_adjust(hspace=0.4)  # Reduce vertical spacing between subplots
    plt.tight_layout(pad=1.0)  # Reduce overall padding
    
    # Save the plot as a vector PDF with experiment type prefix
    # Get experiment type from the second parent directory of the log file path
    try:
        # Attempt to get the experiment type from the second parent directory
        experiment_type = log_file.parent.parent.name
        output_filename = f'{experiment_type}_locust_analysis_results.pdf'
    except (AttributeError, IndexError):
        # Fallback if we can't determine the experiment type
        output_filename = 'locust_analysis_results.pdf'
        typer.echo("Warning: Could not determine experiment type from log file path")
    
    output_file = output_dir / output_filename
    plt.savefig(output_file, format='pdf', bbox_inches='tight')
    typer.echo(f"Chart saved to: {output_file}")
    
    # Show the plot
    # plt.show()

def print_summary(stats_df: pd.DataFrame, error_stats: ErrorStats):
    """Print a summary of the analysis results."""
    typer.echo("\n" + "="*60)
    typer.echo("LOCUST LOG ANALYSIS SUMMARY")
    typer.echo("="*60)
    
    if not stats_df.empty:
        total_requests = stats_df['Count'].sum()
        typer.echo(f"\nFound {len(stats_df)} different request types:")
        typer.echo(f"Total Requests Processed: {total_requests:,}")
        typer.echo("\nResponse Time Statistics:")
        typer.echo(stats_df.to_string(index=False, float_format='%.2f'))
        
        typer.echo(f"\nTop 3 slowest request types:")
        for i, row in stats_df.head(3).iterrows():
            typer.echo(f"  {i+1}. {row['Request Type']}: {row['Average Response Time (ms)']:.2f}ms "
                      f"(Count: {row['Count']})")
    else:
        typer.echo("\nNo response time data found in the log file.")
    
    # Print detailed error statistics with success rate
    typer.echo(f"\nRequest Completion Statistics:")
    if not stats_df.empty:
        total_requests = stats_df['Count'].sum()
        success_rate = ((total_requests - error_stats.total_errors) / total_requests * 100) if total_requests > 0 else 0
        typer.echo(f"  Total Requests: {total_requests:,}")
        typer.echo(f"  Successful Requests: {total_requests - error_stats.total_errors:,} ({success_rate:.1f}%)")
    typer.echo(f"  Total Errors: {error_stats.total_errors}")
    
    if error_stats.total_errors > 0:
        # Show HTTP errors summary
        if error_stats.total_http_errors > 0:
            typer.echo(f"\n  HTTP Status Code Errors: {error_stats.total_http_errors} ({(error_stats.total_http_errors / error_stats.total_errors * 100):.1f}%)")
            if error_stats.http_503_errors > 0:
                typer.echo(f"    - HTTP 503 (Service Unavailable): {error_stats.http_503_errors}")
            if error_stats.http_502_errors > 0:
                typer.echo(f"    - HTTP 502 (Bad Gateway): {error_stats.http_502_errors}")
            if error_stats.http_500_errors > 0:
                typer.echo(f"    - HTTP 500 (Internal Server Error): {error_stats.http_500_errors}")
        
        # Show functional errors summary
        if error_stats.total_functional_errors > 0:
            typer.echo(f"\n  Functional Errors: {error_stats.total_functional_errors} ({(error_stats.total_functional_errors / error_stats.total_errors * 100):.1f}%)")
            if error_stats.profile_errors > 0:
                typer.echo(f"    - Profile Access Errors: {error_stats.profile_errors}")
            if error_stats.logout_errors > 0:
                typer.echo(f"    - Logout Errors: {error_stats.logout_errors}")
            if error_stats.login_errors > 0:
                typer.echo(f"    - Login Errors: {error_stats.login_errors}")
            if error_stats.category_errors > 0:
                typer.echo(f"    - Category Browse Errors: {error_stats.category_errors}")
            if error_stats.product_errors > 0:
                typer.echo(f"    - Product/Cart Errors: {error_stats.product_errors}")
            if error_stats.page_load_errors > 0:
                typer.echo(f"    - Page Load Errors: {error_stats.page_load_errors}")
        
        # Show other error types if any
        other_total = (error_stats.timeout_errors + error_stats.unknown_errors + 
                      error_stats.connection_errors + error_stats.other_errors)
        if other_total > 0:
            typer.echo(f"\n  Other Errors: {other_total} ({(other_total / error_stats.total_errors * 100):.1f}%)")
            if error_stats.timeout_errors > 0:
                typer.echo(f"    - Timeout Errors: {error_stats.timeout_errors}")
            if error_stats.unknown_errors > 0:
                typer.echo(f"    - Unknown/Empty Errors: {error_stats.unknown_errors}")
            if error_stats.connection_errors > 0:
                typer.echo(f"    - Connection Errors: {error_stats.connection_errors}")
            if error_stats.other_errors > 0:
                typer.echo(f"    - Other Errors: {error_stats.other_errors}")
        
        typer.echo("\n⚠️  There were errors during the load test. Check the error messages above.")
    else:
        typer.echo("\n✅ No errors found in the log file.")

@app.command()
def analyze(
    log_file: Path = typer.Argument(..., help="Path to the locust log file to analyze"),
    output_dir: Path = typer.Option(None, "--output-dir", "-o", help="Directory to save the chart (defaults to log file directory)")
):
    """
    Analyze a locust log file and create bar charts showing:
    1. Average response times per request type (with request counts displayed)
    2. Total number of errors by category
    
    The response time chart now includes:
    - Total request count in the title
    - Individual request counts displayed within each bar
    """
    
    # Validate input file
    if not log_file.exists():
        typer.echo(f"Error: Log file '{log_file}' does not exist.", err=True)
        raise typer.Exit(1)
    
    if not log_file.is_file():
        typer.echo(f"Error: '{log_file}' is not a file.", err=True)
        raise typer.Exit(1)
    
    # Set output directory
    if output_dir is None:
        output_dir = log_file.parent
    else:
        output_dir.mkdir(parents=True, exist_ok=True)
    
    typer.echo(f"Analyzing log file: {log_file}")
    typer.echo(f"Output directory: {output_dir}")
    
    # Parse the log file
    typer.echo("Parsing log file...")
    response_times, error_stats = parse_log_file(log_file)
    
    if not response_times:
        typer.echo("No response time data found in the log file.")
        if error_stats.total_errors == 0:
            typer.echo("No errors found either. Please check the log file format.")
            raise typer.Exit(1)
    
    # Calculate statistics
    typer.echo("Calculating statistics...")
    stats_df = calculate_statistics(response_times)
    
    # Create and save charts
    typer.echo("Creating charts...")
    create_bar_chart(stats_df, error_stats, output_dir, log_file)
    
    # Print summary
    print_summary(stats_df, error_stats)
    
    typer.echo(f"\n✅ Analysis complete! Results saved to {output_dir}")

if __name__ == "__main__":
    app()
