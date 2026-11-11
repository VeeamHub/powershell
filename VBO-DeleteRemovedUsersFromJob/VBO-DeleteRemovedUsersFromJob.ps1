<# 
.NAME
    Veeam Backup for Microsoft Office 365 clean up script for O365 accounts without an Exchange account
.SYNOPSIS
    Remove users without Exchange account from backup jobs
.DESCRIPTION
    Script to use for removing O365 accounts without an Exchange account from backup jobs
    Released under the MIT license.
.LINK
    http://www.github.com/nielsengelen
#>

# Modify the values below to your needs
$JobName = "TEST"

# Do not change below unless you know what you are doing
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

$Job = Get-VBOJob -Name $JobName
$JobSession = Get-VBOJobSession -Job $Job -Last
$SelectedItems = $Job.SelectedItems
$SelectedUser = $Job.SelectedItems.User
$JobLog = $JobSession.Log

$Seperator = '\[Warning\].*(Exchange\saccount\swas\snot\sfound)'
$Warnings = $JobLog.Title -match "$Seperator"

foreach ($JobWarning in $Warnings) {
    $UID = $JobWarning.Split('(ID: ')
    $UID = $UID[-1].TrimEnd(')')

    $RemoveUser = $SelectedItems | Where-Object {$_.User.OfficeId -eq $UID}
    $DisplayName = $($SelectedUser | Where-Object {$_.OfficeId -eq $UID} | Select-Object -ExpandProperty DisplayName)
    
    try {
        Remove-VBOBackupItem -Job $job -BackupItem $RemoveUser -ErrorAction Stop
        Write-Host -ForegroundColor Green "User named '$DisplayName' with GUID '$UID' has been removed from backup job '$($Job.Name)'."
    } catch {
        Write-Host -ForegroundColor Red "User named '$DisplayName' with GUID '$UID' could not be removed from backup job '$($Job.Name)'."
    }
}