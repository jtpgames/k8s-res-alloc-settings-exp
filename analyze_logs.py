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
from typing import Dict, List, Tuple, Optional
import matplotlib.pyplot as plt
import matplotlib.cm as cm
import numpy as np
import pandas as pd
from dataclasses import dataclass

@dataclass
class FileData:
    """Data class to store parsed data from a single log file."""
    file_path: Path
    response_times: Dict[str, List[float]]
    error_stats: 'ErrorStats'
    file_label: str  # Human-readable label for the file

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

def parse_multiple_log_files(log_files: List[Path]) -> List[FileData]:
    """
    Parse multiple log files and return a list of FileData objects.
    
    Args:
        log_files: List of Path objects pointing to log files
        
    Returns:
        List of FileData objects containing parsed data from each file
    """
    file_data_list = []
    
    for log_file in log_files:
        typer.echo(f"Parsing {log_file.name}...")
        response_times, error_stats = parse_log_file(log_file)
        
        # Create a human-readable label using experiment type
        try:
            experiment_type = log_file.parent.parent.name
            file_label = experiment_type
        except (AttributeError, IndexError):
            # Fallback to filename if we can't determine experiment type
            file_label = log_file.stem
        
        file_data = FileData(
            file_path=log_file,
            response_times=response_times,
            error_stats=error_stats,
            file_label=file_label
        )
        file_data_list.append(file_data)
    
    return file_data_list

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
    """Calculate average response times for each request type (single file)."""
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
    
    if not stats:
        return pd.DataFrame(columns=['Request Type', 'Average Response Time (ms)', 'Min Response Time (ms)', 'Max Response Time (ms)', 'Count'])
    return pd.DataFrame(stats).sort_values('Average Response Time (ms)', ascending=False)

def calculate_multi_file_statistics(file_data_list: List[FileData]) -> pd.DataFrame:
    """Calculate statistics for multiple files, keeping file information."""
    all_stats = []
    
    for file_data in file_data_list:
        for request_type, times in file_data.response_times.items():
            if times:  # Only process if there are response times
                all_stats.append({
                    'Request Type': request_type,
                    'File': file_data.file_label,
                    'Average Response Time (ms)': sum(times) / len(times),
                    'Min Response Time (ms)': min(times),
                    'Max Response Time (ms)': max(times),
                    'Count': len(times)
                })
    
    return pd.DataFrame(all_stats).sort_values(['Request Type', 'File'])

def create_bar_chart(stats_df: pd.DataFrame, error_stats: ErrorStats, output_dir: Path, log_file: Path):
    """Create and save bar charts for response times and error count (single file)."""
    
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
        
        # Create a color map with distinct colors
        if len(categories) <= 8:
            colors = ['#ff6b6b', '#4ecdc4', '#45b7d1', '#f9ca24', '#f0932b', '#eb4d4b', '#6c5ce7', '#a29bfe']
        else:
            # Use colormap for many categories
            colors = plt.colormaps['Set3'](np.linspace(0, 1, len(categories)))
        
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

def create_multi_file_bar_chart(file_data_list: List[FileData], output_dir: Path, 
                                omit_request_count_per_bar_labels: bool = False,
                                simple_title: bool = False,
                                publication_ready: bool = False,
                                export_svg: bool = False):
    """Create and save bar charts for multiple files using textures to distinguish files."""
    
    # Set publication-ready styling
    if publication_ready:
        plt.rcParams.update({
            'font.size': 14,
            'axes.titlesize': 16,
            'axes.labelsize': 14,
            'xtick.labelsize': 12,
            'ytick.labelsize': 12,
            'legend.fontsize': 12,
            'font.family': 'serif',
            'font.serif': ['Times', 'Times New Roman', 'DejaVu Serif'],
            'mathtext.fontset': 'dejavuserif',
            # LaTeX text rendering for crisp output
            'text.usetex': True,
            'text.latex.preamble': r'\usepackage{times}',
            'pdf.fonttype': 42,     # TrueType fonts (not bitmap)
            'ps.fonttype': 42,      # TrueType fonts (not bitmap)
            'svg.fonttype': 'none', # Keep text as text in SVG
            'axes.unicode_minus': False,  # Use LaTeX minus sign
        })
        figsize = (12, 8)  # Standard column width for papers
        # figsize = (6.5, 4.5)  # Two-column width (~3.25" per column)
    else:
        figsize = (14, 10)
    
    # Create figure with subplots - optimized size for papers
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=figsize)
    
    # Define hatching patterns for different files - improved for better visibility
    hatch_patterns = ['', '///', '\\\\', '|||', '---', '+++', 'xxx', 'ooo']
    
    # Collect all request types across all files
    all_request_types = set()
    for file_data in file_data_list:
        all_request_types.update(file_data.response_times.keys())
    all_request_types = sorted(all_request_types)
    
    # Plot 1: Average Response Times by Request Type (Multiple Files)
    if all_request_types:
        bar_width = 0.8 / len(file_data_list)  # Width of each bar group
        x_positions = np.arange(len(all_request_types))
        
        # Calculate per-file totals for title
        file_totals = []
        
        # Academic-friendly color palette (colorblind safe)
        colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd', '#8c564b', '#e377c2', '#7f7f7f']
        
        if len(file_data_list) > 8:
            # Use colormap for many categories
            colors = plt.colormaps['tab10'](np.linspace(0, 1, len(file_data_list)))

        for i, file_data in enumerate(file_data_list):
            file_response_times = []
            file_request_counts = []
            file_total_requests = 0

            color_to_use = colors[i]
            
            for request_type in all_request_types:
                if request_type in file_data.response_times and file_data.response_times[request_type]:
                    times = file_data.response_times[request_type]
                    avg_time = sum(times) / len(times)
                    count = len(times)
                else:
                    avg_time = 0
                    count = 0
                
                file_response_times.append(avg_time)
                file_request_counts.append(count)
                file_total_requests += count
            
            file_totals.append(file_total_requests)
           
            
            # Create bars for this file with specific texture
            hatch = hatch_patterns[i % len(hatch_patterns)]
            edge_width = 1.0 if publication_ready else 0.5
            alpha_val = 0.8 if publication_ready else 0.7
            bars = ax1.bar(x_positions + i * bar_width, file_response_times, 
                          bar_width, label=file_data.file_label,
                          color=color_to_use, alpha=alpha_val, hatch=hatch, 
                          edgecolor='black', linewidth=edge_width)
           
            # Add value labels on bars
            for j, (bar, avg_time, count) in enumerate(zip(bars, file_response_times, file_request_counts)):
                if avg_time > 0:  # Only label non-zero bars
                    height = bar.get_height()
                    ax1.text(bar.get_x() + bar.get_width()/2., height + height*0.01,
                            f'{avg_time:.0f}ms', ha='center', va='bottom', fontsize=8, fontweight='bold')
                   
                    if not omit_request_count_per_bar_labels:
                        # Add request count in the middle of the bar
                        if count > 0:
                            ax1.text(bar.get_x() + bar.get_width()/2., height/2,
                                    f'{count}', ha='center', va='center', 
                                    fontsize=6, color='black', fontweight='bold')
        
        # ax1.set_xlabel('Request Type', fontweight='bold')
        ax1.set_ylabel('Average Response Time (ms)', fontweight='bold')
       
        if not simple_title:
            # Create title with per-file request counts
            title_parts = []
            for file_data, total in zip(file_data_list, file_totals):
                title_parts.append(f'{file_data.file_label}: {total:,}')
            title_suffix = ' | '.join(title_parts)
            title_suffix = f"\n({title_suffix})"
        else:
            title_suffix = ""
        ax1.set_title(f'Average Response Times per Request Type {title_suffix}')
        
        ax1.set_xticks(x_positions + bar_width * (len(file_data_list) - 1) / 2)
        ax1.set_xticklabels(all_request_types, rotation=45, ha='right')
        ax1.grid(axis='y', alpha=0.3, linestyle='--', linewidth=0.5)

        # Add vertical headroom so legend does not overlap tallest bars
        ax1.margins(y=0.50)
        
        # Improve legend positioning
        ax1.legend(loc='upper right', frameon=True, fancybox=True, shadow=False)
    else:
        ax1.text(0.5, 0.5, 'No response time data found', 
                ha='center', va='center', transform=ax1.transAxes)
        ax1.set_title('Average Response Times per Request Type - Multiple Files')
    
    # Plot 2: Error Breakdown by Type (Per File with Textures)
    # Collect all error types across all files
    all_error_types = set()
    for file_data in file_data_list:
        error_dict = file_data.error_stats.to_dict()
        filtered_errors = {k: v for k, v in error_dict.items() if v > 0}
        all_error_types.update(filtered_errors.keys())
    
    all_error_types = sorted(all_error_types)
    
    if all_error_types:
        error_bar_width = 0.8 / len(file_data_list)  # Width of each error bar group
        error_x_positions = np.arange(len(all_error_types))
        
        # Calculate total errors per file for title
        file_error_totals = []
        
        for i, file_data in enumerate(file_data_list):
            file_error_counts = []
            
            # Get error counts for this file for each error type
            error_dict = file_data.error_stats.to_dict()
            for error_type in all_error_types:
                count = error_dict.get(error_type, 0)
                file_error_counts.append(count)
            
            file_error_totals.append(file_data.error_stats.total_errors)
            
            # Create bars for this file with specific texture
            hatch = hatch_patterns[i % len(hatch_patterns)]
            edge_width = 1.0 if publication_ready else 0.5
            
            # Use professional color palette for error types
            error_colors = ['#d62728', '#ff7f0e', '#2ca02c', '#1f77b4', '#9467bd', '#8c564b', '#e377c2', '#7f7f7f']
            if len(all_error_types) > 8:
                error_colors = plt.colormaps['tab10'](np.linspace(0, 1, len(all_error_types)))
            
            # For error bars, we'll use the same color for each error type but different textures for files
            bars = ax2.bar(error_x_positions + i * error_bar_width, file_error_counts, 
                          error_bar_width, label=file_data.file_label,
                          color=error_colors[:len(all_error_types)], alpha=0.8, 
                          hatch=hatch, edgecolor='black', linewidth=edge_width)
            
            # Add value labels on bars (only for non-zero values)
            for j, (bar, count) in enumerate(zip(bars, file_error_counts)):
                if count > 0:  # Only label non-zero bars
                    height = bar.get_height()
                    ax2.text(bar.get_x() + bar.get_width()/2., height + height*0.01,
                            f'{count}', ha='center', va='bottom', fontsize=8, fontweight='bold')
        
        ax2.set_ylabel('Error Count', fontweight='bold')

        if not simple_title:
            # Create title with per-file error totals
            error_title_parts = []
            for file_data, total in zip(file_data_list, file_error_totals):
                error_title_parts.append(f'{file_data.file_label}: {total}')
            error_title_suffix = ' | '.join(error_title_parts)
            error_title_suffix = f"\n({error_title_suffix})"
        else:
            error_title_suffix = ""
        ax2.set_title(f'Error Breakdown by Type per Error Type {error_title_suffix}')
        
        ax2.set_xticks(error_x_positions + error_bar_width * (len(file_data_list) - 1) / 2)
        ax2.set_xticklabels(all_error_types, rotation=45, ha='right')
        ax2.grid(axis='y', alpha=0.3, linestyle='--', linewidth=0.5)
        
        # Add vertical headroom so legend does not overlap tallest bars
        ax2.margins(y=0.15)

        # Improve legend positioning
        ax2.legend(loc='upper right', frameon=True, fancybox=True, shadow=False)
    else:
        ax2.text(0.5, 0.5, 'No errors found', 
                ha='center', va='center', transform=ax2.transAxes)
        ax2.set_title('Error Breakdown by Type - Multiple Files')
        ax2.set_ylabel('Error Count')
    
    # Optimize spacing between subplots for better readability
    if publication_ready:
        plt.subplots_adjust(hspace=0.5)  # More space for publication
        plt.tight_layout(pad=1.5)  # More padding for cleaner look
    else:
        plt.subplots_adjust(hspace=0.4)
        plt.tight_layout(pad=1.0)
    
    # Generate output filename for multiple files
    if len(file_data_list) == 1:
        output_filename = f'{file_data_list[0].file_label}_locust_analysis_results.pdf'
    else:
        file_labels = '_vs_'.join([fd.file_label for fd in file_data_list[:3]])  # Limit to first 3 for filename
        if len(file_data_list) > 3:
            file_labels += '_and_more'
        output_filename = f'multi_file_comparison_{file_labels}.pdf'
    
    output_file = output_dir / output_filename
    
    # Save with publication-quality settings optimized for small two-column figures
    if publication_ready:
        plt.savefig(output_file, format='pdf', 
                   bbox_inches='tight',    # Remove extra whitespace
                   dpi=600,               # Higher DPI for small figures (better text clarity)
                   facecolor='white',     # Clean background
                   edgecolor='none',      # No border
                   pad_inches=0.02,       # Minimal padding for compact layout
                   transparent=False)     # Solid background for print
        
        # Also export SVG for LaTeX if requested
        if export_svg:
            svg_file = output_file.with_suffix('.svg')
            plt.savefig(svg_file, format='svg', bbox_inches='tight',
                       facecolor='white', edgecolor='none', pad_inches=0.02)
            typer.echo(f"SVG version saved to: {svg_file}")
    else:
        plt.savefig(output_file, format='pdf', bbox_inches='tight')
    
    typer.echo(f"Multi-file chart saved to: {output_file}")
    
    # Show the plot
    # plt.show()

def print_summary(stats_df: pd.DataFrame, error_stats: ErrorStats):
    """Print a summary of the analysis results (single file)."""
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

def print_multi_file_summary(file_data_list: List[FileData]):
    """Print a summary of the analysis results for multiple files."""
    typer.echo("\n" + "="*80)
    typer.echo("MULTI-FILE LOCUST LOG ANALYSIS SUMMARY")
    typer.echo("="*80)
    
    # Summary for each file
    for i, file_data in enumerate(file_data_list, 1):
        typer.echo(f"\n[{i}] FILE: {file_data.file_path.name}")
        typer.echo("-" * 60)
        
        # Calculate stats for this file
        stats_df = calculate_statistics(file_data.response_times)
        
        if not stats_df.empty:
            total_requests = stats_df['Count'].sum()
            typer.echo(f"Request Types: {len(stats_df)}")
            typer.echo(f"Total Requests: {total_requests:,}")
            
            # Show top 3 slowest for this file
            typer.echo(f"Top 3 slowest request types:")
            for j, row in stats_df.head(3).iterrows():
                typer.echo(f"  {j+1}. {row['Request Type']}: {row['Average Response Time (ms)']:.2f}ms "
                          f"(Count: {row['Count']})")
        else:
            typer.echo("No response time data found.")
            total_requests = 0
        
        # Error statistics for this file
        error_stats = file_data.error_stats
        if total_requests > 0:
            success_rate = ((total_requests - error_stats.total_errors) / total_requests * 100) if total_requests > 0 else 0
            typer.echo(f"Successful Requests: {total_requests - error_stats.total_errors:,} ({success_rate:.1f}%)")
        typer.echo(f"Total Errors: {error_stats.total_errors}")
        
        if error_stats.total_errors > 0:
            # Show main error categories for this file
            if error_stats.total_http_errors > 0:
                typer.echo(f"  HTTP Errors: {error_stats.total_http_errors}")
            if error_stats.total_functional_errors > 0:
                typer.echo(f"  Functional Errors: {error_stats.total_functional_errors}")
    
    # Combined statistics
    typer.echo("\n" + "="*60)
    typer.echo("COMBINED STATISTICS")
    typer.echo("="*60)
    
    # Calculate combined totals
    total_requests_all = 0
    total_errors_all = 0
    combined_request_types = set()
    
    for file_data in file_data_list:
        stats_df = calculate_statistics(file_data.response_times)
        if not stats_df.empty:
            total_requests_all += stats_df['Count'].sum()
        total_errors_all += file_data.error_stats.total_errors
        combined_request_types.update(file_data.response_times.keys())
    
    typer.echo(f"Total Files Analyzed: {len(file_data_list)}")
    typer.echo(f"Unique Request Types: {len(combined_request_types)}")
    typer.echo(f"Total Requests (All Files): {total_requests_all:,}")
    
    if total_requests_all > 0:
        success_rate_combined = ((total_requests_all - total_errors_all) / total_requests_all * 100)
        typer.echo(f"Successful Requests (All Files): {total_requests_all - total_errors_all:,} ({success_rate_combined:.1f}%)")
    
    typer.echo(f"Total Errors (All Files): {total_errors_all}")
    
    if total_errors_all == 0:
        typer.echo("\n✅ No errors found across all log files.")
    else:
        typer.echo("\n⚠️  There were errors in the analyzed log files.")

@app.command()
def analyze(
    log_files: List[Path] = typer.Argument(..., help="Path(s) to the locust log file(s) to analyze"),
    output_dir: Path = typer.Option(None, "--output-dir", "-o", help="Directory to save the chart (defaults to first log file directory)"),
    publication_ready: bool = typer.Option(False, "--publication", "-p", help="Generate publication-ready plots with academic styling"),
    export_svg: bool = typer.Option(False, "--svg", help="Also export SVG format for better LaTeX compatibility")
):
    """
    Analyze one or more locust log files and create bar charts showing:
    1. Average response times per request type (with request counts displayed)
    2. Total number of errors by category
    
    When multiple files are provided, data from all files will be plotted
    in the same chart with different textures/patterns to distinguish between files.
    
    The response time chart now includes:
    - Total request count in the title
    - Individual request counts displayed within each bar
    """
    
    # Validate input files
    for log_file in log_files:
        if not log_file.exists():
            typer.echo(f"Error: Log file '{log_file}' does not exist.", err=True)
            raise typer.Exit(1)
        
        if not log_file.is_file():
            typer.echo(f"Error: '{log_file}' is not a file.", err=True)
            raise typer.Exit(1)
    
    # Set output directory
    if output_dir is None:
        output_dir = log_files[0].parent  # Use first file's directory
    else:
        output_dir.mkdir(parents=True, exist_ok=True)
    
    # Handle single vs multiple files
    if len(log_files) == 1:
        # Single file - use original logic
        log_file = log_files[0]
        typer.echo(f"Analyzing single log file: {log_file}")
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
        
    else:
        # Multiple files - use new logic
        typer.echo(f"Analyzing {len(log_files)} log files:")
        for log_file in log_files:
            typer.echo(f"  - {log_file}")
        typer.echo(f"Output directory: {output_dir}")
        
        # Parse all log files
        typer.echo("\nParsing log files...")
        file_data_list = parse_multiple_log_files(log_files)
        
        # Check if any files have data
        has_data = False
        for file_data in file_data_list:
            if file_data.response_times or file_data.error_stats.total_errors > 0:
                has_data = True
                break
        
        if not has_data:
            typer.echo("No response time data or errors found in any log file.")
            typer.echo("Please check the log file formats.")
            raise typer.Exit(1)
        
        # Create and save charts
        typer.echo("\nCreating multi-file comparison charts...")
        create_multi_file_bar_chart(file_data_list, output_dir, omit_request_count_per_bar_labels=True, 
                                   simple_title=True, publication_ready=publication_ready, 
                                   export_svg=export_svg)
        
        # Print summary
        print_multi_file_summary(file_data_list)
    
    typer.echo(f"\n✅ Analysis complete! Results saved to {output_dir}")

if __name__ == "__main__":
    app()
