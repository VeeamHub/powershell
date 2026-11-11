#!/bin/bash

#==============================================================================
# Veeam VSA Automation Script - Configuration Password
# Auto-destruction after execution
#==============================================================================

# Configuration
VSA_USER="veeamso"
VSA_PASSWORD="$3"
TOTP_SECRET="$2"
CONFIG_PASSWORD="$1"
VSA_PORT="10443"

# Temporary files
COOKIE_JAR="/tmp/veeam_session_$$_$(date +%s)"
LOG_FILE="/var/log/veeam_addsoconfpw.log"
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
            echo -e "[INFO]${NC} ${message}"
            ;;
        WARN)
            echo -e "[WARN]${NC} ${message}"
            ;;
        ERROR)
            echo -e "[ERROR]${NC} ${message}"
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
    
    unset VSA_PASSWORD TOTP_SECRET TOTP_CODE CSRF_TOKEN CONFIG_PASSWORD
    
    log "INFO" "Script self-destruction in 2 seconds"
    sleep 2
    
    if command -v shred &> /dev/null; then
        shred -u -n 3 "$SCRIPT_PATH" 2>/dev/null
        log "INFO" "Script deleted with shred"
    else
        rm -f "$SCRIPT_PATH"
        log "WARN" "Script deleted without shred"
    fi
}

trap cleanup EXIT

#==============================================================================
# Preliminary checks
#==============================================================================
log "INFO" "Starting Veeam VSA automation"

if [ -z "$CONFIG_PASSWORD" ]; then
    log "ERROR" "Usage: $0 <config_password> <totp_secret> <vsa_password>"
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

log "INFO" "TOTP code generated"
TIMESTAMP=$(date +%s)

#==============================================================================
# Step 1: Authentication
#==============================================================================
log "INFO" "Step 1/4: Authentication"
RESPONSE=$(curl -k -s -i -c "$COOKIE_JAR" -b "$COOKIE_JAR" -X POST "${VSA_URL}/api/auth/login" \
    -H "Content-Type: application/json;charset=UTF-8" \
    -H "x-otp-token: ${TOTP_CODE}" \
    -H "otp-client-unixtime: ${TIMESTAMP}" \
    -H "Accept: */*" \
    -H "Connection: keep-alive" \
    -H "User-Agent: Mozilla/5.0 (Linux) AppleWebKit/537.36" \
    -d "{\"user\":\"${VSA_USER}\",\"password\":\"${VSA_PASSWORD}\"}" 2>&1)

CSRF_TOKEN=$(echo "$RESPONSE" | grep -i "X-CSRF-TOKEN:" | awk '{print $2}' | tr -d '\r')

if [ -z "$CSRF_TOKEN" ]; then
    log "ERROR" "Authentication failed"
    exit 1
fi

log "INFO" "Authentication successful"
sleep 1

#==============================================================================
# Step 2: Log in check
#==============================================================================
log "INFO" "Step 2/4: Configuration check"
STATUS=$(curl -k -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" -w "%{http_code}" -o /dev/null \
    -X GET "${VSA_URL}/api/v1/bco/imported?" \
    -H "Accept: application/json" \
    -H "x-csrf-token: ${CSRF_TOKEN}" \
    -H "User-Agent: Mozilla/5.0 (Linux) AppleWebKit/537.36")

if [ "$STATUS" != "200" ]; then
    log "WARN" "Check: HTTP ${STATUS}"
else
    log "INFO" "login verified"
fi

#==============================================================================
# Step 3: Add password
#==============================================================================
log "INFO" "Step 3/4: Add password"
RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    -X POST "${VSA_URL}/api/v1/bco/imported?" \
    -H "Content-Type: application/json;charset=UTF-8" \
    -H "Accept: application/json" \
    -H "x-csrf-token: ${CSRF_TOKEN}" \
    -H "Origin: ${VSA_URL}" \
    -H "Referer: ${VSA_URL}/configuration" \
    -H "Connection: keep-alive" \
    -H "User-Agent: Mozilla/5.0 (Linux) AppleWebKit/537.36" \
    -d "{\"hint\":\"\",\"passphrase\":\"${CONFIG_PASSWORD}\"}")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$HTTP_CODE" = "200" ]; then
    log "INFO" "Password added successfully"
else
    log "ERROR" "Failed to add password (HTTP ${HTTP_CODE})"
    exit 1
fi

#==============================================================================
# Step 4: Create current configuration password
#==============================================================================
log "INFO" "Step 4/5: Create current configuration password"
RESPONSE=$(curl -k -s -w "\nHTTP_CODE:%{http_code}" -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    -X POST "${VSA_URL}/api/v1/bco/current?" \
    -H "Content-Type: application/json;charset=UTF-8" \
    -H "Accept: application/json" \
    -H "x-csrf-token: ${CSRF_TOKEN}" \
    -H "Origin: ${VSA_URL}" \
    -H "Referer: ${VSA_URL}/configuration" \
    -H "Connection: keep-alive" \
    -H "User-Agent: Mozilla/5.0 (Linux) AppleWebKit/537.36" \
    -d "{\"hint\":\"\",\"passphrase\":\"${CONFIG_PASSWORD}\"}")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed 's/HTTP_CODE:.*//')

if [ "$HTTP_CODE" = "200" ]; then
    log "INFO" "Current configuration password created successfully"
else
    log "ERROR" "Failed to create current configuration password (HTTP ${HTTP_CODE})"
    exit 1
fi

#==============================================================================
# Step 5: Final verification
#==============================================================================
log "INFO" "Step 5/5: Final verification"
FINAL_STATUS=$(curl -k -s -b "$COOKIE_JAR" -w "%{http_code}" -o /dev/null \
    -X GET "${VSA_URL}/api/v1/bco/imported?" \
    -H "Accept: application/json" \
    -H "x-csrf-token: ${CSRF_TOKEN}" \
    -H "User-Agent: Mozilla/5.0 (Linux) AppleWebKit/537.36")

if [ "$FINAL_STATUS" = "200" ]; then
    log "INFO" "Final verification successful"
else
    log "WARN" "Final verification: HTTP ${FINAL_STATUS}"
fi

log "INFO" "Process completed successfully"
log "INFO" "Cleanup in progress"

exit 0


