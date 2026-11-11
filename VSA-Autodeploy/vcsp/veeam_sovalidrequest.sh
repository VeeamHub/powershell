#!/bin/bash

#==============================================================================
# VCSP Automation Script - SecOF Request Auto-Validation
# Auto-destruction after execution
#==============================================================================

# Configuration
VSA_USER="$2"
VSA_PASSWORD="$3"
TOTP_SECRET="$1"
VSA_PORT="10443"

# Temporary files
COOKIE_JAR="/tmp/vcsp_session_$$_$(date +%s)"
LOG_FILE="/var/log/vcsp_so_valid_request.log"
SCRIPT_PATH="$0"

#==============================================================================
# Secure logging function
#==============================================================================
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    
    case "$level" in
        INFO)
            echo -e "[INFO] ${message}"
            ;;
        WARN)
            echo -e "[WARN] ${message}"
            ;;
        ERROR)
            echo -e "[ERROR] ${message}"
            ;;
        *)
            echo "[${level}] ${message}"
            ;;
    esac
}

#==============================================================================
# Secure cleanup function
#==============================================================================
cleanup() {
    log "INFO" "Cleaning up temporary files"
    
    if [ -f "$COOKIE_JAR" ]; then
        shred -u -n 3 "$COOKIE_JAR" 2>/dev/null || rm -f "$COOKIE_JAR"
        log "INFO" "Cookie jar deleted"
    fi
    
    unset VSA_PASSWORD TOTP_SECRET TOTP_CODE CSRF_TOKEN
}

trap cleanup EXIT

#==============================================================================
# Preliminary checks
#==============================================================================
log "INFO" "Starting VCSP SecOF request auto-validation"

if [ -z "$TOTP_SECRET" ] || [ -z "$VSA_USER" ] || [ -z "$VSA_PASSWORD" ]; then
    log "ERROR" "Usage: $0 <totp_secret> <username> <password>"
    exit 1
fi

if ! command -v oathtool &> /dev/null; then
    log "ERROR" "oathtool not found - Installation: dnf install oathtool"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    log "ERROR" "curl not found"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    log "WARN" "jq not found - will use grep fallback for JSON parsing"
fi

#==============================================================================
# Retrieve local IP address
#==============================================================================
log "INFO" "Retrieving local IP address"

VSA_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

if [ -z "$VSA_IP" ] || [ "$VSA_IP" = "127.0.0.1" ]; then
    VSA_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[^ ]+')
fi

if [ -z "$VSA_IP" ] || [ "$VSA_IP" = "127.0.0.1" ]; then
    VSA_IP=$(ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -n1)
fi

if [ -z "$VSA_IP" ] || [ "$VSA_IP" = "127.0.0.1" ]; then
    log "ERROR" "Unable to retrieve local IP address"
    exit 1
fi

VSA_URL="https://${VSA_IP}:${VSA_PORT}"
log "INFO" "VSA URL: ${VSA_URL}"

#==============================================================================
# Generate TOTP code
#==============================================================================
log "INFO" "Generating TOTP code"
TOTP_CODE=$(oathtool --totp -b "$TOTP_SECRET" 2>/dev/null)

if [ -z "$TOTP_CODE" ]; then
    log "ERROR" "TOTP generation failed"
    exit 1
fi

log "INFO" "TOTP code generated: ${TOTP_CODE}"
TIMESTAMP=$(date +%s)

#==============================================================================
# Step 1: Initial authentication attempt (expecting HTTP 428 - MFA required)
#==============================================================================
log "INFO" "Step 1/4: Initial authentication"

RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
    -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
    -X POST "${VSA_URL}/api/auth/login" \
    -H "Content-Type: application/json;charset=UTF-8" \
    -H "Accept: */*" \
    -H "Connection: keep-alive" \
    -H "User-Agent: Mozilla/5.0 (Linux) AppleWebKit/537.36" \
    -d "{\"user\":\"${VSA_USER}\",\"password\":\"${VSA_PASSWORD}\"}")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$HTTP_CODE" = "428" ]; then
    log "INFO" "MFA required (HTTP 428) - proceeding with OTP"
elif [ "$HTTP_CODE" = "200" ]; then
    log "INFO" "Authentication successful without MFA"
else
    log "ERROR" "Unexpected response during authentication (HTTP ${HTTP_CODE})"
    exit 1
fi

sleep 1

#==============================================================================
# Step 2: Authentication with MFA
#==============================================================================
log "INFO" "Step 2/4: Authentication with MFA code"

RESPONSE=$(curl -k -s -i \
    -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
    -X POST "${VSA_URL}/api/auth/login" \
    -H "Content-Type: application/json;charset=UTF-8" \
    -H "X-OTP-TOKEN: ${TOTP_CODE}" \
    -H "Accept: */*" \
    -H "Connection: keep-alive" \
    -H "User-Agent: Mozilla/5.0 (Linux) AppleWebKit/537.36" \
    -d "{\"user\":\"${VSA_USER}\",\"password\":\"${VSA_PASSWORD}\"}" 2>&1)

# Extract CSRF token from response headers
CSRF_TOKEN=$(echo "$RESPONSE" | grep -i "X-CSRF-TOKEN:" | awk '{print $2}' | tr -d '\r')

if [ -z "$CSRF_TOKEN" ]; then
    log "ERROR" "Authentication with MFA failed - no CSRF token received"
    exit 1
fi

log "INFO" "Authentication successful - CSRF token: ${CSRF_TOKEN}"
sleep 1

#==============================================================================
# Step 3: Get pending SecOF requests
#==============================================================================
log "INFO" "Step 3/4: Retrieving pending SecOF requests"

RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
    -b "$COOKIE_JAR" \
    -X GET "${VSA_URL}/api/v1/secof/requests" \
    -H "Accept: application/json" \
    -H "X-CSRF-TOKEN: ${CSRF_TOKEN}" \
    -H "Referer: ${VSA_URL}/overview" \
    -H "Connection: keep-alive" \
    -H "User-Agent: Mozilla/5.0 (Linux) AppleWebKit/537.36")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed 's/HTTP_CODE:.*//')

if [ "$HTTP_CODE" != "200" ]; then
    log "ERROR" "Failed to retrieve SecOF requests (HTTP ${HTTP_CODE})"
    exit 1
fi

log "INFO" "SecOF requests retrieved successfully"

# Parse JSON to extract request IDs
if command -v jq &> /dev/null; then
    # Use jq if available (preferred method)
    REQUEST_IDS=($(echo "$BODY" | jq -r '.[].id' 2>/dev/null))
    REQUEST_TYPES=($(echo "$BODY" | jq -r '.[].type' 2>/dev/null))
    REQUEST_DESCRIPTIONS=($(echo "$BODY" | jq -r '.[].description' 2>/dev/null))
else
    # Fallback to grep if jq is not available
    REQUEST_IDS=($(echo "$BODY" | grep -oP '"id":"\K[^"]+'))
    REQUEST_TYPES=($(echo "$BODY" | grep -oP '"type":"\K[^"]+'))
fi

if [ ${#REQUEST_IDS[@]} -eq 0 ]; then
    log "WARN" "No pending SecOF requests found"
    log "INFO" "Nothing to validate - exiting"
    exit 0
fi

log "INFO" "Found ${#REQUEST_IDS[@]} pending request(s)"

#==============================================================================
# Step 4: Validate each pending SecOF request
#==============================================================================
log "INFO" "Step 4/4: Validating SecOF requests"

SUCCESS_COUNT=0
FAIL_COUNT=0

for i in "${!REQUEST_IDS[@]}"; do
    REQUEST_ID="${REQUEST_IDS[$i]}"
    REQUEST_TYPE="${REQUEST_TYPES[$i]:-Unknown}"
    
    log "INFO" "Validating request [$((i+1))/${#REQUEST_IDS[@]}]: ${REQUEST_ID} (Type: ${REQUEST_TYPE})"
    
    RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" \
        -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
        -X POST "${VSA_URL}/api/v1/secof/requests/${REQUEST_ID}?" \
        -H "Content-Type: application/json;charset=UTF-8" \
        -H "Accept: application/json" \
        -H "X-CSRF-TOKEN: ${CSRF_TOKEN}" \
        -H "Origin: ${VSA_URL}" \
        -H "Referer: ${VSA_URL}/" \
        -H "Connection: keep-alive" \
        -H "User-Agent: Mozilla/5.0 (Linux) AppleWebKit/537.36" \
        -d '{}')
    
    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | sed 's/HTTP_CODE:.*//')
    
    if [ "$HTTP_CODE" = "204" ]; then
        log "INFO" "Request ${REQUEST_ID} validated successfully (HTTP 204)"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    elif [ "$HTTP_CODE" = "200" ]; then
        log "INFO" "Request ${REQUEST_ID} validated successfully (HTTP 200)"
        log "INFO" "Response: ${BODY}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        log "ERROR" "Failed to validate request ${REQUEST_ID} (HTTP ${HTTP_CODE})"
        log "ERROR" "Response: ${BODY}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Small delay between requests
    sleep 1
done

#==============================================================================
# Summary
#==============================================================================
log "INFO" "================================================"
log "INFO" "Validation Summary:"
log "INFO" "  Total requests: ${#REQUEST_IDS[@]}"
log "INFO" "  Successful: ${SUCCESS_COUNT}"
log "INFO" "  Failed: ${FAIL_COUNT}"
log "INFO" "================================================"

if [ $FAIL_COUNT -gt 0 ]; then
    log "WARN" "Some requests failed validation"
    exit 1
fi

log "INFO" "All requests validated successfully"
#log "INFO" "Cleanup in progress"

exit 0

