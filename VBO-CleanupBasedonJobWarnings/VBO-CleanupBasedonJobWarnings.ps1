<# 
.NAME
    VBO-CleanupBasedonJobWarnings.ps1
.SYNOPSIS
    Processes specific users, recipient types, and group members in Veeam Backup for Microsoft Office 365 backup jobs which are for some reason not valid anymore.
    Example scenarios: User account removed, Exchange Mailbox removed in Exchange / Exchange Online or user in group wrongfully added to VBO job, such as user-added without Mailbox. 
    Cleans up specific users and recipient types which do not exist anymore, and adds specific group members from backup jobs to the exclusion list.
    The script works based on a job input text file in which you specify for which jobs this script needs to run (line per line bases).
    The script outputs job information such as Groups and Group Members with UIDs and logs all cleanup and exclusion actions in a log file. 
    This script is tested on jobs build from Groups (Security, Distribution and Dynamic Groups), Single Users added to a job, and Dynamically added Recipient Types based on VBO-IncludeSpecificRecipientTypes.ps1 script.
.DESCRIPTION
    Script to use for removing O365 accounts in Veeam Backup for Microsoft Office 365 backup jobs based on warnings generated in the job log.
    Released under the MIT license.
#>

#Function to timestamp input in logfiles
    function Get-TimeStamp {
   
    return "[{0:dd-MM-yyyy}] [{0:HH:mm:ss}]" -f (Get-Date)
   
}

# Do not change below unless you know what you are doing
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

######################################################################
# Modify the values below to your needs
$Org = Get-VBOOrganization -Name "Your Tenant"
$LogFile = "C:\Temp\VBOJobCleanup.log"
$Jobs = Get-Content -Path C:\Temp\VBOJobsToProcess.txt
$MembersUIDlog = "C:\Temp\VBOGroupMemberOutput.log"
######################################################################
# Do not change below unless you know what you are doing# Arrays for processing and comparing.$GroupMemberNames = @()$ProcessedUsers = @()# Create a VBO Temp-Out file if does not exist.
If(!(Test-Path -Path $MembersUIDlog)){
    New-Item -Path $MembersUIDlog
}
Else {
    New-Item -Path $MembersUIDlog -Force
}# Getting information from each job to process groups, and group members in each job.foreach ($Job in $Jobs) {$JobtoRun = Get-VBOJob -Name $Job$GroupsinJob = Get-VBOBackupItem -Job $JobtoRun -GroupsWrite-Output "--------------------------------------------------------------------------------------------------" | Out-File -FilePath $MembersUIDlog -Appendwrite-Output "$(Get-TimeStamp)" " [Info]: " "Job: " $Job  | Out-File -FilePath $MembersUIDlog -NoNewLine -AppendWrite-Output "`n" | Out-File -FilePath $MembersUIDlog -Append# Listing Groups in backup job to process  foreach ($Group in $GroupsinJob) {
         $GroupDisplayName = $Group.Group.DisplayName
         $Groups = Get-VBOOrganizationGroup -Organization $org -DisplayName $GroupDisplayName         $GroupMember = Get-VBOOrganizationGroupMember -Group $Groups         write-Output "$(Get-TimeStamp)" " [Info]: Group: " $Groups.DisplayName | Out-File -FilePath $MembersUIDlog -NoNewLine -Append         Write-Output "`n" | Out-File -FilePath $MembersUIDlog -Append# Getting Groupmembers from groups in backup job to process         if ($Groups -ne $null) {             foreach($Member in $GroupMember){            $MemberUID = Get-VBOOrganizationUser -Organization $org -UserName $Member            write-Output "$(Get-TimeStamp)" " [Info]: User: " $MemberUID.DisplayName " with UID: " $MemberUID.OfficeId.Guid | Out-File -FilePath $MembersUIDlog -NoNewline -Append            Write-Output "`n" | Out-File -FilePath $MembersUIDlog -Append
            ForEach-Object {
            $GroupMemberNames += $MemberUID
            }           }          }
         }# If no groups exist in job to process this will output "No Groups in Job" in the log file         if ($GroupsinJob -eq $null) {
         Write-Output "$(Get-TimeStamp) [Info]: No Groups in Job" | Out-File -FilePath $MembersUIDlog -NoNewLine -Append
         Write-Output "`n" | Out-File -FilePath $MembersUIDlog -Append          }
    
# Job members found in joblog, which match the warnings specfied, will be removed from job.
# Adjust the seperators to your own needs, but be aware of the concequences when removing job members based on other warnings than specified.

$Warnings = @()

# Getting last job session and job log.
$JobSession = Get-VBOJobSession -Job $JobtoRun -Last
$JobLog = $JobSession.Log

# Checks for warnings in job log based on the following seperators

# Seen when a member of a Group (Security / Distribution or Dynamic Group) or a single user does not have a Exchange account anymore, but Exchange object processing in part of the backup job.
$Seperator1 = '\[Warning\].*(Exchange\saccount\swas\snot\sfound)'

# Seen when a Shared Mailbox or other RecipientType Mailbox does not exist anymore, but account is still part of the backup job.
$Seperator2 = '\[Warning\].*(User\swas\snot\sfound)'

# To be used for other warnings to be specified for your own needs.
$Seperator3 = '\[Warning\].*(ToBeDefined)'

$SeperatorWarnings1 = $JobLog.Title -match "$Seperator1"ForEach-Object {                $Warnings += $SeperatorWarnings1                }
$SeperatorWarnings2 = $JobLog.Title -match "$Seperator2"ForEach-Object {                $Warnings += $SeperatorWarnings2                }

$SeperatorWarnings3 = $JobLog.Title -match "$Seperator3"ForEach-Object {                $Warnings += $SeperatorWarnings3                }
# For each warning seen in the job log, the script checks if it regards a user of a group member. Based on this check the script will process either: 1. A removal for an individual object and 2. An exclusion for a group member part of a group in the job.
foreach ($JobWarning in $Warnings) {        $SelectedUsers = Get-VBOBackupitem -Job $JobtoRun -Users        $UID = $JobWarning.Split('(ID: ')        $UID = $UID[-1].TrimEnd(')')# Individual object check - which will remove object when match with warning seen in job log    if ($SelectedUsers.User.OfficeID -ccontains $UID){        $RemoveUser = Get-VBOBackupItem -Job $JobtoRun | Where-Object {$_.User.OfficeId -ccontains $UID}    if ($RemoveUser -ne $null){        Remove-VBOBackupItem -Job $JobtoRun -BackupItem $RemoveUser        Write-Host -ForegroundColor Green "User" $RemoveUser.User.DisplayName "with UID '$UID' has been removed from backup job '$($Job)'"        Write-Output "$(Get-TimeStamp) [Info]: User "$RemoveUser.User.DisplayName " with UID '$UID' has been removed from backup job '$($Job)'" | Out-File -FilePath $LogFile -NoNewLine -Append        Write-Output "`n" | Out-File -FilePath $LogFile -Append        }        }# Group member check - which will exclude if match with warning seen in job log   elseif ($GroupMemberNames.OfficeID -ccontains $UID){        $ExcludedUsersinJob = Get-VBOexcludedbackupitem -job $JobtoRun        $User = $GroupMemberNames | Where-Object {$_.OfficeID -ccontains $UID}        if($ExcludedUsersinJob.User.OfficeId -eq $User.OfficeId){        Write-Host "[Info] User:" $User.DisplayName "already excluded in job: '$Job'"        Write-Output "$(Get-TimeStamp) [Info] User: " $User.DisplayName " with UID: " $User.OfficeId.Guid " is already excluded in job: '$Job'" | Out-File -FilePath $LogFile -NoNewLine -Append        Write-Output "`n" | Out-File -FilePath $LogFile -Append        }      elseif($User.OfficeId -ne $null){        $ExcludeUser = New-VBOBackupItem -User $User -Mailbox:$true -ArchiveMailbox:$true        Add-VBOExcludedBackupItem -Job $JobtoRun -BackupItem $ExcludeUser# Makes sure that each user is processed only once, even when multiple warnings with same UID are found.        ForEach-Object {        $ProcessedUsers += $ExcludeUser.User.OfficeID        }        Write-Host -ForegroundColor Green "User "$ExcludeUser.User.DisplayName " with UID '$UID' has been excluded from backup job '$($Job)'"        Write-Output "$(Get-TimeStamp) [Info]: User " $ExcludeUser.User.DisplayName " with UID '$UID' has been excluded from backup job '$($Job)'" | Out-File -FilePath $LogFile -NoNewLine -Append        Write-Output "`n" | Out-File -FilePath $LogFile -Append        }        }       }     }

# Cleaning up variables used in this session.
Remove-Variable -Name * -ErrorAction SilentlyContinue


