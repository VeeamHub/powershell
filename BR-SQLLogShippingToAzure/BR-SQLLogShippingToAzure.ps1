<#
.Synopsis
  Simple offload of SQL transaction logs to Azure Blob storage
.Notes
  Version: 0.1
  Author: Johan Huttenga
  Modified Date: 23-09-2020
.EXAMPLE
  BR-SQLLogShippingToAzure.ps1
#>

# This script is written to run from a local Windows backup repository as a scheduled task. 
#
# Be sure to update the variables below with the backup repository location, destination Azure Blob URL and SAS token
#
# Remember to ensure that the account running this script has the correct logon permissions
# as defined by local group policy, has the ability to execute powershell and access the data for upload.

$SourceBackupRepository = "C:\Backups\"
$DestinationBlobUrl = "https://<storage-account>.blob.core.windows.net/<container>/"
$DestinationBlobSASToken = "?<sas-token>"

# Subfolder created for each source host 
$DestinationBlobFolder = $env:computername 

# To shorten job run times this script only backs up the last 24 hours of data
# It is easy to change this behavior by having modified time set to zero
$ModifiedTime = (Get-Date).AddMinutes(-1440)

# Number of parallel jobs for AzCopy commands
$JobTaskCount = 64

# Logging
$LogFile = "BR-SQLLogShippingToAzure-$(get-date -UFormat "%d%m%Y-%H%M%S").log"
function LogWrite($content) {
    Write-Output $content
    $content = "$(get-date -UFormat "%Y-%m-%dT%H:%M:%S %Z"): "+$content
    Add-Content $LogFile -value $content
}

# This script expects AzCopy to be available on the command line path
if ((Get-Command "azcopy.exe" -ErrorAction SilentlyContinue) -eq $null) { 
    LogWrite "Unable to find azcopy.exe in PATH" 
    exit
}

$items  = Get-ChildItem -Path $SourceBackupRepository -Include *.vsm,*.vlm,*vlb -Recurse | Where {($_.LastWriteTime -ge $ModifiedTime)}
if ($items -eq $null) {
    LogWrite "Cannot find log files (*.vsm,*.vlm,*.vlb) in $($SourceBackupRepository)"
    exit
}

$functions = {
    
    function StartProcessRedirectWait ($Path, $Arguments) {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $Path
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.UseShellExecute = $false
        $pinfo.Arguments = $Arguments
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        $p.Start() | Out-Null
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        $p.WaitForExit()
        $exitcode = $p.ExitCode
        return [pscustomobject]@{
            StandardOutput = $stdout
            StandardError = $stderr
            ExitCode = $exitcode
        }
    }

    function Run-AzCopy($source, $dest) {
        $p = StartProcessRedirectWait -Path "C:\Users\johan.huttenga\Documents\azcopy.exe" -Arguments "cp $source $dest --overwrite ifSourceNewer"
        if ($p.StandardOutput.Contains("Status: Completed")) {
            $output = $p.StandardOutput.Split([System.Environment]::NewLine)
            $logfile = ""
            $throughput = 0
            $bytes = 0
            $completed = 0
            $failed = 1
            $skipped = 0
            foreach($l in $output) {
                if ($l.Contains("Log file")) { $logfile = $l.split(":")[1].Trim() }
                if ($l.Contains("Elapsed Time")) { $time = [double]$l.split(":")[1].Trim()*60 }
                if ($l.Contains("TotalBytesTransferred")) { $bytes = $l.split(":")[1].Trim() }
                if ($l.Contains("Completed:")) { $completed = $l.split(":")[1].Trim() }
                if ($l.Contains("Failed:")) { $failed = $l.split(":")[1].Trim() }
                if ($l.Contains("Skipped:")) { $skipped = $l.split(":")[1].Trim() }
            }
            if ($failed -eq 0 -and $skipped -eq 0) {
                Write-Output "Completed transfer of $($source) ($($bytes / [math]::Pow(1024,2)) MB in $($time))"
            }
            elseif ($skipped -eq 1) { 
                Write-Output "Skipped $($source) (only uploads if source newer)"
            }
            else {
                Write-Output "Failure occurred when transferring $($source). Check log for details: $($logfile)"
            }
        }
    }
}

foreach($item in $items) {
    $RunningJobs = @(Get-Job | Where-Object { $_.State -eq 'Running' })
    if ($RunningJobs.Count -ge $JobTaskCount) {
        $waitjob = $RunningJobs | Wait-Job -Any
        $result = Receive-Job $waitjob
        LogWrite $result
        Remove-Job $waitjob | Out-Null
    }

    $dest = "$($DestinationBlobUrl)$($DestinationBlobFolder)/$((Get-Date -Format o).Split("T")[0])/$($item.Name)$($DestinationBlobSASToken)"

    LogWrite "Transfering $($item.Name) to $($DestinationBlobUrl)..."

    Start-Job -Name "SQLLogShipToAzureBlob-$($item.Name)" -InitializationScript $functions -ScriptBlock {
        param($source, $dest)
        Run-AzCopy -Source $source -Dest $dest
    } -ArgumentList $item.FullName, $dest | Out-Null

}

Wait-Job -Name "SQLLogShipToAzureBlob*" | Out-Null

foreach($job in Get-Job -Name "SQLLogShipToAzureBlob*")
{
    $result = Receive-Job $job
    LogWrite $result
    Remove-Job $job | Out-Null
}