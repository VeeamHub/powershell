<#
.SYNOPSIS
    Exports Veeam Backup & Replication audit logs within a specified date range and emails the formatted report.

.DESCRIPTION
    This PowerShell script automates the process of connecting to a Veeam Backup & Replication (VBR) server, exporting audit logs 
    for a defined date range, dynamically naming the exported CSV file based on the current date and time, formatting the exported 
    data into a structured HTML table embedded within the email body, and attaching the CSV report to the email. 
    The script leverages Veeam's PowerShell module for audit data retrieval and Microsoft Graph API for sending emails 
    with the generated CSV report both embedded in the email body and as an attachment.

.PARAMETER VBRServer
    The IP address or hostname of the Veeam Backup & Replication server to connect to.

.PARAMETER VBRUser
    The username used to authenticate with the Veeam Backup & Replication server.

.PARAMETER VBRPassword
    The password corresponding to the VBRUser for authentication.

.PARAMETER FromDate
    The start date and time for the audit log export. Specify in a format recognized by Get-Date.

.PARAMETER ToDate
    The end date and time for the audit log export. Specify in a format recognized by Get-Date.

.PARAMETER AuditReportPath
    The full file path where the exported audit CSV will be saved. The filename includes the current date and time for uniqueness.

.PARAMETER TenantId
    The Azure AD tenant ID associated with the Microsoft Graph API application registration.

.PARAMETER ClientId
    The client ID (application ID) of the Azure AD application registered for Microsoft Graph API access.

.PARAMETER ClientSecret
    The client secret for the Azure AD application. Ensure this is stored securely and not exposed in plain text.

.PARAMETER SenderEmail
    The email address from which the report will be sent. This should be associated with the Azure AD application.

.PARAMETER RecipientEmail
    The email address to which the report will be sent.

.PARAMETER EmailSubject
    The subject line of the email containing the audit report.

.PARAMETER EmailBodyText
    The plain text content of the email. This text is combined with the embedded HTML table for rich formatting.

.EXAMPLE
    .\VBR_AuditExport_EmailReport.ps1
    Connects to the VBR server at the specified IP using specified credentials, exports audit logs from one date, to another date, 
    dynamically names the CSV report based on the current date and time, embeds the audit data as an HTML table in the email body, 
    attaches the CSV report, and emails the report to the specified sender email.

.NOTES
    SCRIPT NAME: VBR_AuditExport_EmailReport.ps1
    VERSION: 1.2
    AUTHOR: Jorge de la Cruz
    CONTACT: jorge.delacruz@jorgedelacruz.es
    GITHUB: https://github.com/jorgedlcruz
    TWITTER: @jorgedlcruz

.LINK
    Comprehensive documentation and updates available at:
    https://jorgedelacruz.uk/
#>

# ---------------------------
# Parameters Configuration
# ---------------------------

# VBR Server Connection Details
$VBRServer = "VBRIP"
$VBRUser = "DOMAINORWROKGROUP\Administrator"
$VBRPassword = "YOURPASS"

# Audit Export Details
$FromDate = Get-Date -Year 2023 -Month 2 -Day 2 -Hour 0 -Minute 0 -Second 0
$ToDate = Get-Date -Year 2024 -Month 10 -Day 4 -Hour 0 -Minute 0 -Second 0
$CurrentDateTime = Get-Date -Format "yyyyMMdd-HHmmss"
$AuditReportPath = "C:\${CurrentDateTime}-AuditReport.csv"

# Email Configuration
$TenantId = "YOURTENANT.onmicrosoft.com"
$ClientId = "YOURCLIENTID"
$ClientSecret = "YOURSECRETFORAPP" 
$SenderEmail = "your@email.com"
$RecipientEmail = "towhom@mail.com"
$EmailSubject = "[Report] Veeam Backup & Replication Infrastructure Audit"
$EmailBodyText = @"
Dear Customer,

Find attached the Veeam ONE Audit Report.

Best Regards,
Your Veeam Sentinel
"@

# ---------------------------
# Connect to Veeam Backup & Replication
# ---------------------------

try {
    Disconnect-VBRServer -ErrorAction SilentlyContinue
    Connect-VBRServer -Server $VBRServer -User $VBRUser -Password $VBRPassword
    Write-Output "Connected to Veeam Backup & Replication server successfully."
} catch {
    Write-Error "Failed to connect to Veeam Backup & Replication server. $_"
    exit 1
}

# ---------------------------
# Export Audit Data
# ---------------------------

try {
    Export-VBRAudit -From $FromDate -To $ToDate -FileFullPath $AuditReportPath
    Write-Output "Audit data exported successfully to $AuditReportPath."
} catch {
    Write-Error "Failed to export audit data. $_"
    exit 1
}

# ---------------------------
# Process the CSV File
# ---------------------------

try {
    # Import the CSV data
    $AuditData = Import-Csv -Path $AuditReportPath -Delimiter ','
    
    # Convert CSV data to HTML table
    $HtmlTable = $AuditData | ConvertTo-Html -Property Time, User, SID, Operation, Result, Details -Title "Veeam ONE Infrastructure Audit Report" | Out-String

    Write-Output "Audit data processed successfully."
} catch {
    Write-Error "Failed to process audit data. $_"
    exit 1
}

# ---------------------------
# Send Email with Report
# ---------------------------

# Import MSAL.PS module
if (-not (Get-Module -ListAvailable -Name MSAL.PS)) {
    Install-Module -Name MSAL.PS -Scope CurrentUser -Force
}
Import-Module MSAL.PS

# Acquire an access token to interact with the app
$appRegistration = @{
    TenantId     = $TenantId
    ClientId     = $ClientId
    ClientSecret = (ConvertTo-SecureString $ClientSecret -AsPlainText -Force)
}

try {
    $msalToken = Get-msaltoken @appRegistration -ForceRefresh
    Write-Output "Access token acquired successfully."
} catch {
    Write-Error "Failed to acquire access token. $_"
    exit 1
}

# Prepare the attachment (CSV report)
try {
    $AttachmentContent = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($AuditReportPath))
    $Attachment = @{
        "@odata.type"  = "#microsoft.graph.fileAttachment"
        "name"         = "$(Split-Path -Path $AuditReportPath -Leaf)"
        "contentType"  = "text/csv"
        "contentBytes" = $AttachmentContent
    }
} catch {
    Write-Error "Failed to prepare attachment. $_"
    exit 1
}

# Prepare the email body with HTML table
$emailBodyHtml = @"
<html>
<head>
    <style>
        table {
            border-collapse: collapse;
            width: 100%;
        }
        th, td {
            border: 1px solid #dddddd;
            text-align: left;
            padding: 8px;
        }
        th {
            background-color: #f2f2f2;
        }
    </style>
</head>
<body>
    <p>$EmailBodyText</p>
    $HtmlTable
</body>
</html>
"@

# Prepare the request body
$requestBody = @{
    "message" = @{
        "subject" = $EmailSubject
        "body" = @{
            "contentType" = "HTML"
            "content"     = $emailBodyHtml
        }
        "toRecipients" = @(
            @{
                "emailAddress" = @{
                    "address" = $RecipientEmail
                }
            }
        )
        "attachments" = @($Attachment)
    }
    "saveToSentItems" = "true"
}

# Make the Graph API request to send the email
try {
    $request = @{
        "Headers"     = @{ Authorization = $msalToken.CreateAuthorizationHeader() }
        "Method"      = "Post"
        "Uri"         = "https://graph.microsoft.com/v1.0/users/$SenderEmail/sendMail"
        "Body"        = $requestBody | ConvertTo-Json -Depth 10
        "ContentType" = "application/json"
    }

    Invoke-RestMethod @request
    Write-Output "Email has been sent successfully to $RecipientEmail."
} catch {
    Write-Error "Failed to send email. $_"
    exit 1
}

# ---------------------------
# Cleanup (Optional)
# ---------------------------

# Remove the audit report file if not needed
try {
    Remove-Item $AuditReportPath -Force
    Write-Output "Temporary report file has been removed."
} catch {
    Write-Warning "Failed to remove temporary file. $_"
}

# Disconnect from VBR server
try {
    Disconnect-VBRServer
    Write-Output "Disconnected from Veeam Backup & Replication server."
} catch {
    Write-Warning "Failed to disconnect from Veeam Backup & Replication server. $_"
}