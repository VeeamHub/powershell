#
# Import all Veeam Cloud Connect backups
#
# v 1.0 - Luca Dell'Oca
# v 1.1 - Preben Berg - optimized for loops
# v 1.2 - Andrea Borella - minor changes for v9.5 compatibility
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

ForEach ($winrepo in Get-VBRBackupRepository | where Type -eq "WinLocal") {
    $winreponame = $winrepo.GetHost().Name;

    #obtain the full unc path of the repository to be passed to get-childitem
    $winrepopath = "\\{0}\{1}" -f ($winreponame, $winrepo.FriendlyPath.Replace(":", "$"));

    #browse recursively the repository to find any backup chain, by identifying all the .vbm files
    $winvbms = Get-ChildItem -Path $winrepopath -Filter "*.vbm" -Recurse -ErrorAction SilentlyContinue -Force

    # Import the backup chains into Veeam server
    ForEach ($vbm in $winvbms) {
        $path=$vbm.DirectoryName
        $vbmfile=$vbm.Name
        $winrepo.GetHost() | Import-VBRBackup -Filename $path\$vbmfile
    }
}


## Process Linux repositories

# Retrieve the list of linux repositories
$linuxrepos = Get-VBRBackupRepository | where Type -eq "LinuxLocal"

if (Get-Command -Name "New-SSHSession" -ErrorAction SilentlyContinue) {
    ForEach ($linuxrepo in $linuxrepos) {
        $linuxreponame = $linuxrepo.GetHost().Name;

        # Login via ssh into the linux repository (interactive username and password request)
        New-SSHSession -ComputerName $linuxreponame -Credential (Get-Credential) -AcceptKey

        # find all .vbm files in the linux repository, output has full path
        $linuxvbms = Invoke-SSHCommand -SessionId 0 -Command "find / -type f -name *.vbm" | select -ExpandProperty Output

        # close the SSH session
        Remove-SSHSession -SessionId 0

        # Import the backup chains into Veeam server
        ForEach ($linuxvbm in $linuxvbms) {
            $linuxrepo.GetHost() | Import-VBRBackup -Filename $linuxvbm
        }
    }
} else {
    Write-Host "Found Linux repositories, but missing PoSSH";
}
