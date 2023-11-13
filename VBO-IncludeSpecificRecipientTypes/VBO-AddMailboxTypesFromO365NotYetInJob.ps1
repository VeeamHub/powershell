<# 
.NAME
	VBO-AddMailboxTypesFrom0365NotYetInJob.ps1
.SYNOPSIS
	Modify the values below to connect to your M365 tenant and your VB365 backup server and modify folder locations to your needs.
.DESCRIPTION
	Add specific mailbox types which are not in specific VB365 job based on the ExO ExchangeOnlineManagement module.
	Credentials used to connect to your M365 tenant will be stored encrypted in a <user>.txt file.
    Make sure that you use an MFA-Enabled service account with a preconfigured App password to login to M365. 
    See the following link to create an App password for an MFA-Enabled service account: http://vee.am/App-Password.
	Run this script at least once interactively to create this credentials .xml file and then schedule this script as a 
    scheduled task to automatically add newly added mailboxes based on the Recipient types selected to process.
	More information about the usage of this script can be found inline. 
#>

## 1. Run the script like this '.\SharedMailboxes.ps1 admin@M365x000000000.onmicrosoft.com' and the RecipientTypeDetails configured below are used
## 2. Run the script like this '.\SharedMailboxes.ps1 admin@M365x000000000.onmicrosoft.com "EquipmentMailbox, RoomMailbox, SharedMailbox"' and the RecipientTypeDetails from the command line will be used

## VB365 Server to connect to and BU Job we want to add the Mailboxes to (recommended is to run the script local on the VB365 Server)
$vb365server = "vb365.veeam.lab"
$jobname = "Shared Mailboxes"

## The Mailboxes we will search for by default if no argument was given (more info: https://learn.microsoft.com/en-us/powershell/module/exchange/get-exomailbox?view=exchange-ps#-recipienttypedetails)
$RecipientTypeDetails = "EquipmentMailbox, RoomMailbox, SharedMailbox"

## Path to (create and) store the encrypted user credentials and other files
$credsdir = "C:\ProgramData\Veeam\ScriptFiles\SecureCredentials"
$workingdir = "C:\ProgramData\Veeam\ScriptFiles"



#### DO NOT EDIT BELOW ###

$org = $args[0].split('@')[1].split(' ')
$vb365org = Get-VBOOrganization -Name "$org"
$job = Get-VBOJob -Organization $vb365org -Name $jobname

# Function to timestamp output in logfiles
# Do not change below unless you know what you are doing

    function Get-TimeStamp { 
    return "[{0:dd-MM-yyyy}] [{0:HH:mm:ss}]" -f (Get-Date)
}
 
# Do not change below unless you know what you are doing
#Install-Module -Name ExchangeOnlineManagement -RequiredVersion 3.1.0

Write-Host -ForegroundColor white ""
Write-Host -ForegroundColor white "Importing modules."
Write-Host -ForegroundColor white ""
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1" 

## Install/import ExchangeOnlineManagement Module
$m = "ExchangeOnlineManagement"
function Load-Module ($m) {

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host "Module $m is already imported."
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Install-Module -Name $m -Force -Scope CurrentUser -RequiredVersion 3.0.1
                Import-Module $m
            }
            else {

                # If the module is not imported, not available and not in the online gallery then abort
                write-host "Module $m not imported, not available and not in an online gallery, exiting."
                exit 1
            }
        }
    }
}

Load-Module "$m"


## Connecting to VB365 Server
Write-Host -ForegroundColor white "`nConnecting to VB365 Server: $vb365server"
Disconnect-VBOServer
Connect-VBOServer -Server $vb365server
Write-Host -ForegroundColor white "Starting VB365 Organization Synchronization"
Start-VBOOrganizationSynchronization -Organization $vb365org -Full:$true
Get-VBOOrganizationSynchronizationState -Organization $vb365org
Write-Host -ForegroundColor white "Done."


$LogFileAdded = "$workingdir\Logfiles\VBO-Mailboxes-added.log"
$LogFileSkipped = "$workingdir\Logfiles\VBO-Mailboxes-skipped.log"
$MailboxExportFile = "$workingdir\Temp\MailboxesToAddToVBO-Job.txt"

# The Filter file can be used to put in UPNs of accounts that you want to filter out (not added to the backup job).
$FilterFile = "$workingdir\Filter\filter.txt"


# Create the folder structure for your Workingset. Edit when changing the actual location.
If(!(Test-Path -Path "$workingdir")){
    New-Item -Path "$workingdir" -ItemType Directory -Force
    Write-Host -ForegroundColor green "Created the Workingset folder structure."
    Write-Host ""
}
Else {
    Write-Host -ForegroundColor white "Workingset Folder structure in place."
    Write-Host ""
}

# Create the folder structure for your Filter location. Edit when changing the actual location.
If(!(Test-Path -Path "$workingdir\Filter")){
    New-Item -Path "$workingdir\Filter" -ItemType Directory -Force
    Write-Host -ForegroundColor green "Created the Filter folder structure."
    Write-Host ""
}
Else {
    Write-Host -ForegroundColor white "Filter Folder structure in place."
    Write-Host ""
}

# Create the folder structure for your Temp location. Edit when changing the actual location.
If(!(Test-Path -Path "$workingdir\Temp")){
    New-Item -Path "$workingdir\Temp" -ItemType Directory -Force
    Write-Host -ForegroundColor green "Created the Temp folder structure."
    Write-Host ""
}
Else {
    Write-Host -ForegroundColor white "Temp Folder structure in place."
    Write-Host ""
}

# Create the folder structure for your Logfiles location. Edit when changing the actual location.
If(!(Test-Path -Path "$workingdir\Logfiles")){
    New-Item -Path "$workingdir\Logfiles" -ItemType Directory -Force
    Write-Host -ForegroundColor green "Created the Logfiles folder structure."
    Write-Host ""
}
Else {
    Write-Host -ForegroundColor white "Logfiles Folder structure in place."
    Write-Host ""
}

# Create a filter file if does not exist.
If(!(Test-Path -path $FilterFile)){
    sleep 2
	New-Item -Path $FilterFile
    Write-Host -ForegroundColor green "Created a empty filter file."
    Write-Host ""
}
Else {
    Write-Host -ForegroundColor green "Filter file exists and can be used."
}

# stupid quick permissions hack
icacls $workingdir /grant:r Everyone:F /t  | Out-Null



## Checking if RecipientTypeDetails were set in the command or that we use the defaults
if($args[1].Length -gt 0){
	$RecipientTypeDetails = $args[1]
    Write-Host "`nRecipientTypeDetails were passed, searching for: "
	Write-Host "$($args[1])`n" -ForegroundColor Green 
}
else{
    Write-Host "`nNo RecipientTypeDetails were passed, using script defaults: "
	Write-Host "$($RecipientTypeDetails)`n" -ForegroundColor Green 
}

## Credential stuff, Logging in to Exchange Online and running the command
$user = $args[0]
$userfile = "$credsdir\$($user).txt"
$FileExists = Test-Path $userfile

if ($FileExists -eq $True) {
	Write-Host -ForegroundColor white "User Credentials exist, logging in..."
	## Encrypting User Credentials
	$encrypted = Get-Content $credsdir\$user.txt | ConvertTo-SecureString
	$logincredentials = New-Object System.Management.Automation.PsCredential($user, $encrypted)
	## Connecting to Exchange Online
	Write-Host -ForegroundColor white "Connecting to Exchange Online..."
	Connect-ExchangeOnline -Credential $logincredentials -ShowProgress:$false -ShowBanner:$false
	## Grab the Mailboxes
	Write-Host -ForegroundColor white "Getting mailboxes...`n"
	$Mailboxes = Get-EXOMailbox -ResultSize unlimited -RecipientTypeDetails $RecipientTypeDetails | Select UserPrincipalName
}
else {
	Write-Host -ForegroundColor white "User Credentials do not exist..."
	## Saving User Credentials (and creating path if needed)
	New-Item -ItemType Directory -Force -Path $credsdir | Out-Null
	Write-Host -ForegroundColor white "Saving encrypted credentials in: $($credsdir)\	" 
	$credential = Get-Credential -Credential $user
	$credential.Password | ConvertFrom-SecureString | Set-Content $credsdir\$($user).txt
	## Encrypting User Credentials
	$encrypted = Get-Content $credsdir\$user.txt | ConvertTo-SecureString
	$logincredentials = New-Object System.Management.Automation.PsCredential($user, $encrypted)
	## Connecting to Exchange Online
	Write-Host -ForegroundColor white "Connecting to Exchange Online..."
	Connect-ExchangeOnline -Credential $logincredentials -ShowProgress:$false -ShowBanner:$false
	## Grab the Mailboxes
	Write-Host -ForegroundColor white "Getting mailboxes...`n"
	$Mailboxes = Get-EXOMailbox -ResultSize unlimited -RecipientTypeDetails $RecipientTypeDetails | Select UserPrincipalName
}

Write-Host -ForegroundColor white "Disconnecting from Exchange Online."
Disconnect-ExchangeOnline -Confirm:$false


$Filters = Get-Content $FilterFile

# Create or clear the output file before the run.
If(!(Test-Path -path $MailboxExportFile)){
    New-Item -Path $MailboxExportFile
    Write-Host -ForegroundColor green "Created new Mailbox export text file at the start of the job."
    Write-Host ""
}
Else {
    Clear-Content -Path $MailboxExportFile
    Write-Host -ForegroundColor green "Cleared existing Mailbox export text file before running the job."
    Write-Host ""
}

# Export each mailbox found with the Get-EXOMailbox and create those to the output file. 
# This output file will be used to check which mailboxes are not yet added to the backup job.

Write-Host -ForegroundColor white "Writing mailbox output to output file."
Write-Host -ForegroundColor white ""

ForEach($Mailbox in $Mailboxes) {
    Write $Mailbox.UserPrincipalName | Out-File -Filepath $MailboxExportFile -Append
}

$Mailboxinput = Get-Content $MailboxExportFile
Write-Host -ForegroundColor white "Getting existing mailboxes from the VB365 Job."
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
        $M365User = Get-VBOOrganizationUser -Organization $vb365org -UserName $NewMailbox 
        $BackupItemUser = New-VBOBackupItem -User $M365User -Mailbox:$True -ArchiveMailbox:$False -OneDrive:$False -Sites:$False
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

Write-Host -ForegroundColor white "Mailboxes checked against filter and added new mailboxes to VB365 Job."
Write-Host -ForegroundColor white ""

# Variable for the calculation of total mailboxes added.
$TotalMailboxes = $ExistingMailboxes.count

Write-Host -ForegroundColor white "Finalizing."
Write-Host -ForegroundColor white ""

# Output will be written to the log file for auditing purposes. 
Write-Host "------------------------------------------------------------------------"
Write-Host -ForegroundColor white "A total of" $AddedMailboxes "new mailboxes are added to Org - Job:" $Job "."
Write-Host -ForegroundColor white "And a total of" $FilteredMailboxes "mailboxes are filtered out based on the filter specified."
Write-Host "------------------------------------------------------------------------"
Write-Output "$(Get-TimeStamp)" " A total of " $FilteredMailboxes " mailboxes are filtered out based on the filter specified" | Out-File -FilePath $LogFileSkipped -NoNewLine -Append
Write-Output "`n" | Out-File -FilePath $LogFileSkipped -Append
Write-Output "-------------------------------------------------------------------------------------------------------------------------" | Out-File -FilePath $LogFileSkipped -Append

# Variables will be removed after the script run to clean up the system for the next run.
Remove-Variable -Name * -ErrorAction SilentlyContinue -Exclude VerbosePreference
Write-Host -ForegroundColor white ""
Write-Host -ForegroundColor white "Cleaned up variables for the next run."