# WHOIS IP Lookup Script

A bash script that performs bulk WHOIS lookups for IP addresses and outputs structured data in CSV format along with raw WHOIS information.

## Features

- Bulk processing of IP addresses
- Rate limit handling with exponential backoff
- Structured output in CSV format
- Complete raw WHOIS data preservation
- IP format validation
- Error handling and retry logic

## Prerequisites

- Unix-like operating system (Linux, macOS)
- `whois` command-line tool installed
- Bash shell

## Installation

1. Clone this repository or download the script
2. Make the script executable:
   ```bash
   chmod +x whois.sh
   ```

## Usage

1. Create a file named `ips.txt` in the same directory as the script
2. Add IP addresses to `ips.txt`, one per line, for example:
   ```
   8.8.8.8
   1.1.1.1
   ```
3. Run the script:
   ```bash
   ./whois.sh
   ```

## Output Files

The script generates two output files:

### 1. results.csv

A structured CSV file containing the following fields for each IP:
- IP address
- Network name
- ASN (Autonomous System Number)
- Country
- Organization
- CIDR
- Abuse contact
- Creation date
- Last modified date
- Registry
- Status

### 2. raw_whois_data.txt

Contains the complete, unprocessed WHOIS output for each IP address for reference.

## Error Handling

The script includes several error handling mechanisms:

- **Rate Limiting**: Implements exponential backoff when rate limits are encountered
- **Invalid IPs**: Marks invalid IP formats in the CSV output
- **Retry Logic**: Attempts up to 5 times with increasing delays for failed queries
- **Field Parsing**: Handles various WHOIS output formats and field names

## Field Mapping

The script attempts to map various WHOIS field names to standardized output:

- Network Name: `netname`, `network-name`
- ASN: `originas`, `origin`, `asnumber`, `aut-num`
- Organization: `orgname`, `organization`, `org-name`, `owner`
- CIDR: `cidr`, `inetnum`, `netrange`
- Abuse Contact: `abuse-mailbox`, `orgabuseemail`
- Created Date: `created`, `regdate`
- Modified Date: `last-modified`, `changed`
- Registry: `registry`, `registrar`
- Status: `status`, `state`

## Rate Limiting

To avoid overwhelming WHOIS servers, the script:
- Implements exponential backoff (2^n seconds) on rate limits
- Adds random delays (1-3 seconds) between queries
- Retries up to 5 times per IP

## Notes

- Comments and remarks from WHOIS output are filtered out
- Empty fields in the CSV output indicate that the information was not available in the WHOIS data
- If an IP fails all retry attempts, it will be marked with "ERROR" in all fields in the CSV 