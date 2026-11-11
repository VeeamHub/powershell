<# 
.NAME
    Veeam Backup for Microsoft Office 365 Report Generation
.SYNOPSIS
    Script to use for automation of Veeam Backup for Microsoft Office 365 reporting feature 
.DESCRIPTION
    Script to use for automation of Veeam Backup for Microsoft Office 365 reporting feature 
    Released under the MIT license.
.LINK
    http://www.github.com/nielsengelen
#>

# Modify the values below to your needs
# Mail configuration
$from = "vbo365@company.com"
$to = "mailbox@company.com"
$smtpserver = "mail.company.com"
$subject = "Veeam Backup for Microsoft Office 365 reports"
$port = "587" # default: 25
$usessl = true # Use SSL (true) or not (false)

# Used for authentication against the mail server
$username = "authentication@company.com"
$password = ConvertTo-SecureString "AUTHPASSWORD" -AsPlainText -Force

# Report configuration
$path = "c:\VBO365reports" # Folder to store reports
$daysago = "30" # Amount of days to go back
$format = "PDF" # Can be CSV or PDF

# Do not change below unless you know what you are doing
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

$endtime = Get-Date
$starttime = (Get-Date).AddDays(-30)
$pathtime = Get-Date -UFormat "%Y-%m-%d-%H%M%S" # 2019-06-18-125011 - YEAR-MONTH-DATE-HOURMINUTESSECONDS
$fullpath = "$path\$pathtime"

if (!(Test-Path $fullpath -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $fullpath | Out-Null
}

# License Overview Report
Get-VBOLicenseOverviewReport -StartTime $starttime -EndTime $endtime -Path $fullpath -Format $format

# Mailbox Protection Report
Get-VBOMailboxProtectionReport -Path $fullpath -Format $format

# Storage Consumption Report
Get-VBOStorageConsumptionReport -StartTime $starttime -EndTime $endtime -Path $fullpath -Format $format

$licensereport = Get-Item "$fullpath\Veeam_LicenseOverviewReport*"
$mailboxreport = Get-Item "$fullpath\Veeam_MailboxProtectionReport*"
$storagereport = Get-Item "$fullpath\Veeam_StorageConsumptionReport*"
$cred = New-Object System.Management.Automation.PSCredential ($username, $password)

if ($usessl) {
    Send-MailMessage -From $from -To $to -Subject $subject -Body 'Veeam Backup for Microsoft Office 365 report' -Attachments $licensereport,$mailboxreport,$storagereport -SmtpServer $smtpserver -Port $port -Credential $cred -UseSsl -DeliveryNotificationOption OnFailure,OnSuccess
} else {
    Send-MailMessage -From $from -To $to -Subject $subject -Body 'Veeam Backup for Microsoft Office 365 report' -Attachments $licensereport,$mailboxreport,$storagereport -SmtpServer $smtpserver -Port $port -Credential $cred -DeliveryNotificationOption OnFailure,OnSuccess
}