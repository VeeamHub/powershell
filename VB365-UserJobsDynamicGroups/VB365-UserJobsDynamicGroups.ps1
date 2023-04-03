<# 
   .SYNOPSIb
   Creating Azure AD dynamic groups with user membership based on regex and creating VB365 backup jobs for every group.

   .DESCRIPTION
   !!! You need to use the Microsoft AzureADPreview module since the parameter "MembershipRule" is only available in the beta of GraphAPI.
   -> Install-Module AzureADPreview -Scope CurrentUser -AllowClobber !!!
   
   Requires: Microsoft subscription which includes at least Azure AD Premium P1 features.

   This script creates Azure AD dynamic groups to split up the users of a whole tenant based on the first two characters of their ObjectID. 
   The number of groups beeing created is depending on the array of first and second character.
   Per default, this script will create 64 groups, since the first charakter will be from "0" to "f" and the second character will be grouped in 4 expression ranges.
   VB365 backup jobs will be created for every dynamic group and separatly for Exchange Online and OneDrive.
    
   .NOTES 
   Version:        1.1
   Author:         David Bewernick (david.bewernick@veeam.com)
   Creation Date:  03.04.2023

   .CHANGELOG
   1.0   31.03.2023   Script created
   1.1   03.04.2023   Description and dynamic membership rules extention

 #> 

# Enable (1) or disable (0) debug messages
$debug = 0

# Install-Module AzureADPreview -Scope CurrentUser -AllowClobber #uncomment this to install the AureADPreview module

$timestampFileName = get-date -Format "yyyy-mm-dd_HH-mm-ss"
[string[]]$script:arrFirstChar = @("0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f") #array of characters for the regex
[string[]]$Script:arrScndChar = @('0-3','4-7','8-9a-b','c-f')

# Variables to fit your needs
$OrgName = "XYZ.onmicrosoft.com" # The name of your M365 organization
$RepoName = "XYZ-Repo" # Define the target repository
$LogFile = "VBO-CreateDynamicGroups.log" #logfile name
$GroupNameFile = "DynamicGroupsList_$timestampFileName.log" #file to export group names
$strGroupNameStart = "VB365-UserBackup_" #start of the Azure AD dynamic group names
$strJobNameStartExch = "Exch_" #start of the Exchange Online job names
$strJobNameStartOD = "OD_" #start of the OneDrive job names

# Get the organizsation in an object
$vbOrgObject = Get-VBOOrganization -Name $OrgName
# Get the VB365 target repository object
$vbRepoObject = Get-VBORepository -Name $RepoName

# Define the backup schedule for new jobs (Options Info: https://helpcenter.veeam.com/archive/vbo365/40/powershell/new-vbojobschedulepolicy.html)
$vbSchedType = "daily"
$vbSchedDailyType = "Everyday"
$vbSchedStartHr = "22"
$vbSchedStartMin = "00"

# Time to delay in minutes for the next created job
$global:vbSchedDelayMin = "2"

# Create the initial start time value
$global:vbDailyTime = "$vbSchedStartHr" + ":" + "$vbSchedStartMin" + ":00"

#Function for logging and console output
function Write-Log($Info, $Status){
    $timestamp = get-date -Format "yyyy-mm-dd HH:mm:ss"
    switch($Status){
        Info    {Write-Host "$timestamp $Info" -ForegroundColor Green  ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
        Status  {Write-Host "$timestamp $Info" -ForegroundColor Yellow ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
        Warning {Write-Host "$timestamp $Info" -ForegroundColor Yellow ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
        Error   {Write-Host "$timestamp $Info" -ForegroundColor Red -BackgroundColor White; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
        default {Write-Host "$timestamp $Info" -ForegroundColor white "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
    }
}

# Create a time object for later modification
$global:vbSchedTimeObj = New-Object DateTime 2022, 1, 1, $vbSchedStartHr, $vbSchedStartMin, 0, ([DateTimeKind]::Utc)
if($debug="1"){Write-Host "Initial vbSchedTimeObj: $vbSchedTimeObj"}

# Build the initial backup job schedule
$global:vbSchedule = New-VBOJobSchedulePolicy -Type $vbSchedType -DailyType $vbSchedDailyType -DailyTime $vbDailyTime
Write-Log -Info "New jobs will be created with this initual schedule:`n`t`t`t`t Type: $($vbSchedule.Type) `n`t`t`t`t DailyType: $($vbSchedule.DailyType) `n`t`t`t`t DailyTime: $($vbSchedule.DailyTime) `n`t`t`t`t Delay for the next job: $vbSchedDelayMin" -Status Info

function AddTimeDelay(){

    if($debug="1"){Write-Host "vbSchedTimeObj before delay: $vbSchedTimeObj"}

    # Add the delay minutes
    $global:vbSchedTimeObj = $vbSchedTimeObj.AddMinutes($vbSchedDelayMin)
    if($debug="1"){Write-Host "vbSchedTimeObj after delay: $vbSchedTimeObj"}

    # Recreate the DailyTime value
    $global:vbDailyTime = $vbSchedTimeObj.ToString("HH:mm:ss")
    if($debug="1"){Write-Host "vbDailyTime: $vbDailyTime"}

    # Recreate the schedule object with the new start time
    $global:vbSchedule = New-VBOJobSchedulePolicy -Type $vbSchedType -DailyType $vbSchedDailyType -DailyTime $vbDailyTime
    if($debug="1"){Write-Host "vbSchedule: $vbSchedule"}
}

#Function to create the Azure AD dynamic groups and backup jobs in VB365
function create-groups(){ 
    $i=0
    while($i -lt $arrFirstChar.length){ #go through the array for the first character
        $j=0            
        while($j -lt $arrScndChar.length){ #go through the array for the second character
            $strRegex = '^' + $arrFirstChar[$i] + '[' + $arrScndChar[$j] + ']' #building the regex based on the array strings
            $strGroupName = $strGroupNameStart + $arrFirstChar[$i] + $arrScndChar[$j] #create the group name
            $strMembershipRule = '(user.objectID -match "' + $strRegex + '") and (user.mail -ne "$null") and (user.accountEnabled -eq true) and (user.assignedPlans -ne $null) and (user.assignedPlans -any (assignedPlan.capabilityStatus -eq "Enabled"))' #define the Membership rule based on the regex and additional properties"
            #Write-Output $strGroupName
            #Write-Output $strRegex
            #Write-Output $strMembershipRule

            if((Get-AzureADMSGroup | where{$_.DisplayName -eq $strGroupName}) -eq $null) {
                try {
                    New-AzureADMSGroup -DisplayName "$strGroupName" -MailNickname "$strGroupName" -Description "Group for VBO backup with rule $strRegex" -MailEnabled $false -GroupTypes {DynamicMembership} -SecurityEnabled $true -MembershipRule "$strMembershipRule" -MembershipRuleProcessingState 'on' #this is finally creating the dynamic group in AzureAD
                    Write-Log -Info "Group $strGroupName created with MembershipRule $strMembershipRule" -Status Info
                    $strGroupName | Out-File -FilePath $GroupNameFile -Append # write groupname to CSV file
                }
                catch{
                    Write-Log -Info "$_" -Status Error
                    Write-Log -Info "Group $strGroupName could not be created" -Status Error
                    exit 99
                }
            }
            else { 
                Write-Log -Info "Group $strGroupName is already existing" -Status Status
                $strGroupName | Out-File -FilePath $GroupNameFile -Append # write groupname to CSV file
            }

            # Call the function to create or modify the backup job
            create-jobs($strGroupName)

            $j++
        }
    $i++
    }
   
}



# Function to create the backup jobs based on the group name
function create-jobs ($strGroupName){

    # get the organization group in an object
    $orggroup = Get-VBOOrganizationGroup -Organization $org -DisplayName $strGroupName
    # create backup job item objects for Exchange and OneDrive
    $ExchJobItem = New-VBOBackupItem -Group $orggroup -Mailbox -ArchiveMailbox
    $ODJobItem = New-VBOBackupItem -Group $orggroup -OneDrive
    
    $ExchJobName = $strJobNameStartExch + $strGroupName
    $ODJobName = $strJobNameStartOD + $strGroupName

    ### Modify or create Exchange backup job ###

    # Check if job exist and add group

    if ($VbJob=Get-VBOJob | ? {$_.Name -like $ExchJobName}){
        Write-Log -Info "$ExchJobName exists, adding $strGroupName" -Status Info
        Add-VBOBackupItem -Job $VbJob -BackupItem $ExchJobItem

    }

    # If job does not exist create it including the site
    else {
        Write-Log -Info "Creating $ExchJobName and adding $strGroupName" -Status Info
        Add-VBOJob -Organization $vbOrgObject -Name "$ExchJobName" -Repository $vbRepoObject -SchedulePolicy $vbSchedule -SelectedItems $ExchJobItem

        # Increase the time for the next schedule
        if($debug="1"){Write-Host "Schedule before delay: $($vbSchedule.DailyTime)"}
        AddTimeDelay
        if($debug="1"){Write-Host "Schedule after delay: $($vbSchedule.DailyTime)"}
    }

    ### Modify or create OneDrive backup job ###

    # Check if job exist and add group

    if ($VbJob=Get-VBOJob | ? {$_.Name -like $ODJobName}){
        Write-Log -Info "$ODJobName exists, adding $strGroupName" -Status Info
        Add-VBOBackupItem -Job $VbJob -BackupItem $ODJobItem

    }

    # If job does not exist create it including the site
    else {
        Write-Log -Info "Creating $ODJobName and adding $strGroupName" -Status Info
        Add-VBOJob -Organization $vbOrgObject -Name "$ODJobName" -Repository $vbRepoObject -SchedulePolicy $vbSchedule -SelectedItems $ODJobItem

        # Increase the time for the next schedule
        if($debug="1"){Write-Host "Schedule before delay: $($vbSchedule.DailyTime)"}
        AddTimeDelay
        if($debug="1"){Write-Host "Schedule after delay: $($vbSchedule.DailyTime)"}
    }
}

### MAIN ###

# Connecting to AzureAD
Write-Log -Info "Trying to connect to AzureAD..." -Status Info
    try {
        Connect-AzureAD
        $ConnectionAccountName = Get-AzureADCurrentSessionInfo | select Account
        Write-Log -Info "Connection successful with $ConnectionAccountName" -Status Info
        } 
    catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Could not connect with $ConnectionAccountName" -Status Error
        exit 99
    }


Write-Log -Info "Creating the groups and jobs..." -Status Info

create-groups

#Disconnecting from AzureAD
Write-Log -Info "Trying to disconnect from AzureAD..." -Status Info
    try {
        Disconnect-AzureAD
        Write-Log -Info "Successfully disconnected" -Status Info
        } 
    catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Could not disconnect from AzureAD" -Status Error
        exit 99
    }
