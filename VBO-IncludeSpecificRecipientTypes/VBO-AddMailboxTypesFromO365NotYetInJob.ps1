<# 
.NAME
	VBO-AddMailboxTypesFromO365NotYetInJob.ps1
.SYNOPSIS
	Modify the values below to connect to your O365 tenant and your VBO backup server and modify 	folder locations to your needs.
.DESCRIPTION
	Add specific mailbox types which are not in specific VBO job based on the Ex0 ExchangeOnlineManagement module.
	Credentials used to connect to your O365 tenant will be stored encrypted in a cred.xml file.
	Run this script at least once interactively to create this credentials .xml file and then schedule this script as a 
    scheduled task to automatically add newly added mailboxes based on the Recipient types selected to process.
	More information about the usage of this script can be found inline. 
#>

# Function to timestamp output in logfiles
# Do not change below unless you know what you are doing

    function Get-TimeStamp { 
    return "[{0:dd-MM-yyyy}] [{0:HH:mm:ss}]" -f (Get-Date)
}
 
# Do not change below unless you know what you are doing
Write-Host -ForegroundColor white ""
Write-Host -ForegroundColor white "Importing modules."
Write-Host -ForegroundColor white ""
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"
Import-Module -Name ExchangeOnlineManagement 

##############################################################################################################
# Modify the values below to your needs                                                                      #
##############################################################################################################

$Org = Get-VBOOrganization -Name "Your Tenant"
$Job = Get-VBOJob -Organization $Org -Name "Your Backup Job"

#Create the folder structure for your Workingset. Edit when changing the actual location.
If(!(Test-Path -Path "$env:ProgramData\Veeam\ScriptFiles\")){
    New-Item -Path "$env:ProgramData\Veeam\ScriptFiles\" -ItemType Directory -Force
    Write-Host -ForegroundColor green "Created the Workingset folder structure."
    Write-Host ""
}
Else {
    Write-Host -ForegroundColor white "Workingset Folder structure in place."
    Write-Host ""
}

#Create the folder structure for your Filter location. Edit when changing the actual location.
If(!(Test-Path -Path "$env:ProgramData\Veeam\ScriptFiles\Filter")){
    New-Item -Path "$env:ProgramData\Veeam\ScriptFiles\Filter" -ItemType Directory -Force
    Write-Host -ForegroundColor green "Created the Filter folder structure."
    Write-Host ""
}
Else {
    Write-Host -ForegroundColor white "Filter Folder structure in place."
    Write-Host ""
}

#Create the folder structure for your Cred location. Edit when changing the actual location.
If(!(Test-Path -Path "$env:ProgramData\Veeam\ScriptFiles\Cred")){
        New-Item -Path "$env:ProgramData\Veeam\ScriptFiles\Cred" -ItemType Directory -Force
    Write-Host -ForegroundColor green "Created the Filter folder structure."
    Write-Host ""
}
Else {
    Write-Host -ForegroundColor white "Cred Folder structure in place."
    Write-Host ""
}

#Create the folder structure for your Temp location. Edit when changing the actual location.
If(!(Test-Path -Path "$env:ProgramData\Veeam\ScriptFiles\Temp")){
    New-Item -Path "$env:ProgramData\Veeam\ScriptFiles\Temp" -ItemType Directory -Force
    Write-Host -ForegroundColor green "Created the Temp folder structure."
    Write-Host ""
}
Else {
    Write-Host -ForegroundColor white "Temp Folder structure in place."
    Write-Host ""
}

#Create the folder structure for your Logfiles location. Edit when changing the actual location.
If(!(Test-Path -Path "$env:ProgramData\Veeam\ScriptFiles\Logfiles")){
    New-Item -Path "$env:ProgramData\Veeam\ScriptFiles\Logfiles" -ItemType Directory -Force
    Write-Host -ForegroundColor green "Created the Logfiles folder structure."
    Write-Host ""
}
Else {
    Write-Host -ForegroundColor white "Logfiles Folder structure in place."
    Write-Host ""
}


# Log file locations
$LogFileAdded = "c:\ProgramData\Veeam\ScriptFiles\Logfiles\VBO-Mailboxes-added.log"
$LogFileSkipped = "c:\ProgramData\Veeam\ScriptFiles\Logfiles\VBO-Mailboxes-skipped.log"
$MailboxExportFile = "c:\ProgramData\Veeam\ScriptFiles\Temp\MailboxesToAddToVBO-Job.txt"

# Connect to your O365 tenant using the following service account and credential file.  
$O365Adm="youraccount@yourtenant"
$O365CredFile = "c:\ProgramData\Veeam\ScriptFiles\Cred\cred.xml"

# The Filter file can be used to put in UPNs of accounts that you want to filter out (not added to the backup job).
$FilterFile = "c:\ProgramData\Veeam\ScriptFiles\Filter\filter.txt"


##############################################################################################################
# Install the ExchangeOnlineManagement module by running the rule below once.                                #
#Install-Module -Name ExchangeOnlineManagement -RequiredVersion 1.0.1
##############################################################################################################

# Check if the credentials file exists.
If(!(Test-Path -path $O365CredFile)){
    Get-Credential -Message em"Enter your Office 365 Admin Credentials" | Export-Clixml -Path $o365CredFile
    $O365Cred=Get-Credential –Credential $O365Adm | EXPORT-CLIXML $O365credFile
}
Else{
    Write-Host -ForegroundColor green "O365 Credentials file found and will be used."
    Write-Host -ForegroundColor white ""
}

$O365Cred=IMPORT-CLIXML $O365CredFile

# Connect to Exchange Online and get the information of the mailboxes you want to add to your VBO script.
Write-Host -ForegroundColor white "Connecting to O365 Tenant using specified credentials."
Write-Host -ForegroundColor white ""
Connect-ExchangeOnline -UserPrincipalName $O365Adm -ShowProgress:$false -ShowBanner:$false


# Change the -RecipientTypeDetails to the specific types you want to include in your VBO job.
# Examples: -RecipientTypeDetails EquipmentMailbox, RoomMailbox, SharedMailbox


Write-Host -ForegroundColor white "Getting mailboxes based on the RecipientTypeDetails specified."
Write-Host -ForegroundColor white ""
$Mailboxes = Get-EXOMailbox -RecipientTypeDetails EquipmentMailbox, RoomMailbox, SharedMailbox -ResultSize unlimited 

# Create a filter file if does not exist.
If(!(Test-Path -path $FilterFile)){
    New-Item -Path $FilterFile
    Write-Host -ForegroundColor green "Created a empty filter file."
    Write-Host ""
}
Else {
    Write-Host -ForegroundColor green "Filter file exists and can be used."
    Write-Host ""
}

$Filters = Get-Content $FilterFile

# Create or clear the output file before the run.
If(!(Test-Path -path $MailboxExportFile)){
    New-Item -Path $MailboxExportFile
    Write-Host -ForegroundColor green "Created new Mailbox Export text file at the start of the job."
    Write-Host ""
}
Else {
    Clear-Content -Path $MailboxExportFile
    Write-Host -ForegroundColor green "Cleared existing Mailbox Export text file before running the job."
    Write-Host ""
}

# Export each Mailbox found with the Get-EXOMailbox and create those to the Output file. 
# This output file will then be used to check which mailboxes are not yet added to the backup job.

Write-Host -ForegroundColor white "Writing mailbox output to output file."
Write-Host -ForegroundColor white ""

ForEach($Mailbox in $Mailboxes) {
    Write $Mailbox.UserPrincipalName | Out-File -Filepath $MailboxExportFile -Append
}

$Mailboxinput = Get-Content $MailboxExportFile
Write-Host -ForegroundColor white "Getting existing mailboxes from the VBO Job."
Write-Host -ForegroundColor white ""
$ExistingMailboxes = Get-VBOBackupItem -Job $Job

Write-Host -ForegroundColor white "Checking for new mailboxes to add to the backup job."
Write-Host -ForegroundColor white ""

# For each mailbox found in the Output file there will be done two checks. 
# First if the mailbox may be added to the VBO Job (if not on the filter list)
# Second if the mailbox is already added to the VBO Job (then skipped).

# Do not change below unless you know what you are doing
ForEach($NewMailbox in $Mailboxinput) {
    If (-not ($Filters-ccontains $NewMailbox) -and (-not ($ExistingMailboxes.User.UserName -eq $NewMailbox))) {
        $User = Get-VBOOrganizationUser -Organization $Org -UserName $NewMailbox 
        $BackupItemUser = New-VBOBackupItem -User $User -Mailbox:$True -ArchiveMailbox:$False -OneDrive:$False -Sites:$False
        Add-VBOBackupItem -Job $Job -BackupItem $BackupItemUser -Verbose
        Write-Host -ForegroundColor Green "added" $NewMailbox "to" $Job
        Write-Output "$(Get-TimeStamp)" " Added " $NewMailbox " to " "$Job" | Out-File -FilePath $LogFileAdded -NoNewLine -Append
        Write-Output "`n" | Out-File -FilePath $LogFileAdded -Append
        $AddedMailboxes++
      }
  If(!$AddedMailboxes){
        $AddedMailboxes = 0
     }
ForEach ($Filter in $Filters) {
    If ($Filter-ccontains $NewMailbox) {
        Write-Host -ForegroundColor Gray $Filter "skipped based on filter"
        Write-Output "$(Get-TimeStamp)" " $Filter filtered out based on the filter specified" | Out-File -FilePath $LogFileSkipped -NoNewLine -Append
        Write-Output "`n" | Out-File -FilePath $LogFileSkipped -Append
        $FilteredMailboxes++
     }
    }
    If(!$FilteredMailboxes){
        $FilteredMailboxes = 0
    }
}

Write-Host -ForegroundColor white ""
Write-Host -ForegroundColor white "Mailboxes checked against filter and added new mailboxes to VBO Job."
Write-Host -ForegroundColor white ""

# Variable for the calculation of total mailboxes added.
$TotalMailboxes = $ExistingMailboxes.count

Write-Host -ForegroundColor white "Finalizing."
Write-Host -ForegroundColor white ""

# Output will be written to the log files for auditing purposes. 
Write-Host "------------------------------------------------------------------------"
Write-Host -ForegroundColor white "A total of" $AddedMailboxes "new mailboxes are added to Org - Job:" $Job "."
Write-Host -ForegroundColor white "And a total of" $FilteredMailboxes "mailboxes are filtered out based on the filter specified."
Write-Host "------------------------------------------------------------------------"
Write-Output "$(Get-TimeStamp)" " A total of " $FilteredMailboxes " mailboxes are filtered out based on the filter specified" | Out-File -FilePath $LogFileSkipped -NoNewLine -Append
Write-Output "`n" | Out-File -FilePath $LogFileSkipped -Append
Write-Output "-------------------------------------------------------------------------------------------------------------------------" | Out-File -FilePath $LogFileSkipped -Append

# Variables will be removed after the script run to clean up the system for the next run.
Write-Host -ForegroundColor white ""
Write-Host -ForegroundColor white "Cleaned up variables for the next run."
Remove-Variable -Name User,Mailbox,BackupItemUser,NewMailbox,Mailboxes,Filters,AddedMailboxes,FilteredMailboxes,TotalMailboxes -ErrorAction SilentlyContinue