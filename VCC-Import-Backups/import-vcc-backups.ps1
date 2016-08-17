# 
# Import all Veeam Cloud Connect backups
#
# v 1.0 - Luca Dell'Oca
#
# Run this script on the Veeam server
#
# Script workflow:
# 1. retrieves the list of repositories, first windows than # linux
# 2. lists recursively all the existing backup chains (.vbm files)
# 3. imports all the chains into the VBR server
# 
# To use the SSH commands, you need to have Posh-SSH module installed.
# To install the module, you need to run this code on Windows 10, or
# have Windows Management Framework 5.0 installed. Once ready, run:
#
# Install-Module Posh-SSH


# Load Veeam powershell snapin
asnp VeeamPSSnapIn -ErrorAction SilentlyContinue

## Process Windows repositories

# Retrieve the list of windows repositories
$winrepos = Get-VBRBackupRepository | where Type -eq "WinLocal" | ForEach-Object { (echo $($_.FindHost().name)) }

ForEach ($winrepo in $winrepos) {
    #obtain the full unc path of the repository to be passed to get-childitem
    $winrepopath = Get-VBRBackupRepository | where Type -eq "WinLocal" | ForEach-Object { (echo \\$($_.FindHost().name)\$($_.path)).Replace(":","$") }
    
    #browse recursively the repository to find any backup chain, by identifying all the .vbm files
    $winvbms = Get-ChildItem -Path $winrepopath -Filter "*.vbm" -Recurse -ErrorAction SilentlyContinue -Force | ForEach-Object { echo $($_.FullName).replace("$",":") }
    
    #remove the server part from the unc path so we have the complete local path of the vbm
    $winvbms = $winvbms -replace '^\\\\[^\\]+\\'
    
    # Import the backup chains into Veeam server
    ForEach ($winvbm in $winvbms) {
        Get-VBRServer –Name $winrepo | Import-VBRBackup -Filename $winvbm
    }
}


## Process Linux repositories

# Retrieve the list of linux repositories
$linuxrepos = Get-VBRBackupRepository | where Type -eq "LinuxLocal" | ForEach-Object { (echo $($_.FindHost().name)) }

ForEach ($linuxrepo in $linuxrepos) {

    # Login via ssh into the linux repository (interactive username and password request)
    New-SSHSession -ComputerName $linuxrepo -Credential (Get-Credential) -AcceptKey

    # find all .vbm files in the linux repository, output has full path
    $linuxvbms = Invoke-SSHCommand -SessionId 0 -Command "find / -type f -name *.vbm" | select -ExpandProperty Output

    # close the SSH session
    Remove-SSHSession -SessionId 0

    # Import the backup chains into Veeam server
    ForEach ($linuxvbm in $linuxvbms) {
        Get-VBRServer –Name $linuxrepo | Import-VBRBackup -Filename $linuxvbm
    }
}