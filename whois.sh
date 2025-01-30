#!/bin/bash

# Function to handle rate limiting with exponential backoff
handle_rate_limit() {
    local attempt=$1
    local wait_time=$((2 ** (attempt - 1)))
    echo "Rate limit encountered. Waiting ${wait_time} seconds before retry (attempt ${attempt}/5)..." >&2
    sleep "$wait_time"
}

# Function to process a single IP
process_ip() {
    local ip=$1
    local max_attempts=5
    local attempt=1
    local success=false
    
    echo "Processing IP: $ip"
    
    while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
        # Use whois to get the information
        whois_output=$(whois "$ip" 2>&1)
        
        # Check for rate limiting messages
        if echo "$whois_output" | grep -iE "(rate limit|too many requests|quota exceeded)" > /dev/null; then
            handle_rate_limit "$attempt"
            attempt=$((attempt + 1))
            continue
        fi
        
        # If we get here, the request was successful
        success=true
        
        # Create a temporary file for this IP's data
        temp_file=$(mktemp)
        
        # Process all fields from whois output
        echo "$whois_output" | while IFS=':' read -r key value; do
            # Skip empty lines and lines without a colon
            if [ -z "$key" ] || [ -z "$value" ]; then
                continue
            fi
            
            # Clean up the key and value
            key=$(echo "$key" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
            value=$(echo "$value" | sed 's/^[ \t]*//;s/[ \t]*$//')
            
            # Skip comments and remarks
            if [[ "$key" =~ ^(%|#|remarks|comment) ]]; then
                continue
            fi
            
            # Store the key-value pair
            echo "${key}=${value}" >> "$temp_file"
        done
        
        # Convert to CSV format with all fields
        {
            # If this is the first IP, write the headers
            if [ ! -s results.csv ]; then
                echo "ip,netname,asn,country,organization,cidr,abuse_contact,created,last_modified,registry,status" > results.csv
            fi
            
            # Extract specific fields (with fallbacks for different field names)
            netname=$(grep -E "^(netname|network-name)=" "$temp_file" | head -1 | cut -d'=' -f2-)
            asn=$(grep -E "^(originas|origin|asnumber|aut-num)=" "$temp_file" | head -1 | cut -d'=' -f2-)
            country=$(grep -E "^(country)=" "$temp_file" | head -1 | cut -d'=' -f2-)
            org=$(grep -E "^(orgname|organization|org-name|owner)=" "$temp_file" | head -1 | cut -d'=' -f2-)
            cidr=$(grep -E "^(cidr|inetnum|netrange)=" "$temp_file" | head -1 | cut -d'=' -f2-)
            abuse=$(grep -E "^(abuse-mailbox|orgabuseemail)=" "$temp_file" | head -1 | cut -d'=' -f2-)
            created=$(grep -E "^(created|regdate)=" "$temp_file" | head -1 | cut -d'=' -f2-)
            modified=$(grep -E "^(last-modified|changed)=" "$temp_file" | head -1 | cut -d'=' -f2-)
            registry=$(grep -E "^(registry|registrar)=" "$temp_file" | head -1 | cut -d'=' -f2-)
            status=$(grep -E "^(status|state)=" "$temp_file" | head -1 | cut -d'=' -f2-)
            
            # Save all raw whois data to a separate file for reference
            echo "=== WHOIS data for $ip ===" >> raw_whois_data.txt
            echo "$whois_output" >> raw_whois_data.txt
            echo -e "\n\n" >> raw_whois_data.txt
            
            # Write the CSV line
            echo "$ip,$netname,$asn,$country,$org,$cidr,$abuse,$created,$modified,$registry,$status" >> results.csv
        }
        
        # Clean up temp file
        rm -f "$temp_file"
        
        # Random sleep between 1-3 seconds to avoid rate limiting
        sleep $(( ( RANDOM % 3 ) + 1 ))
    done
    
    if [ "$success" = false ]; then
        echo "Failed to process IP $ip after $max_attempts attempts" >&2
        echo "$ip,ERROR,ERROR,ERROR,ERROR,ERROR,ERROR,ERROR,ERROR,ERROR,ERROR" >> results.csv
    fi
}

# Create/clear the results files
> results.csv
> raw_whois_data.txt

# Process each IP from the input file
while read -r ip || [[ -n "$ip" ]]; do
    # Skip empty lines
    if [[ -z "$ip" ]]; then
        continue
    fi
    
    # Clean the IP address (remove any whitespace)
    ip=$(echo "$ip" | tr -d ' ')
    
    # Validate IP format
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        process_ip "$ip"
    else
        echo "Warning: Invalid IP format: $ip" >&2
        echo "$ip,INVALID_FORMAT,,,,,,,,,," >> results.csv
    fi
done < ips.txt

echo "Processing complete. Results saved in:"
echo "1. results.csv (structured data)"
echo "2. raw_whois_data.txt (complete whois output for each IP)" 