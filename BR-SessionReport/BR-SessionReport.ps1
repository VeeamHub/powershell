<#
    .SYNOPSIS
    Veeam Session Report
  
    .DESCRIPTION
    This Script will Report Statistics about Session during a given windows (default: last 24 Hours) and Actual Repository usage.
        
    .EXAMPLE
    BR-SessionReport.ps1 -BRHost "veeam01.lan.local"
    .EXAMPLE
    BR-SessionReport.ps1 -BRHost "veeam01.lan.local" -reportMode Weekly

    .EXAMPLE
    BR-SessionReport.ps1 -BRHost "veeam01.lan.local" -reportMode 12

    .EXAMPLE
    BR-SessionReport.ps1 -BRHost "veeam01.lan.local" -reportMode Monthly -repoCritical 5 -repoWarn 10

    .Notes
    NAME:  BR-SessionReport.ps1
    LASTEDIT: 08/23/2016
    VERSION: 1.0
    KEYWORDS: Veeam, Sessions
    BASED ON: http://mycloudrevolution.com/2016/03/21/veeam-prtg-sensor-reloaded/
   
    .Link
    http://mycloudrevolution.com/
 
 #Requires PS -Version 3.0
 #Requires -Modules VeeamPSSnapIn    
 #>
[cmdletbinding()]
param(
    [Parameter(Position=0, Mandatory=$True)]
        [string]$BRHost,
    [Parameter(Position=1, Mandatory=$False)]
        [string] $reportMode = "24",
    [Parameter(Position=2, Mandatory=$False)]
        [Int] $repoCritical = 10,
    [Parameter(Position=2, Mandatory=$False)]
        [Int] $repoWarn = 20

)

# Big thanks to Shawn, creating a awsome Reporting Script:
# http://blog.smasterson.com/2016/02/16/veeam-v9-my-veeam-report-v9-0-1/

#region: Start Load VEEAM Snapin (if not already loaded)
if (!(Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue)) {
	if (!(Add-PSSnapin -PassThru VeeamPSSnapIn)) {
		# Error out if loading fails
		Write-Error "`nERROR: Cannot load the VEEAM Snapin."
		Exit
	}
}
#endregion

#region: Functions
Function Get-vPCRepoInfo {
[CmdletBinding()]
param (
        [Parameter(Position=0, ValueFromPipeline=$true)]
                [PSObject[]]$Repository
        )
Begin {
        $outputAry = @()
        Function Build-Object {param($name, $repohost, $path, $free, $total)
                $repoObj = New-Object -TypeName PSObject -Property @{
                                Target = $name
                                RepoHost = $repohost
                                Storepath = $path
                                StorageFree = [Math]::Round([Decimal]$free/1GB,2)
                                StorageTotal = [Math]::Round([Decimal]$total/1GB,2)
                                FreePercentage = [Math]::Round(($free/$total)*100)
                        }
                Return $repoObj | Select-Object Target, RepoHost, Storepath, StorageFree, StorageTotal, FreePercentage
        }
}
Process {
        Foreach ($r in $Repository) {
                # Refresh Repository Size Info
                [Veeam.Backup.Core.CBackupRepositoryEx]::SyncSpaceInfoToDb($r, $true)
                
                If ($r.HostId -eq "00000000-0000-0000-0000-000000000000") {
                        $HostName = ""
                        }
                Else {
                        $HostName = $($r.GetHost()).Name.ToLower()
                        }
                $outputObj = Build-Object $r.Name $Hostname $r.Path $r.info.CachedFreeSpace $r.Info.CachedTotalSpace
                }
        $outputAry += $outputObj
}
End {
        $outputAry
        }
}
#endregion

#region: Start BRHost Connection
Write-Output "Starting to Process Connection to $BRHost ..."
$OpenConnection = (Get-VBRServerSession).Server
if($OpenConnection -eq $BRHost) {
	Write-Output "BRHost is Already Connected..."
} elseif ($null -eq $OpenConnection) {
	Write-Output "Connecting BRHost..."
	Connect-VBRServer -Server $BRHost
} else {
    Write-Output "Disconnection actual BRHost..."
    Disconnect-VBRServer
    Write-Output "Connecting new BRHost..."
    Connect-VBRServer -Server $BRHost
}

$NewConnection = (Get-VBRServerSession).Server
if ($null -eq $NewConnection) {
	Write-Error "`nError: BRHost Connection Failed"
	Exit
}
#endregion

#region: Convert mode (timeframe) to hours
If ($reportMode -eq "Monthly") {
        [Int] $HourstoCheck = 720
} Elseif ($reportMode -eq "Weekly") {
        [Int] $HourstoCheck = 168
} Else {
        [Int] $HourstoCheck = $reportMode
}
#endregion

#region: Collect and filter Sessions
$repoList = Get-VBRBackupRepository     # Get all Repositories
$allSesh = Get-VBRBackupSession         # Get all Sessions (Backup/BackupCopy/Replica)
$seshListBk = @($allSesh | Where-Object {($_.CreationTime -ge (Get-Date).AddHours(-$HourstoCheck)) -and $_.JobType -eq "Backup"})           # Gather all Backup sessions within timeframe
$seshListBkc = @($allSesh | Where-Object {($_.CreationTime -ge (Get-Date).AddHours(-$HourstoCheck)) -and $_.JobType -eq "BackupSync"})      # Gather all BackupCopy sessions within timeframe
$seshListRepl = @($allSesh | Where-Object {($_.CreationTime -ge (Get-Date).AddHours(-$HourstoCheck)) -and $_.JobType -eq "Replica"})        # Gather all Replication sessions within timeframe
#endregion

#region: Get Backup session informations
$totalxferBk = 0
$totalReadBk = 0
$seshListBk | %{$totalxferBk += $([Math]::Round([Decimal]$_.Progress.TransferedSize/1GB, 0))}
$seshListBk | %{$totalReadBk += $([Math]::Round([Decimal]$_.Progress.ReadSize/1GB, 0))}
#endregion

#region: Preparing Backup Session Reports
$successSessionsBk = @($seshListBk | Where-Object {$_.Result -eq "Success"})
$warningSessionsBk = @($seshListBk | Where-Object {$_.Result -eq "Warning"})
$failsSessionsBk = @($seshListBk | Where-Object {$_.Result -eq "Failed"})
$runningSessionsBk = @($allSesh | Where-Object {$_.State -eq "Working" -and $_.JobType -eq "Backup"})
$failedSessionsBk = @($seshListBk | Where-Object {($_.Result -eq "Failed") -and ($_.WillBeRetried -ne "True")})
#endregion

#region:  Preparing Backup Copy Session Reports
$successSessionsBkC = @($seshListBkC | Where-Object {$_.Result -eq "Success"})
$warningSessionsBkC = @($seshListBkC | Where-Object {$_.Result -eq "Warning"})
$failsSessionsBkC = @($seshListBkC | Where-Object {$_.Result -eq "Failed"})
$runningSessionsBkC = @($allSesh | Where-Object {$_.State -eq "Working" -and $_.JobType -eq "BackupSync"})
$IdleSessionsBkC = @($allSesh | Where-Object {$_.State -eq "Idle" -and $_.JobType -eq "BackupSync"})
$failedSessionsBkC = @($seshListBkC | Where-Object{($_.Result -eq "Failed") -and ($_.WillBeRetried -ne "True")})
#endregion

#region Preparing Replicatiom Session Reports
$successSessionsRepl = @($seshListRepl | Where-Object {$_.Result -eq "Success"})
$warningSessionsRepl = @($seshListRepl | Where-Object {$_.Result -eq "Warning"})
$failsSessionsRepl = @($seshListRepl | Where-Object {$_.Result -eq "Failed"})
$runningSessionsRepl = @($allSesh | Where-Object {$_.State -eq "Working" -and $_.JobType -eq "Replica"})
$failedSessionsRepl = @($seshListRepl | Where-Object {($_.Result -eq "Failed") -and ($_.WillBeRetried -ne "True")})
#endregion

#region: Create Repository Report
$RepoReport = $repoList | Get-vPCRepoInfo | Select-Object   @{Name="Repository Name"; Expression = {$_.Target}},
                                                            @{Name="Host"; Expression = {$_.RepoHost}},
                                                            @{Name="Path"; Expression = {$_.Storepath}},
                                                            @{Name="Free (GB)"; Expression = {$_.StorageFree}},
                                                            @{Name="Total (GB)"; Expression = {$_.StorageTotal}},
                                                            @{Name="Free (%)"; Expression = {$_.FreePercentage}},
                                                             @{Name="Status"; Expression = {
                                                            If ($_.FreePercentage -lt $repoCritical) {"Critical"} 
                                                            ElseIf ($_.FreePercentage -lt $repoWarn) {"Warning"}
                                                            ElseIf ($_.FreePercentage -eq "Unknown") {"Unknown"}
                                                            Else {"OK"}}} | `
                                                            Sort-Object "Repository Name" 
#endregion

#region: Create Session Report
$SessionReport    = @()
$BackupSession  = [PSCustomObject] @{
	Type  = "Backup"
	Success = $successSessionsBk.Count
	Warning = $warningSessionsBk.Count
	Fails = $failsSessionsBk.Count
	Failed = $failedSessionsBk.Count
	Running = $runningSessionsBk.Count
	Idle = "-"
    "Transfer (GB)" = $totalxferBk
    "Read (GB)" = $totalReadBk

}
$SessionReport += $BackupSession

$CopySession  = [PSCustomObject] @{
	Type  = "BackupCopy"
	Success = $successSessionsBkC.Count
	Warning = $warningSessionsBkc.Count
	Fails = $failsSessionsBkc.Count
	Failed = $failedSessionsBkc.Count
	Running = $runningSessionsBkc.Count
	Idle = $IdleSessionsBkC.Count
    "Transfer (GB)" = "-"
    "Read (GB)" = "-"

}
$SessionReport += $CopySession

$ReplicaSession  = [PSCustomObject] @{
	Type  = "Replication"
	Success = $successSessionsRepl.Count
	Warning = $warningSessionsRepl.Count
	Fails = $failsSessionsRepl.Count
	Failed = $failedSessionsRepl.Count
	Running = $runningSessionsRepl.Count
	Idle = "-"
    "Transfer (GB)" = "-"
    "Read (GB)" = "-"

}
$SessionReport += $ReplicaSession
#endregion

$RepoReport | Format-Table * -AutoSize
$SessionReport | Format-Table * -AutoSize

#region: Output

