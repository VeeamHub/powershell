<# 
.NAME
    Veeam Backup for Microsoft Office 365 Backup Job Reporter
.SYNOPSIS
    Script to use for getting a detailed report per backup job modification
.DESCRIPTION
    This script will check all the backup jobs, store the backup job included items in a file and do a comparison every run to see what has changed
    Can be used in combination with Windows Task Schedule
    Created for Veeam Backup for Microsoft Office 365 v4
    Released under the MIT license.
.LINK
    http://www.github.com/nielsengelen
#>

# Modify the values below to your needs
$Folder = "c:\VBO365JobReporter"
$File = "output"

# Do not change below unless you know what you are doing
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

# Array for already backed up accounts
$BackedupNames = @()

# Get all the repositories
$Jobs = Get-VBOJob
    
# Go over each job
ForEach ($Job in $Jobs) {
    $csvPath = $Folder + "\" + $File + "-" + $Job.Organization.Name + ".csv" # csv path based upon folder and file input

    if(!(Test-Path $csvPath)) {
        # Create the folder and file if needed
        New-Item -ItemType Directory -Force -Path $Folder | Out-Null
        New-Item -ItemType File -Force -Path $csvPath | Out-Null
    } else {
        # Import existing data if the file exists
        Import-Csv $csvPath | `
            ForEach-Object {
                $BackedupNames += $_.DisplayName
            }
    }

    $Data = Get-VBOEntityData -Type User -Repository $Job.Repository | Where-Object {$_.Organization.DisplayName -eq $Job.Organization.Name}

    # Selected items backup job
    # We will only match the items included in a backup job against the repository data
    if ($Job.JobBackupType -eq "SelectedItems") {
        # Users
        $Items = Get-VBOBackupItem -Job $Job -Users
        $Names = $Items.User | Select DisplayName 

        ForEach ($Name in $Names) {
            if ($BackedupNames -notcontains $Name.DisplayName) {
                $Match = $Data | Where {$_.DisplayName -eq $Name.DisplayName} | Select DisplayName,IsMailboxBackedUp,MailboxBackedUpTime,IsArchiveBackedUp,ArchiveBackedUpTime,IsOneDriveBackedUp,OneDriveBackedUpTime,IsPersonalSiteBackedUp,PersonalSiteBackedUpTime,@{Label=”Organization”;Expression={$_.Organization.DisplayName}}
                $Match | Export-CSV –Append -NoTypeInformation –Path $csvPath
            }
        }

        # Groups
        $Groups = Get-VBOBackupItem -Job $Job -Groups

        ForEach ($Group in $Groups) {
            $Members = Get-VBOOrganizationGroupMember -Group $group.Group

            ForEach ($Member in $Members) {
                if ($BackedupNames -notcontains $Member.DisplayName) {
                    $Match = $Data | Where {$_.DisplayName -eq $Member.DisplayName} | Select DisplayName,IsMailboxBackedUp,MailboxBackedUpTime,IsArchiveBackedUp,ArchiveBackedUpTime,IsOneDriveBackedUp,OneDriveBackedUpTime,IsPersonalSiteBackedUp,PersonalSiteBackedUpTime,@{Label=”Organization”;Expression={$_.Organization.DisplayName}}
                    $Match | Export-CSV –Append -NoTypeInformation –Path $csvPath
                }
            }
        }
    } else {
        # Full organization backup job
        # Check the repository for the data
        $Result = $Data | Select DisplayName,IsMailboxBackedUp,MailboxBackedUpTime,IsArchiveBackedUp,ArchiveBackedUpTime,IsOneDriveBackedUp,OneDriveBackedUpTime,IsPersonalSiteBackedUp,PersonalSiteBackedUpTime,@{Label=”Organization”;Expression={$_.Organization.DisplayName}}
        $Result | Export-CSV –Append -NoTypeInformation –Path $csvPath
    }
}