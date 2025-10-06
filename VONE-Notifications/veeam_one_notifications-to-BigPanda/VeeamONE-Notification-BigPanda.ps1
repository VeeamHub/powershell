<#
.SYNOPSIS
Sends Veeam ONE alerts to BigPanda via their API.
.DESCRIPTION
This script takes parameters from Veeam ONE alerting and formats them for BigPanda's API.
It includes debug logging to a file for troubleshooting.
.PARAMETER AlarmName
The name of the alarm.

.PARAMETER NodeName
The name of the node.

.PARAMETER Summary
A brief summary of the alarm.

.PARAMETER AlarmTime
The time the alarm was triggered.

.PARAMETER AlarmStatus
The current status of the alarm.

.PARAMETER PreviousStatus
The previous status of the alarm.

.PARAMETER AlarmID
The unique identifier for the alarm.

.PARAMETER ChildObjectType
The type of the child object associated with the alarm.
.EXAMPLE
.\VeeamBigPandaAlerting.ps1 -AlarmName "Disk Space Low" -NodeName "Server01" -Summary "Disk space on C: drive is below threshold." -AlarmTime "10/1/2025 10:59:03 AM" -AlarmStatus "Error" -PreviousStatus "Warning" -AlarmID "12345" -ChildObjectType "Disk"
This example sends a "Disk Space Low" alert for "Server01" to BigPanda.
.NOTES
This script is best adapted by adding the "Run Script" action to the desired Alarm(s) in the Notification settings of Veeam ONE.
Ensure that the script has the necessary permissions to execute and access the network.

REQUIRED ENVIRONMENT VARIABLES:
- BIGPANDA_APP_KEY: Your BigPanda application key
- BIGPANDA_AUTH_TOKEN: Your BigPanda authentication token

Suggested values:
Action = Run Script
Value = powershell.exe VeeamBigPandaAlerting.ps1 '%1' '%2' '%3' '%4' '%5' '%6' '%7' '%8'
Condition = Any State

Author: Adam Congdon
Date: 2024-10-01

# Adjust the following variables with your BigPanda API credentials and endpoint
$webhookUrl = "https://api.bigpanda.io/data/v2/alerts"


With a special thanks to GitHub Copilot for assistance in debug logging implementation.

#>



param (
    [string]$AlarmName,
    [string]$NodeName,
    [string]$Summary,
    [string]$AlarmTime,
    [string]$AlarmStatus,
    [string]$PreviousStatus,
    [string]$AlarmID,
    [string]$ChildObjectType

)

#OIM
$appKey = $env:BIGPANDA_APP_KEY
$authToken = $env:BIGPANDA_AUTH_TOKEN

if (-not $appKey -or -not $authToken) {
    Write-DebugLog "ERROR: BigPanda credentials not found in environment variables"
    Write-Error "Please set BIGPANDA_APP_KEY and BIGPANDA_AUTH_TOKEN environment variables"
    exit 1
}
Write-DebugLog "API credentials configured (OIM environment)"


# Debug logging setup

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$logFile = "C:\temp\PandaDebug_$timestamp.log"

# Ensure the temp directory exists

if (!(Test-Path "C:\temp")) {
    New-Item -ItemType Directory -Path "C:\temp" -Force
}

# Function to write debug log

function Write-DebugLog {
    param([string]$Message)
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Output $logEntry
}

Write-DebugLog "Script started with parameters:"
Write-DebugLog "  AlarmName: $AlarmName"
Write-DebugLog "  NodeName: $NodeName"
Write-DebugLog "  Summary: $Summary"
Write-DebugLog "  AlarmTime: $AlarmTime"
Write-DebugLog "  AlarmStatus: $AlarmStatus"
Write-DebugLog "  PreviousStatus: $PreviousStatus"
Write-DebugLog "  AlarmID: $AlarmID"
Write-DebugLog "  ChildObjectType: $ChildObjectType"
Write-DebugLog "Original AlarmStatus: $AlarmStatus"


# Map alarm statuses to BigPanda status values
if ($AlarmStatus -eq "Error") {
    $AlarmStatus = "critical"
}

elseif ($AlarmStatus -eq "Acknowledged") {
    $AlarmStatus = "warning-suspect"
}

elseif ($AlarmStatus -eq "Reset/resolved") {
    $AlarmStatus = "ok"
}

elseif ($AlarmStatus -eq "Warning") {
    $AlarmStatus = "warning"
}

Write-DebugLog "Mapped AlarmStatus: $AlarmStatus"
$webhookUrl = "https://api.bigpanda.io/data/v2/alerts"
Write-DebugLog "Webhook URL configured: $webhookUrl"

# Parse AlarmTime with explicit format, fallback to now if fails

Write-DebugLog "Parsing alarm time: $AlarmTime"
$timestamp = 0

try {
    # Try multiple format patterns to handle different date formats
    $formats = @(
        "M/d/yyyy h:mm:ss tt",     # 10/1/2025 10:59:03 AM
        "MM/dd/yyyy hh:mm:ss tt",  # 10/01/2025 10:59:03 AM
        "M/d/yyyy hh:mm.ss tt",    # 10/1/2025 10:59.03 AM
        "MM/dd/yyyy hh:mm.ss tt"   # 10/01/2025 10:59.03 AM
    )
    $parsed = $false

    foreach ($format in $formats) {
        try {
            $dateTime = [datetime]::ParseExact($AlarmTime, $format, $null)
            $dateTimeLocal = [DateTime]::SpecifyKind($dateTime, [DateTimeKind]::Local)
            $timestamp = [int]([datetimeoffset]$dateTimeLocal).ToUnixTimeSeconds()
            Write-DebugLog "Successfully parsed alarm time using format '$format'. Unix timestamp: $timestamp (treated as UTC)"
            $parsed = $true
            break
        }

        catch {
            # Continue to next format
        }

    }

    if (-not $parsed) {
        throw "No format matched"

    }
}

catch {
    $timestamp = [int](Get-Date -UFormat %s)
    Write-DebugLog "Failed to parse alarm time with all formats, using current time. Unix timestamp: $timestamp. Error: $($_.Exception.Message)"

}

Write-DebugLog "Building request body..."

$body = @{
    app_key          = $appKey
    status           = $AlarmStatus
    host             = $NodeName
    check            = $AlarmName
    description      = $Summary
    timestamp        = $timestamp
    primary_property = "host"
    PreviousStatus   = $PreviousStatus
    AlarmID          = $AlarmID
    ChildObjectType  = $ChildObjectType

    #    custom      = @{

    #        PreviousStatus   = $PreviousStatus

    #        AlarmID         = $AlarmID

    #        ChildObjectType = $ChildObjectType

    #    }

} | ConvertTo-Json

Write-DebugLog "Request body created:"

Write-DebugLog $body

$headers = @{

    Authorization  = "Bearer $authToken"

    "Content-Type" = "application/json"

}

Write-DebugLog "Headers configured for API request"

Write-DebugLog "Sending request to BigPanda API..."

try {

    # $response = Invoke-RestMethod -Uri $webhookUrl -Method Post -Headers $headers -Body $body

    $response = Invoke-WebRequest -Uri $webhookUrl -Method Post -Headers $headers -Body $body

    Write-DebugLog "Alert sent successfully. Status Code: $($response.StatusCode)"

    Write-DebugLog "Response Content: $($response.Content)"

    Write-Output "Alert sent successfully: $($response)"

}

catch {

    Write-DebugLog "Failed to send alert to BigPanda. Error: $($_.Exception.Message)"

    Write-DebugLog "Full Error Details: $($_ | Out-String)"

    Write-Error "Failed to send alert to BigPanda: $_"

}

Write-DebugLog "Script execution completed"
Write-DebugLog "Log file location: $logFile"