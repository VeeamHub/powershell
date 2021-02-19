#
# v0.1 Nutanix Files SMB NAS backup pre-job execution script.
#
# TODO - NFS support
#
# PREREQUISITES - Veeam PowerShell snapin (v10) module (v11)
#
# INPUTS - 
#    share path(s) e.g. \\myfilessvr\mysmbshare (must match VBR-define fileserver path e.g. no trailing "\"), multiple paths are supported
#
# OPERATION - The fileshare path is used to retrieve the existing VBR file server.  Since Nutanix Files
# snapshots will (should!) already exist, the latest hourly snapshot folder will then be retrieved and 
# used the source snapshot folder defined for the file server. The file server properties are also
# set to backup from snapshot.
#

function getFileServer($fs) {
    try {
        $vbrNASSvr = Get-VBRNASServer | where {$_.Path -eq $fs}
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

function getLatestSnapshot($snapDir) {
    try {
        $snaps = Get-ChildItem -Directory $snapDir |  where {$_.Name -like "*hourly*"} | Sort-Object -Property "Name" -Descending
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
        Write-Host $fs
        if (($fileserver = getFileServer($fs)) -ne $null) {
            try {
                $snapDir = $fs+'\.SNAPSHOT'
                Write-Host $snapDir
                if (($snapName = getLatestSnapshot($snapDir)) -ne $null) {
                    Set-VBRNASSMBServer -Server $fileserver -StorageSnapshotPath $snapDir\$snapName -ProcessingMode StorageSnapshot
                    #exit 0
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