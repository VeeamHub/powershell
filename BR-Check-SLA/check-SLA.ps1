# check-SLA.ps1
#
# This script will read all the most recent restore points from all backup jobs of a single or multiple VBR servers.
# SLA fulfillment ratio (in percent) is calculated based on which percentage of the restore points have been created
# within the given backup window in comparison to the total number of restore points.
#
# Note: If a VM within a particular job has NEVER been backed up successfully (i.e., no restore points exist for
#       this VM at all), or if a job didn't run at least successfully once, this script will not be able report these
#       as being 'outside of backup window' as it simply cannot process something that doesn't exist.
#
# Note: If a restore point is newer than the backup window end time, it will be ignored and the next (older) restore
#       point will be checked for backup window compliance instead.
#
# Requires module 'Veeam.Backup.PowerShell'
#
# Parameters:
#   -vbrServer [server] = Veeam backup server name or IP to connect to (can be a pipelined value to process multiple VBR servers)
#   -lookBackDays = how many days should the script look back for the backup window start? (default can be changed in Param()-section)
#   -backupWindowStart = at which time of day starts the backup window? (string in 24h format, default can be changed in Param()-section)
#   -backupWindowEnd = at which time of day ends the backup window? (string in 24h format, default can be changed in Param()-section)
#   -displayGrid = switch to display results in PS-GridViews (default = $false)
#   -outputDir = where to write the output files (folder must exist, otherwise defaulting to script folder)
#   -excludeVMs = VMs or computers that have this string as part of their name will be ignored
#   -excludeVMsFile = filename containing VMs and optional VM-IDs to be excluded explicitly (textfile, one VM name or VM Name + ID per line, default = "exclude-VMs.txt")
#   -separatorChar = character to separate VM Names from VM-IDs in exclusion file (default = "," (comma))
#   -excludeJobs = jobs including this string in their 'description' field will be ignored
#   -excludeJobsFile = filename containing jobs to be excluded explicitly (textfile, one job name per line default = "exclude-Jobs.txt")
#   -verbose = write details about script steps to screen while executing (only for debugging, default off)
# 
# Backup window start will be calculated as follows:
#   Day  = today minus parameter 'lookBackDays'
#   Time = time of day set in parameter 'backupWindowStart'
# Backup window end will be calculated as follows:
#   Day  = yesterday, if time in 'backupWindowEnd' is in the future; otherwise today
#   Time = time of day set in parameter 'backupWindowEnd'
# 
# Two output files will be created in the output folder:
#   1. CSV file containing most recent restore points with some details and whether they comply to backup window
#      (new file for each script run, file name prefixed with date/time)
#   2. CSV file containing summary of SLA compliance
#      (appending to this file for each script run)
#
# 2022.06.16 by M. Mehrtens
# 2022.11.24 added option to explicitly ignore VMs or jobs provided in separate textfiles
# 2022.11.25 enhanced explicit VM exclusions to be based on combination of VM name and VM-ID (vSphere MoRefID)
# 2023-08-07 added support for VBR v12 job type "PerVMParentBackup" (new backup chain format of v12)
# 2023.11.10 fixed a bug which lead to restore points being ignored when a job was changed to target a different repository
# 2024.01.22 replaced usage of obsolete method 'GetTargetVmInfo()' with property 'AuxData' to determine vSphere VM-IDs (this might NOT work with VBR versions prior to 12.1)
# 2025.12.29 fixed a bug related to exclusion processing of VM-IDs ("MoRef-IDs") in the excludeVMsFile
# 2025.12.29 optimized restore point processing (cache expensive calls, hashtable lookups for exclusions, on-the-fly dedupe)
# 2026.08.07 fixed a console output bug that falsely indicated that processing started although it didn't
# 2026.10.13 added support for running on Linux (tested on Rocky 9.8)
#            Veeam Powershell Module required, see https://helpcenter.veeam.com/docs/vbr/powershell/running_ps_sessions_linux.html#configuring-veeam-backup-powershell-on-linux-machines
# -----------------------------------------------

# vbrServer passed as parameter (script will ask for credentials if there is no credentials file!)
Param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$vbrServer,
    [Parameter(Mandatory = $false)]
    [int]$lookBackDays = 1,
    [Parameter(Mandatory = $false)]
    [string]$backupWindowStart = "19:00",
    [Parameter(Mandatory = $false)]
    [string]$backupWindowEnd = "06:00",
    [Parameter(Mandatory = $false)]
    [switch]$displayGrid = $false,
    [Parameter(Mandatory = $false)]
    [string]$outputDir = "",
    [Parameter(Mandatory = $false)]
    [string]$excludeVMs = "",
    [Parameter(Mandatory = $false)]
    [string]$excludeVMsFile = "exclude-VMs.txt",
    [string]$separatorChar = ',',
    [Parameter(Mandatory = $false)]
    [string]$excludeJobs = "temp",
    [Parameter(Mandatory = $false)]
    [string]$excludeJobsFile = "exclude-Jobs.txt"
)
# -----------------------------------------------


Begin {

    # check for Linux/Windows platform
    if($PSVersionTable.Platform -eq "Unix") {
        try {
            Import-Module "/opt/veeam/powershell/Veeam.Backup.PowerShell/Veeam.Backup.PowerShell.psd1" -ErrorAction Stop
        } catch {
            write-output "ERROR: Veeam Powershell Module not found."
            break
        }
        if($displayGrid) {
            write-output "(ignoring '-displayGrid' parameter as this is not suported on Linux)"
            $displayGrid = $false
        }
    } elseif($PSVersionTable.Platform -eq "Win32NT") {
        #Import-Module Veeam.Backup.PowerShell
    } else {
        write-output "ERROR: This script only runs on Powershell Core on Windows or Linux."
        break
    }
    
    # calculate backup window start and stop times from parameters
    $now = Get-Date
    $intervalStart = [Datetime]("$($now.Year)" + "." + `
            "$($now.Month)" + "." + `
            "$($now.Day)" + " " + `
            "$backupWindowStart")
    $intervalEnd = [Datetime]("$($now.Year)" + "." + `
            "$($now.Month)" + "." + `
            "$($now.Day)" + " " + `
            "$backupWindowEnd")
    
    # subtract $lookBackDays from backup window start time
    $intervalStart = $intervalStart.AddDays(- $lookBackDays)

    # if backup window end time lies in future, use end time of yesterday
    if ($intervalEnd -gt $now) {
        $intervalEnd = $intervalEnd.AddDays(-1)
    }

    Write-Output "Backup window"
    Write-Output "  start: $intervalStart"
    Write-Output "    end: $intervalEnd"
    Write-Output ""


    $jobTypesScope = @("Backup",
        "PerVMParentBackup",
        "EndpointBackup",
        "EpAgentBackup",
        "EpAgentManagement",
        "EPAgentPolicy")

    $vmJobTypesScope = @("Backup",
        "PerVMParentBackup")

    $agentJobTypesScope = @("EndpointBackup",
        "EpAgentBackup",
        "EpAgentManagement",
        "EPAgentPolicy")

    $extentTypesWithFriendlyPath = @('Nfs',
                                     'CifsShare',
                                     'SanSnapshotOnly',
                                     'DDBoost',
                                     'HPStoreOnceIntegration',
                                     'AmazonS3External',
                                     'AzureStorageExternal')

    # build proper wildcards for exclusion filters
    if ("" -ne $excludeJobs) {
        $excludeJobs = "*{0}*" -f $excludeJobs.Trim('*')
        Write-Output "excluding jobs matching ""$excludeJobs"""
    }
    if ("" -ne $excludeVMs) {
        $excludeVMs = "*{0}*" -f $excludeVMs.Trim('*')
        Write-Output "excluding VMs matching ""$excludeVMs"""
    }

    # read exclusion list files
    
    # exclusion of VM names
    $excludeVMsList = New-Object -TypeName 'System.Collections.Generic.List[PSCustomObject]'
    if ("" -ne $excludeVMsFile) {
        try {
            $excludeVMsFile = (Get-Item -Path $excludeVMsFile -ErrorAction Stop).FullName
            Write-Verbose "reading VM exclusions file ""$excludeVMsFile"""
            $excludeVMsFileContent = Get-Content -LiteralPath $excludeVMsFile -ErrorAction Stop
        }
        catch {
            Write-Output "!!! error reading from ""$excludeVMsFile"" !!!"
        }
        if ($excludeVMsFileContent.Count -gt 0) {
            Write-Output "excluding $($excludeVMsFileContent.Count) VM entries listed in ""$excludeVMsFile"""
            foreach ($line in $excludeVMsFileContent) {
                $entry = $null
                if ($line.Length -gt 0) {
                    $entry = $line.Split($separatorChar)
                    if ($entry.Length -gt 1) {
                        $tmpObject = [PSCustomobject]@{
                            Name = $entry[0].Trim()
                            ID   = $entry[1].Trim()
                        }
                    }
                    else {
                        $tmpObject = [PSCustomobject]@{
                            Name = $entry[0].Trim()
                            ID   = $null
                        }
                    }
                    $null = $excludeVMsList.Add($tmpObject)
                    $tmpObject = $null
                }
            }
        }
    }

    # Build a hashtable for fast exclusion lookup (VMName -> ID or $null meaning exclude by name only)
    $excludeVMsDict = @{}
    foreach ($e in $excludeVMsList) {
        if (-not [string]::IsNullOrWhiteSpace($e.Name)) {
            $name = $e.Name.Trim()
            $id = if ($e.ID) { $e.ID.Trim() } else { $null }
            if (-not $excludeVMsDict.ContainsKey($name)) {
                $excludeVMsDict[$name] = $id
            }
        }
    }

    # exclusion of backup job names
    $excludeJobsList = @()
    if ("" -ne $excludeJobsFile) {
        try {
            $excludeJobsFile = (Get-Item -Path $excludeJobsFile -ErrorAction Stop).FullName
            Write-Verbose "reading job exclusions file ""$excludeJobsFile"""
            $excludeJobsList = Get-Content -LiteralPath $excludeJobsFile -ErrorAction Stop
            Write-Output "excluding $($excludeJobsList.Count) Jobs listed in  ""$excludeJobsFile"""
        }
        catch {
            Write-Output "!!! error reading from ""$excludeJobsFile"" !!!"
        }
        
    }

    # Build a hashtable for job exclusions for O(1) checks
    $excludeJobsSet = @{}
    foreach ($j in $excludeJobsList) {
        if (-not [string]::IsNullOrWhiteSpace($j)) {
            $excludeJobsSet[$j.Trim()] = $true
        }
    }

    # helper function to format numbers as MB/GB/TB/etc.
    Function Format-Bytes {
        Param
        (
            [Parameter(
                ValueFromPipeline = $true
            )]
            [ValidateNotNullOrEmpty()]
            [float]$number
        )
        Begin {
            $sizes = 'kB', 'MB', 'GB', 'TB', 'PB'
        }
        Process {
            # New for loop
            for ($x = 0; $x -lt $sizes.count; $x++) {
                if ($number -lt "1$($sizes[$x])") {
                    if ($x -eq 0) {
                        return "$number B"
                    }
                    else {
                        $num = $number / "1$($sizes[$x-1])"
                        $num = "{0:N2}" -f $num
                        return "$num $($sizes[$x-1])"
                    }
                }
            }

        }
        End {}
    }

    # function to retrieve path of repository
    function get_backupfile_path($objRP) {

        $retval = $null
        $extent = $objRP.FindChainRepositories()

        if ($extent) {
            if ($extent.Type -iin $extentTypesWithFriendlyPath) {
                $retval = "$($extent.FriendlyPath)"
            }
            else {
                $retval = "$($extent.Host.Name):$($extent.FriendlyPath)"
            }
        }
        return $retval
    }

    # function to format duration for grid output
    function formatDuration($timeSpan) {
     
        if ($timespan.Days -gt 0) {
            $timespan.ToString("dd\.hh\:mm\:ss")
        }
        else {
            $timespan.ToString("hh\:mm\:ss")
        }
    
    }

}

Process {
    $Error.Clear()
    $procStartTime = Get-Date
    $procDuration = ""
    "Backup Server: $vbrServer"
    # output files path/name prefix
    $outfilePrefix = "$($now.ToString("yyyy-MM-ddTHH-mm-ss"))-$($vbrServer)"
    

    # -----------------------------------------------
    if ($outputDir -eq "") {
        $outputDir = $PSScriptRoot
    }
    elseif (-not (Test-Path -PathType Container $outputDir)) {
        $outputDir = $PSScriptRoot
    }
    else {
        $outputDir = $outputDir.TrimEnd("\\")
    }
    # credential file for this server
    $credFile = "$PSScriptRoot\$vbrServer-creds.xml"
    # output file of restore points
    $outfileRP = "$outputDir\$outfilePrefix-SLA-RPs.csv"
    #output file for statistics
    $outfileStatistics = "$outputDir\SLA-Summary-$vbrServer.csv"

    # read credentials for vbr server authentication if file exists, otherwise ask for credentials and save them
    Disconnect-VBRServer -ErrorAction SilentlyContinue
    $myCreds = $null
    try {
        $myCreds = Import-Clixml -path $credFile
        Write-Verbose "Credentials read from ""$credFile."""
    }
    catch {
        Write-Verbose """$credFile"" not found, asking for credentials interactively."
        $myCreds = $null
        $myCreds = Get-Credential -Title "Authentication" -Message "Please enter credentials for $vbrServer" -Debug
        if ($myCreds) {
            $myCreds | Export-CliXml -Path $credFile
            Write-Verbose "Credentials written to ""$credFile."""
        }
        else {
            Write-Verbose "No Credentials, aborting."
            return
        }
    }

    # establish connection to vbr server
    Write-Progress -Activity "Connecting to $vbrServer" -Id 1
    try {
        Connect-VBRServer -Server $vbrServer -Credential $myCreds
        Write-Verbose "Connection to $vbrServer successful."
    }
    catch {
        Write-Error $Error[0]
        # we can't do anything if this connection fails
        return
    }

    Write-Progress -Activity "Getting all backup jobs from $vbrServer" -Id 1

    # get all backup jobs
    Write-Verbose "Getting all backup jobs."
    $allBackups = Get-VBRBackup | Where-Object { $_.JobType -in $jobTypesScope }

    # Use an on-the-fly dedupe dictionary: key = VMName, value = PSCustomObject for the most recent RP
    $mostRecentByVM = @{}

    # keep counts
    $countJobs = 0
    $totalRPs = 0
    $totalRPsInBackupWindow = 0

    Write-Progress -Activity $vbrServer -Id 1

    # iterate through backup jobs
    foreach ($objBackup in $allBackups) {
        Write-Verbose "Working on job: $($objBackup.JobName)"
        
        $countJobs++
        $allBackupsCount = $allBackups.Count
        if ($allBackupsCount -gt 0) {
            Write-Progress -Activity "Iterating through backup jobs" -CurrentOperation "$($objBackup.JobName)" -PercentComplete ($countJobs / $allBackupsCount * 100) -Id 2 -ParentId 1
        }

        # get backup job object for this backup object
        if ($vmJobTypesScope -icontains $objBackup.JobType) {
            $thisJob = Get-VBRJob -Name $objBackup.JobName
        }
        elseif ($agentJobTypesScope -icontains $objBackup.JobType) {
            $thisJob = Get-VBRComputerBackupJob -Name $objBackup.JobName -ErrorAction SilentlyContinue
        }

        # check exclusion of this job
        $processThisJob = $true
        # ignore jobs explicitly excluded via $excludeJobsFile
        if ($excludeJobsList.Count -gt 0) {
            if ($excludeJobsSet.ContainsKey($objBackup.JobName)) {
                $processThisJob = $false
            }
        }
        # ignore jobs that have a match to $excludeJobs in their description
        if ($processThisJob -and ("" -ne $excludeJobs) ) {
            if ( $thisJob -and $thisJob.Description -like $excludeJobs ) {
                $processThisJob = $false
            }
        }

        if ($processThisJob) {
            try {
                # get repository information
                $myRepoName = $null
                $extentName = $null
                $objThisRepo = $null
                $objThisRepo = $objBackup.GetRepository()
                if ($null -ne $objThisRepo) {
                    $myRepoName = $objThisRepo.Name
                    # fix: don't reference $restorePoint here (it doesn't exist yet). For scale-out, use repository name or leave blank.
                    if ($objThisRepo.TypeDisplay -eq "Scale-out") {
                        $extentName = $objThisRepo.Name
                    }
                }
                Write-Verbose "--> $myRepoName"
            }
            catch {
            }

            # get most recent restore points for current job (they are returned newest first by sorting by CreationTime)
            try {
                if ("" -eq $excludeVMs) {
                    $objRPs = Get-VBRRestorePoint -Backup $objBackup | Sort-Object -Property @{Expression = 'CreationTime'; Descending = $true }, VMName
                }
                else {
                    $objRPs = Get-VBRRestorePoint -Backup $objBackup | Where-Object { $_.VMName -notlike $excludeVMs } | Sort-Object -Property @{Expression = 'CreationTime'; Descending = $true }, VMName
                }
            }
            catch {
                $objRPs = $null
            }

            # iterate through all discovered restore points, but dedupe on-the-fly keeping only the most recent RP per VM
            if ($objRPs) {
                $countRPs = 0
                $objRPsCount = $objRPs.Count
                foreach ($restorePoint in $objRPs) {
                    $countRPs++
                    # reduce Write-Progress frequency to avoid high overhead
                    if ($countRPs % 50 -eq 0) { Write-Progress -Activity "Getting restore points" -PercentComplete ($countRPs / $objRPsCount * 100) -Id 3 -ParentId 2 }

                    # cache frequently used properties and expensive method results
                    $myName = $restorePoint.VmName
                    $moRefID = $restorePoint.AuxData.VmRef

                    # ignore if no completion time
                    $completionTimeUtc = $restorePoint.CompletionTimeUTC
                    if ($null -eq $completionTimeUtc) { continue }
                    $completionTime = $completionTimeUtc.ToLocalTime()

                    # ignore restore points which are newer than the backup window end time
                    if ($completionTime -gt $intervalEnd) { continue }

                    # exclusion by VM name/id using O(1) lookup
                    $skipThisVM = $false
                    if ($excludeVMsDict.Count -gt 0) {
                        if ($excludeVMsDict.ContainsKey($myName)) {
                            $excludeID = $excludeVMsDict[$myName]
                            if (($null -eq $excludeID) -or ($excludeID -eq $moRefID)) {
                                $skipThisVM = $true
                            }
                        }
                    }
                    if ($skipThisVM) { continue }

                    # optional job exclusion by exact job name (fast) already handled, but keep check in case
                    if ($excludeJobsSet.ContainsKey($objBackup.JobName)) { continue }

                    # only proceed if this is the most recent restore point we've seen for this VM so far
                    if ($mostRecentByVM.ContainsKey($myName)) {
                        $existing = $mostRecentByVM[$myName]
                        if ($existing.CompletionTime -ge $completionTime) {
                            continue    # we already have a newer or equal rp for this VM
                        }
                        else {
                            # current rp is newer -> we'll replace. adjust counters accordingly
                            if ($existing.InBackupWindow) { $totalRPsInBackupWindow-- }
                            $totalRPs--
                        }
                    }

                    # cache storage/stats/chain calls once
                    $storage = $restorePoint.GetStorage()
                    $stats = $storage.stats
                    $chain = $restorePoint.FindChainRepositories()

                    $rpDuration = New-TimeSpan -Start $restorePoint.CreationTimeUtc -End $completionTimeUtc

                    $myBackupType = $restorePoint.algorithm
                    if ($myBackupType -eq "Increment") {
                        $myDataRead = $stats.DataSize
                    }
                    else {
                        $myDataRead = $restorePoint.ApproxSize
                    }
                    $myDedup = $stats.DedupRatio
                    $myCompr = $stats.CompressRatio
                    if ($myDedup -gt 1) { $myDedup = 100 / $myDedup } else { $myDedup = 1 }
                    if ($myCompr -gt 1) { $myCompr = 100 / $myCompr } else { $myCompr = 1 }

                    # check if rp is within backup window
                    $rpInBackupWindow = $false
                    if (($completionTime -ge $intervalStart) -and ($completionTime -le $intervalEnd)) {
                        $rpInBackupWindow = $true
                    }

                    # build the lightweight result object
                    $tmpObject = [PSCustomobject]@{
                        RpId           = 0 # will be set later
                        VMName         = $myName
                        VMID           = $moRefID
                        BackupJob      = $objBackup.Name
                        JobType        = $objBackup.JobType
                        JobDescription = if ($thisJob) { $thisJob.Description } else { $null }
                        Repository     = $myRepoName
                        Extent         = $extentName
                        RepoType       = if ($chain) { $chain.Type } else { $null }
                        CreationTime   = $restorePoint.CreationTimeUTC.ToLocalTime()
                        CompletionTime = $completionTime
                        InBackupWindow = $rpInBackupWindow
                        Duration       = $rpDuration
                        BackupType     = $myBackupType
                        ProcessedData  = $restorePoint.ApproxSize
                        DataSize       = $stats.DataSize
                        DataRead       = $myDataRead
                        BackupSize     = $stats.BackupSize
                        DedupRatio     = $myDedup
                        ComprRatio     = $myCompr
                        Reduction      = $myDedup * $myCompr
                        Folder         = if ($chain) { if ($chain.Type -in $extentTypesWithFriendlyPath) { $chain.FriendlyPath } else { "$($chain.Host.Name):$($chain.FriendlyPath)" } } else { $null }
                        Filename       = $storage.PartialPath.Internal.Elements[0]
                    }

                    # store/replace entry for this VM
                    $mostRecentByVM[$myName] = $tmpObject

                    # update counters
                    $totalRPs++
                    if ($rpInBackupWindow) { $totalRPsInBackupWindow++ }
                }
                Write-Progress -Activity "Getting restore points" -Id 3 -ParentId 2 -Completed
            }
        }
    }
    Write-Verbose "Disconnecting from backup server $vbrServer."
    Disconnect-VBRServer -ErrorAction SilentlyContinue
    
    Write-Progress -Activity "Iterating through backup jobs" -Id 2 -Completed

    Write-Progress -Activity "Calculating and preparing output..." -Id 2 -ParentId 1
    Write-Verbose "Calculating and preparing output."

    # collect results
    $allResultingRPs = @()
    if ($mostRecentByVM.Count -gt 0) {
        $allResultingRPs = $mostRecentByVM.GetEnumerator() | ForEach-Object { $_.Value } | Sort-Object -Property VMName
    }

    # re-number sorted list
    $restorePointID = 1
    foreach ($rp in $allResultingRPs) { $rp.RpId = $restorePointID++ }

    # create SLA output object
    $SLACompliance = 0
    if ($allResultingRPs.Count -gt 0) {
        $SLACompliance = [math]::Round($totalRPsInBackupWindow / $allResultingRPs.Count * 100, 2)
    }
    $procDuration = formatDuration(New-TimeSpan -Start $procStartTime)
    $SLAObject = [PSCustomobject]@{
        SLACheckTime         = $now
        SLACheckDuration     = $procDuration
        BackupWindowStart    = $intervalStart
        BackupWindowEnd      = $intervalEnd
        ExcludedJobsFilter   = $excludeJobs
        ExcludedVMsFilter    = $excludeVMs
        TotalRestorePoints   = $allResultingRPs.Count
        RPsInBackupWindow    = $totalRPsInBackupWindow
        SLACompliancePercent = $SLACompliance
    }

    # output everything
    # -----------------
    if ($allResultingRPs.Count -gt 0) {

        $allResultingRPs | Export-Csv -Path $outfileRP -NoTypeInformation -Delimiter ';'
        Write-Verbose "output to file: $outfileRP"

        $SLAObject | Export-Csv -Path $outfileStatistics -NoTypeInformation -Delimiter ';' -Append
        Write-Verbose "output to file: $outfileStatistics"

        if ($displayGrid) {
            # prepare 'human readable' figures for GridViews
            Write-Verbose "Preparing GridViews."
            foreach ($rp in $allResultingRPs) {
                $rp.ProcessedData = Format-Bytes $rp.ProcessedData
                $rp.DataSize = Format-Bytes $rp.DataSize
                $rp.DataRead = Format-Bytes $rp.DataRead
                $rp.BackupSize = Format-Bytes $rp.BackupSize
                if ($rp.Blocksize -gt 0) { $rp.BlockSize = Format-Bytes $rp.BlockSize }
                $rp.Duration = formatDuration($rp.Duration)
            }

            # output GridViews
            Write-Verbose "GridView display."
            $allResultingRPs | Out-GridView -Title "List of most recent restore points ($outFileRP)" -Verbose 
            Import-Csv -Path $outfileStatistics -Delimiter ";" | Out-GridView -Title "SLA compliance overview ($outFileStatistics)" -Verbose 
        }
    }
    Write-Progress -Activity "Calculating and preparing output..." -Id 2 -Completed
    Write-Progress -Activity $vbrServer -Id 1 -Completed
    Write-Output ""
    Write-Output "Results from VBR Server ""$vbrServer"" (processing time: $procDuration)"
    Write-Output "     Most recent restore points: $totalRPs"
    Write-Output "Restore points in backup window: $totalRPsInBackupWindow"
    Write-Output "                 SLA compliance: $SLACompliance%"

    Write-Verbose "Finished processing backup server $vbrServer."
} 
