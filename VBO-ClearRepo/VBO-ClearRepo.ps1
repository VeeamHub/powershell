<# 
.NAME
    Veeam Backup for Microsoft Office 365 clean up script for a specific repository
.SYNOPSIS
    Removes all data from a specific repository
.DESCRIPTION
    Script to use for removing all data from a specific repository
    Released under the MIT license.
.LINK
    http://www.github.com/nielsengelen
#>

Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

$repo = Get-VBORepository -Name "NEWREPO" # Change this to match your repository
$usersList = Get-VBOEntityData -Type User -Repository $repo
$groupsList = Get-VBOEntityData -Type Group -Repository $repo
$sitesList = Get-VBOEntityData -Type Site -Repository $repo

# Remove all users
foreach ($user in $usersList) {
	Remove-VBOEntityData -Repository $repo -User $user -Mailbox -ArchiveMailbox -OneDrive -Sites -Confirm:$false
}

# Remove all groups
foreach ($group in $groupsList) {
	Remove-VBOEntityData -Repository $repo -Group $group -Mailbox -ArchiveMailbox -OneDrive -Sites -GroupMailbox -GroupSite -Confirm:$false
}

# Remove all sites
foreach ($site in $sitesList) {
	Remove-VBOEntityData -Repository $repo -Site $site -Confirm:$false
}