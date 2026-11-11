<#
.SYNOPSIS
The following script is to be used as an example how you can get number of mailboxes for different exchange organisations.
.DESCRIPTION
The following script is to be used as an example how you can get number of mailboxes for different exchange organisations.

.PARAMETER csvfile
This provides the path and name to the CSV File

.EXAMPLE
vboreport.ps1 -csvfile "c:\scripts\vboreport.csv"

.NOTES  
    File Name  : vboreport.ps1  
    Author     : Marco Horstmann, Veeam Software GmbH (marco.horstmann@veeam.com)
    Requires   : PowerShell V4  
.LINK
     https://github.com/marcohorstmann/veeam-stuff/tree/master/VBOReport
#>


Param (
    [string]$csvfile = "C:\test\report.csv"
)

# Import PS Modul for Veeam Backup for Office 365
Import-Module Veeam.Archiver.PowerShell

# Create the array for the Organisations and no of mailbox
$orgmailboxlist = @()

# Get all organisations from VBO 
$vboorgs = Get-VBOOrganization


# For every organisation start this loop
foreach ($vboorg in $vboorgs) {
    # Get all Mailboxes from this org which has the flag IsBackedUp is true
    $vbomailboxes = Get-VBOOrganization -name $vboorg | Get-VBOOrganizationMailbox
    # Get all mailboxes which are flaged as backuped
    $vbomailboxesbackuped = $vbomailboxes | Where-Object {$_.IsBackedUp -eq $true}
    # Get all mailboxes which are flaged as NOT backuped
    $vbomailboxesnotbackuped = $vbomailboxes | Where-Object {$_.IsBackedUp -eq $false}
    # Add an object to the results array
    $orgmailboxlist += New-Object -TypeName PSObject -Property @{ "Name of Organisation"=$vboorg.Name;"No of Mailboxes Backuped"=$vbomailboxesbackuped.Count; }
}

# Export this list to an CSV file 
$orgmailboxlist | Select "Name of Organisation","No of Mailboxes Backuped" | ConvertTo-Csv | out-file $csvfile
