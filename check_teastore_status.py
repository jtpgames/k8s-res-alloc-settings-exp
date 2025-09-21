#!/usr/bin/env python3
"""
TeaStore Status Checker

This script parses the HTML response from TeaStore's status endpoint and checks
if all services are running with OK status.
"""

import sys
import re
from html.parser import HTMLParser


class TeaStoreStatusParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_table = False
        self.in_row = False
        self.in_cell = False
        self.current_row = []
        self.current_cell = ""
        self.services = []
        self.cell_class = None
        
    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self.in_table = True
        elif tag == "tr" and self.in_table:
            self.in_row = True
            self.current_row = []
        elif tag == "td" and self.in_row:
            self.in_cell = True
            self.current_cell = ""
            # Check if this td has a class attribute
            self.cell_class = None
            for attr_name, attr_value in attrs:
                if attr_name == "class":
                    self.cell_class = attr_value
    
    def handle_endtag(self, tag):
        if tag == "table":
            self.in_table = False
        elif tag == "tr" and self.in_row:
            self.in_row = False
            # Process the completed row if it has 4 cells (Service, #, Host(s), Status)
            if len(self.current_row) == 4:
                service_name = self.current_row[0].strip()
                service_status = self.current_row[3].strip()
                # Skip the header row
                if service_name != "Service" and service_name != "":
                    self.services.append({
                        'name': service_name,
                        'count': self.current_row[1].strip(),
                        'hosts': self.current_row[2].strip(),
                        'status': service_status
                    })
        elif tag == "td" and self.in_cell:
            self.in_cell = False
            self.current_row.append(self.current_cell)
    
    def handle_data(self, data):
        if self.in_cell:
            self.current_cell += data


def check_teastore_status(html_content):
    """
    Parse HTML content and check TeaStore service status
    
    Args:
        html_content (str): HTML content from TeaStore status page
        
    Returns:
        tuple: (success: bool, services: list, message: str)
    """
    parser = TeaStoreStatusParser()
    try:
        parser.feed(html_content)
    except Exception as e:
        return False, [], f"Failed to parse HTML: {str(e)}"
    
    services = parser.services
    
    if not services:
        return False, [], "No services found in status page"
    
    # Expected services
    expected_services = {"WebUI", "Auth", "Persistence", "Recommender", "Image"}
    
    # Check each service
    ok_services = []
    failed_services = []
    
    for service in services:
        service_name = service['name']
        service_status = service['status']
        
        # Check if status contains "OK"
        if "OK" in service_status:
            ok_services.append(f"{service_name}: {service_status}")
        else:
            failed_services.append(f"{service_name}: {service_status}")
    
    # Create status message
    total_services = len(services)
    ok_count = len(ok_services)
    
    message_parts = [f"Found {total_services} services, {ok_count} with OK status"]
    
    if ok_services:
        message_parts.append("✓ Services OK:")
        for service in ok_services:
            message_parts.append(f"  - {service}")
    
    if failed_services:
        message_parts.append("✗ Services not OK:")
        for service in failed_services:
            message_parts.append(f"  - {service}")
    
    message = "\n".join(message_parts)
    
    # All services should be OK and we should have at least the expected services
    success = (len(failed_services) == 0 and 
               ok_count >= len(expected_services) and
               all(any(svc['name'] == expected for svc in services) for expected in expected_services))
    
    return success, services, message


def main():
    if len(sys.argv) < 2:
        print("Usage: python check_teastore_status.py <html_content_or_file>", file=sys.stderr)
        sys.exit(1)
    
    # Read HTML content from argument (could be content or file path)
    html_input = sys.argv[1]
    
    try:
        # Try to read as file first
        with open(html_input, 'r', encoding='utf-8') as f:
            html_content = f.read()
    except (FileNotFoundError, IOError):
        # If not a file, treat as direct HTML content
        html_content = html_input
    
    success, services, message = check_teastore_status(html_content)
    
    print(message)
    
    if success:
        print("\n✓ All TeaStore services are ready!")
        sys.exit(0)
    else:
        print("\n✗ TeaStore services are not all ready")
        sys.exit(1)


if __name__ == "__main__":
    main()
