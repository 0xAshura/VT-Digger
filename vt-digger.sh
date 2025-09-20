#!/bin/bash

# =====================================================
# VTSubEnumerator - VirusTotal Subdomain Enumeration Tool
# by Mihir Limbad (0xAshura)
# =====================================================

# Default values
API_KEYS=()
DOMAINS=()
OUTPUT_FILE="vt_subdomains.txt"
SUBDOMAINS_ONLY=false
REQUEST_DELAY=15
VERBOSE=false
MAX_REQUESTS_PER_KEY=500
RECURSIVE=false
declare -A PROCESSED_DOMAINS

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ASCII Art Banner
print_banner() {
    echo -e "${MAGENTA}"
    echo " ██╗   ██╗████████╗   ██████╗ ██╗ ██████╗  ██████╗ ███████╗██████╗   "
    echo " ██╗   ██║╚══██╔══╝   ██╔══██╗██║██╔════╝ ██╔════╝ ██╔════╝██╔══██╗  "
    echo " ██║   ██║   ██║█████╗██║  ██║██║██║  ███╗██║  ███╗█████╗  ██████╔╝  "
    echo " ╚██╗ ██╔╝   ██║╚════╝██║  ██║██║██║   ██║██║   ██║██╔══╝  ██╔══██╗  "
    echo " ╚██╗ ██╔╝   ██║╚════╝██║  ██║██║██║   ██║██║   ██║██╔══╝  ██╔══██╗  "
    echo "  ╚████╔╝    ██║      ██████╔╝██║╚██████╔╝╚██████╔╝███████╗██║  ██║  "
    echo "   ╚═══╝     ╚═╝      ╚═════╝ ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝  "
    echo -e "${CYAN}"
    echo "                    VirusTotal Subdomain Enumeration Tool"
    echo "                         by Mihir Limbad (0xAshura)"
    echo -e "${NC}"
    echo "================================================================================"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -d, --domain DOMAIN        Single domain to query"
    echo "  -f, --file FILE            File containing list of domains (one per line)"
    echo "  -k, --keys FILE            File containing API keys (one per line)"
    echo "  -o, --output FILE          Output file (default: vt_subdomains.txt)"
    echo "  -s, --subdomains-only      Output only subdomains without the root domain"
    echo "  -r, --recursive            Enable recursive subdomain enumeration"
    echo "  -D, --delay SECONDS        Delay between requests (default: 15)"
    echo "  -v, --verbose              Enable verbose output"
    echo "  -h, --help                 Show this help message"
    exit 1
}

# Function to print verbose messages
log() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}[INFO]${NC} $1"
    fi
}

# Function to print error messages
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to print success messages
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to print section headers
section() {
    echo -e "${BLUE}"
    echo "================================================================================="
    echo "$1"
    echo "================================================================================="
    echo -e "${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAINS+=("$2")
            shift 2
            ;;
        -f|--file)
            if [ -f "$2" ]; then
                while IFS= read -r line; do
                    if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
                        DOMAINS+=("$line")
                    fi
                done < "$2"
            else
                error "File $2 not found!"
                exit 1
            fi
            shift 2
            ;;
        -k|--keys)
            if [ -f "$2" ]; then
                while IFS= read -r line; do
                    if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
                        API_KEYS+=("$line")
                    fi
                done < "$2"
            else
                error "File $2 not found!"
                exit 1
            fi
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -s|--subdomains-only)
            SUBDOMAINS_ONLY=true
            shift
            ;;
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -D|--delay)
            REQUEST_DELAY="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            print_banner
            usage
            ;;
        *)
            error "Unknown option: $1"
            usage
            ;;
    esac
done

# Print banner
print_banner

# Validate inputs
if [ ${#DOMAINS[@]} -eq 0 ]; then
    error "No domains specified. Use -d or -f option."
    usage
fi

if [ ${#API_KEYS[@]} -eq 0 ]; then
    error "No API keys specified. Use -k option."
    usage
fi

# Initialize variables
KEY_INDEX=0
TOTAL_SUBDOMAINS=0
TOTAL_REQUESTS=0
declare -A REQUESTS_PER_KEY
declare -A LAST_REQUEST_TIME

# Initialize requests counter for each key
for key in "${API_KEYS[@]}"; do
    REQUESTS_PER_KEY["$key"]=0
    LAST_REQUEST_TIME["$key"]=0
done

# Create or clear the output file
> "$OUTPUT_FILE"

section "Starting VirusTotal Subdomain Enumeration"
log "Domains to process: ${#DOMAINS[@]}"
log "API keys available: ${#API_KEYS[@]}"
log "Maximum requests per key: $MAX_REQUESTS_PER_KEY"
log "Minimum delay between requests: ${REQUEST_DELAY}s"
log "Recursive mode: $RECURSIVE"

# Function to get the next available API key
get_next_key() {
    local current_time=$(date +%s)
    local attempts=0
    local max_attempts=${#API_KEYS[@]}
    
    while [ $attempts -lt $max_attempts ]; do
        KEY_INDEX=$(( (KEY_INDEX + 1) % ${#API_KEYS[@]} ))
        attempts=$((attempts + 1))
        
        local key="${API_KEYS[$KEY_INDEX]}"
        local request_count=${REQUESTS_PER_KEY["$key"]}
        local last_request=${LAST_REQUEST_TIME["$key"]}
        local time_since_last=$((current_time - last_request))
        
        # Check if key has available requests and sufficient time has passed
        if [ $request_count -lt $MAX_REQUESTS_PER_KEY ] && [ $time_since_last -ge $REQUEST_DELAY ]; then
            echo "$key"
            return 0
        fi
    done
    
    # If no key is immediately available, wait and try again
    local min_wait=$REQUEST_DELAY
    for key in "${API_KEYS[@]}"; do
        local request_count=${REQUESTS_PER_KEY["$key"]}
        local last_request=${LAST_REQUEST_TIME["$key"]}
        local time_since_last=$((current_time - last_request))
        
        if [ $request_count -lt $MAX_REQUESTS_PER_KEY ]; then
            local wait_time=$((REQUEST_DELAY - time_since_last))
            if [ $wait_time -lt $min_wait ] && [ $wait_time -gt 0 ]; then
                min_wait=$wait_time
            fi
        fi
    done
    
    log "Waiting ${min_wait}s for API key cooldown..."
    sleep $min_wait
    get_next_key
}

# Function to process a domain with all its pages
process_domain() {
    local domain="$1"
    local next_url="${2:-null}"
    local page="${3:-1}"
    
    # Get next available API key
    API_KEY=$(get_next_key)
    if [ -z "$API_KEY" ]; then
        error "No available API keys with remaining quota for $domain"
        return 1
    fi
    
    # Update request count and time
    REQUESTS_PER_KEY["$API_KEY"]=$((REQUESTS_PER_KEY["$API_KEY"] + 1))
    LAST_REQUEST_TIME["$API_KEY"]=$(date +%s)
    TOTAL_REQUESTS=$((TOTAL_REQUESTS + 1))
    
    # Build the URL
    if [ "$next_url" = "null" ]; then
        URL="https://www.virustotal.com/api/v3/domains/$domain/relationships/subdomains?limit=40"
    else
        URL="$next_url"
    fi
    
    log "Fetching page $page for $domain (Request #${TOTAL_REQUESTS})"
    log "Using API key ${KEY_INDEX} with ${REQUESTS_PER_KEY["$API_KEY"]}/$MAX_REQUESTS_PER_KEY requests"
    
    # Make API request
    RESPONSE=$(curl -s -H "accept: application/json" -H "x-apikey: $API_KEY" "$URL")
    
    # Check if we got a valid response
    if echo "$RESPONSE" | jq -e '.data' > /dev/null 2>&1; then
        # Extract subdomains
        if [ "$SUBDOMAINS_ONLY" = true ]; then
            # Extract only the subdomain part (before the domain)
            SUBS=$(echo "$RESPONSE" | jq -r '.data[].id' | sed "s/\.$domain\$//")
        else
            # Extract full subdomains
            SUBS=$(echo "$RESPONSE" | jq -r '.data[].id')
        fi
        
        # Count and append to output file
        SUBS_COUNT=$(echo "$SUBS" | grep -c -v '^$')
        if [ $SUBS_COUNT -gt 0 ]; then
            echo "$SUBS" >> "$OUTPUT_FILE"
            log "Found $SUBS_COUNT subdomains on page $page"
        fi
        
        # Get next URL
        NEXT_URL=$(echo "$RESPONSE" | jq -r '.links.next')
        
        # Check if we have more pages
        if [ "$NEXT_URL" != "null" ] && [ -n "$NEXT_URL" ]; then
            log "Found next page for $domain"
            process_domain "$domain" "$NEXT_URL" "$((page + 1))"
        fi
        
        return 0
    else
        error "Invalid response for $domain, page $page"
        # Check if we hit rate limits
        if echo "$RESPONSE" | jq -e '.error.code == "QuotaExceededError"' > /dev/null 2>&1; then
            error "API key ${KEY_INDEX} has exceeded its quota."
            REQUESTS_PER_KEY["$API_KEY"]=$MAX_REQUESTS_PER_KEY
        else
            echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
        fi
        return 1
    fi
}

# Function to check if a domain is a subdomain of any target
is_subdomain() {
    local domain="$1"
    for target in "${DOMAINS[@]}"; do
        if [[ "$domain" == *".$target" ]]; then
            return 0
        fi
    done
    return 1
}

# Phase 1: Process all main domains
for DOMAIN in "${DOMAINS[@]}"; do
    section "Processing domain: $DOMAIN"
    process_domain "$DOMAIN"
    PROCESSED_DOMAINS["$DOMAIN"]=1
done

# Phase 2: If recursive mode is enabled, process discovered subdomains
if [ "$RECURSIVE" = true ]; then
    section "Starting recursive enumeration"
    
    # Read all discovered subdomains from the output file
    mapfile -t DISCOVERED_SUBDOMAINS < "$OUTPUT_FILE"
    
    # Remove duplicates and sort
    UNIQUE_SUBDOMAINS=($(printf "%s\n" "${DISCOVERED_SUBDOMAINS[@]}" | sort -u))
    
    log "Found ${#UNIQUE_SUBDOMAINS[@]} unique subdomains for recursive processing"
    
    # Process each unique subdomain that hasn't been processed yet
    for SUBDOMAIN in "${UNIQUE_SUBDOMAINS[@]}"; do
        # For subdomains-only mode, we need to reconstruct the full domain
        if [ "$SUBDOMAINS_ONLY" = true ]; then
            # Find which target domain this subdomain belongs to
            for TARGET in "${DOMAINS[@]}"; do
                if [[ "$SUBDOMAIN" == *".$TARGET" ]]; then
                    # This is already a full domain
                    FULL_DOMAIN="$SUBDOMAIN"
                    break
                else
                    # This is just the subdomain part, need to reconstruct
                    FULL_DOMAIN="$SUBDOMAIN.$TARGET"
                fi
            done
        else
            FULL_DOMAIN="$SUBDOMAIN"
        fi
        
        # Check if we should process this domain
        if [ -z "${PROCESSED_DOMAINS[$FULL_DOMAIN]}" ] && is_subdomain "$FULL_DOMAIN"; then
            section "Processing subdomain: $FULL_DOMAIN"
            process_domain "$FULL_DOMAIN"
            PROCESSED_DOMAINS["$FULL_DOMAIN"]=1
        fi
    done
fi

# Count total subdomains
TOTAL_SUBDOMAINS=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')

# Print summary
section "Enumeration Complete"
success "Total requests made: $TOTAL_REQUESTS"
success "Total subdomains found: $TOTAL_SUBDOMAINS"
echo -e "${CYAN}API key usage:${NC}"
for i in "${!API_KEYS[@]}"; do
    key="${API_KEYS[$i]}"
    echo -e "  Key $i: ${REQUESTS_PER_KEY["$key"]}/$MAX_REQUESTS_PER_KEY requests"
done
success "Results saved to: $OUTPUT_FILE"

echo -e "${MAGENTA}"
echo "================================================================================"
echo " Thank you for using VTSubEnumerator!"
echo " Created by Mihir Limbad (0xAshura)"
echo "================================================================================"
echo -e "${NC}"
