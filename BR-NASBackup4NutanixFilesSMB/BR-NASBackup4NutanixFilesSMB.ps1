#
# v0.1 Nutanix Files SMB NAS backup pre-job execution script.
##
# PREREQUISITES - Veeam PowerShell snapin (v10) module (v11)
#
# INPUTS - 
#    share path(s) e.g. \\myfilessvr\mysmbshare (must match VBR-define fileserver path e.g. no trailing "\"), multiple paths are supported
#
# OPERATION - The fileshare path is used to retrieve the existing VBR file server.  Since Nutanix Files
# snapshots will (should!) already exist (this assumes self-service restore has been enabled on the Files
# share), the latest hourly snapshot folder will then be retrieved and used as the source snapshot folder
# defined for the file server. The file server properties are also set to backup from snapshot.
#

function Get-FileServer($fs) {
    try {
        $vbrNASSvr = Get-VBRNASServer | Where-Object {$_.Path -eq $fs}
        if ($vbrNASSvr.Count -gt 0) {
            return $vbrNASSvr
        }
        else {
            return $null
        }
    }
    catch {
        write-host "Exception in getFileServer"
       return $null
    }
}

function Get-LatestSnapshot($snapDir) {
    try {
        $snaps = Get-ChildItem -Directory $snapDir | Where-Object {$_.Name -like "*hourly*"} | Sort-Object -Property "Name" -Descending
        if ($snaps.Count -gt 0) {
            return $snaps[0]
        }
        else {
            return $null
        }
    }
    catch {
        write-host "Exception in getLatestSnapshot"
        return $null
    }   
}

#
# uncomment per your VBR platform PSSnapin for v10, Module for v11
#
Add-PSSnapin VeeamPSSnapin    #v10
#Import-Module Veeam.Backup.PowerShell  #v11

if ($args.Count -gt 0) {
    foreach ($fs in $args) {
        if (($fileserver = Get-FileServer($fs)) -ne $null) {
            try {
                $snapDir = $fs+'\.snapshot'
                if (($snapName = Get-LatestSnapshot($snapDir)) -ne $null) {
                    Set-VBRNASSMBServer -Server $fileserver -StorageSnapshotPath $snapDir\$snapName -ProcessingMode StorageSnapshot
                    exit 0
                }
                else {
                    write-host "Files snapshot not found!"
                    exit 1
                }
            }
            catch {
                write-host "Exception in main"
                exit 1
            }
        }
        else
        {
            write-host "VBR file server not found!"
            exit 1
        }
    }
    exit 0
}
else {
    Write-Host "USAGE: BR-NASBackup4NutanixFilesSMB.ps1 <fileserver path 0> [<fileserver path 1>...]"
    exit 1
}