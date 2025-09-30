<# 
   .SYNOPSIS
   Reading all session statuses for all protected Azure VMs.

   .DESCRIPTION

   This script uses the Veeam Backup for Azure RestAPI v8 to read all session within the last 30 days. 
   In a second step the status for every Azure VM backup task is collected from each of the sessions.
   The collected date is exported into a HTML and a CSV file.
    
   .NOTES 
   Version:        1.4
   Author:         David Bewernick / @d-works42
   Creation Date:  2025-05-14

   .CHANGELOG
   1.0   2025-05-14   Script created
   1.4   2025-05-14   Extension for HTML coloring and CSV export

 #> 

# Generate timestamp
$Timestamp = Get-Date -Format "yyyyMMdd_HHmm"

# Create a list to hold the CSV data
$ReportData = @()

# Configuration (use your settings!)
$VBA_URL = "https://<VBAZ IP>"
$Username = "<username>"
$Password = "<password>"

# Define CSV output path
$CsvPath = "VM_Protection_Report_$Timestamp.csv"
$HtmlPath = "VM_Protection_Report_$Timestamp.html"

# Ignore SSL errors
Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# Authenticate
$TokenResponse = Invoke-RestMethod -Method Post -Uri "$VBA_URL/api/oauth2/token" `
    -Headers @{ "accept" = "application/json"; "Content-Type" = "application/x-www-form-urlencoded" } `
    -Body @{ Username = $Username; Password = $Password }

$AccessToken = $TokenResponse.access_token
$Headers = @{ "Authorization" = "Bearer $AccessToken"; "accept" = "application/json" }

# Define time range
$StartDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ")
$EndDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")

# Get job sessions
$SessionsUri = "$VBA_URL/api/v8/jobSessions?FromUTc=$StartDate&ToUTC=$EndDate&Types=PolicyBackup"
$Sessions = Invoke-RestMethod -Method Get -Uri $SessionsUri -Headers $Headers

# Function to convert bytes to human-readable format
function Convert-Bytes {
    param ([long]$bytes)
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    elseif ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    elseif ($bytes -ge 1KB) { return "{0:N2} KB" -f ($bytes / 1KB) }
    else { return "$bytes B" }
}


# Start HTML report
$Html = @"
<html><head><style>
body { font-family: Arial, sans-serif; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #ddd; padding: 8px; }
th { background-color: #f2f2f2; }
tr.success { background-color: #d4edda; }
tr.warning { background-color: #ffcc00; }
tr.error { background-color: #f76a6a; }
</style></head><body>
<h2>Per-VM Protection Status by Session (Last 30 Days)</h2>
<table><tr><th>Session Time</th><th>Policy</th><th>VM Name</th><th>Status</th><th>Transferred</th></tr>
"@


# Loop through sessions
foreach ($session in $Sessions.results) {
    $SessionId = $session.id
    $SessionTimeRaw = $session.executionStartTime
    $SessionTime = (Get-Date $SessionTimeRaw).ToString("yyyy-MM-dd HH:mm")
    $SessionType = $session.type
    $PolicyName = $session.BackupJobInfo.policyName

    $ProtectedItemsUri = "$VBA_URL/api/v8/jobSessions/$SessionId/protectedItems"
    $ProtectedItems = Invoke-RestMethod -Method Get -Uri $ProtectedItemsUri -Headers $Headers
    
    foreach ($vm in $ProtectedItems.results) {
        $latestRun = $vm.runs | Sort-Object startTime -Descending | Select-Object -First 1
        $status = $latestRun.status
        $bytes = $latestRun.rates.transferredDataBytes
        $readableBytes = Convert-Bytes $bytes

        $rowClass = switch ($status) {
            "Success" { "success" }
            "Warning" { "warning" }
            "Error" { "error" }
            default   { "" }
        }

        $Html += "<tr class='$rowClass'><td>$SessionTime</td><td>$PolicyName</td><td>$($vm.resource.displayName)</td><td>$status</td><td>$readableBytes</td></tr>"
        
        $ReportData += [PSCustomObject]@{
            "VM Name"      = $vm.resource.displayName
            "Session Time" = $SessionTime
            "Status"       = $latestRun.status
            "Policy"       = $PolicyName
            "Transferred"  = $readableBytes
            "Resource Group" = $vm.resource.ResourceGroupName
        }
    }
}


$Html += "</table></body></html>"
$Html | Out-File -FilePath $HtmlPath -Encoding UTF8
Write-Host "Report generated: VM_Protection_Report_$Timestamp.html.html"

$ReportData = $ReportData | Sort-Object "VM Name"
$ReportData | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
Write-Host "CSV report generated: $CsvPath"