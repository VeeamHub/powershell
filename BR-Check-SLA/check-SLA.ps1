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
#   -excludeVMsFile = filename containing VMs to be excluded explicitly (textfile, one VM name per line, default = "exclude-VMs.txt")
#   -excludeJobs = jobs including this string in their 'description' field will be ignored
#   -excludeJobsFile = filename containing jobs to be excluded explicitly (textfile, one job name per line default = "exclude-Jobs.txt")
#   -verbose = write details about script steps to screen while executing (only for debugging, default off)
# 
# Backup windows start will be calculated as follows:
#   Day  = today minus parameter 'lookBackDays'
#   Time = time of day set in parameter 'backupWindowStart'
# Backup windo end will be calculated as follows:
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
# 2022.11.24 added option to explicitly ignore a listing of VMs provided in a separate textfile
# -----------------------------------------------

# vbrServer passed as parameter (script will ask for credentials if there is no credentials file!)
Param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$vbrServer,
    [Parameter(Mandatory = $false)]
    [int]$lookBackDays = 1,
    [Parameter(Mandatory = $false)]
    [string]$backupWindowStart = "20:00",
    [Parameter(Mandatory = $false)]
    [string]$backupWindowEnd = "07:00",
    [Parameter(Mandatory = $false)]
    [switch]$displayGrid = $false,
    [Parameter(Mandatory = $false)]
    [string]$outputDir = "",
    [Parameter(Mandatory = $false)]
    [string]$excludeVMs = "",
    [Parameter(Mandatory = $false)]
    [string]$excludeVMsFile = "exclude-VMs.txt",
    [Parameter(Mandatory = $false)]
    [string]$excludeJobs = "",
    [Parameter(Mandatory = $false)]
    [string]$excludeJobsFile = "exclude-Jobs.txt"
)
# -----------------------------------------------


Begin {
    #Import-Module Veeam.Backup.PowerShell
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
        "EndpointBackup",
        "EpAgentBackup",
        "EpAgentManagement",
        "EPAgentPolicy")

    $jobBlockSizes = [PSCustomobject]@{ kbBlockSize256 = 256 * 1024
        kbBlockSize512                                 = 512 * 1024
        kbBlockSize1024                                = 1024 * 1024
        kbBlockSize4096                                = 4096 * 1024
        kbBlockSize8192                                = 8192 * 1024
        Automatic                                      = "[Automatic]"
    }

    # build proper wildcards for exclusion filters
    if ("" -ne $excludeJobs) {
        $excludeJobs = "*$($excludeJobs.Trim('*'))*" 
        Write-Output "excluding jobs matching ""$excludeJobs"""
    }
    if ("" -ne $excludeVMs) {
        $excludeVMs = "*$($excludeVMs.Trim('*'))*" 
        Write-Output "excluding VMs matching  ""$excludeVMs"""
    }

    # read exclusion list files
    $excludeVMsList = @()
    if ("" -ne $excludeVMsFile) {
        try {
            $excludeVMsFile = (Get-Item -Path $excludeVMsFile -ErrorAction Stop).FullName
            Write-Verbose "reading VM exclusions file ""$excludeVMsFile"""
            $excludeVMsList = Get-Content -LiteralPath $excludeVMsFile -ErrorAction Stop
            Write-Output "excluding $($excludeVMsList.Count) VMs listed in ""$excludeVMsFile"""
        }
        catch {
            Write-Output -Message "!!! could not read from ""$excludeVMsFile"" !!!"
        }
        
    }
    $excludeJobsList = @()
    if ("" -ne $excludeJobsFile) {
        try {
            $excludeJobsFile = (Get-Item -Path $excludeJobsFile -ErrorAction Stop).FullName
            Write-Verbose "reading job exclusions file ""$excludeJobsFile"""
            $excludeJobsList = Get-Content -LiteralPath $excludeJobsFile -ErrorAction Stop
            Write-Output "excluding $($excludeJobsList.Count) Jobs listed in  ""$excludeJobsFile"""
        }
        catch {
            Write-Output -Message "!!! could not read from ""$excludeJobsFile"" !!!"
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
            if ($extent.Type -iin ('Nfs', `
                        'CifsShare', `
                        'SanSnapshotOnly', `
                        'DDBoost', `
                        'HPStoreOnceIntegration', `
                        'AmazonS3External', `
                        'AzureStorageExternal') ) {
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
        $outputDir = $outputDir.TrimEnd("\")
    }
    # credential file for this server
    $credFile = "$PSScriptRoot\$vbrServer-creds.xml"
    # output file of restore points
    $outfileRP = "$outputDir\$outfilePrefix-SLA-RPs.csv"
    #output file for statistics
    $outfileStatistics = "$outputDir\SLA-Summary-$vbrServer.csv"

    Write-Progress -Activity "Connecting to $vbrServer" -Id 1

    # read credentials for vbr server authentication if file exists, otherwise ask for credentials and save them
    Disconnect-VBRServer -ErrorAction SilentlyContinue
    try {
        $myCreds = Import-Clixml -path $credFile
        Write-Verbose "Credentials read from ""$credFile."""
    }
    catch {
        Write-Verbose """$credFile"" not found, asking for credentials interactively."
        $myCreds = Get-Credential -Message "Credentials for $vbrServer"
        if ($null -ne $myCreds) {
            $myCreds | Export-CliXml -Path $credFile | Out-Null
            Write-Verbose "Credentials written to ""$credFile."""
        }
        else {
            Write-Verbose "No Credentials, aborting."
            return
        }
    }

    # establish connection to vbr server
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
    $allRPs = New-Object -TypeName 'System.Collections.Generic.List[object]'
    $VMJobList = New-Object -TypeName 'System.Collections.Generic.List[string]'
    $countJobs = 0
    $rpId = 0
    $totalRPs = 0
    $totalRPsInBackupWindow = 0

    Write-Progress -Activity $vbrServer -Id 1

    # iterate through backup jobs
    foreach ($objBackup in $allBackups) {
        Write-Verbose "Working on job: $($objBackup.JobName)"
        
        
        $countJobs++
        Write-Progress -Activity "Iterating through backup jobs" -CurrentOperation "$($objBackup.JobName)" -PercentComplete ($countJobs / $allBackups.Count * 100) -Id 2 -ParentId 1

        # get backup job object for this backup object
        if ($objBackup.JobType -eq "Backup") {
            $thisJob = Get-VBRJob -Name $objBackup.JobName
        }
        else {
            $thisJob = Get-VBRComputerBackupJob -Name $objBackup.JobName
        }

        # check exclusion of this job
        $processThisJob = $true
        # ignore jobs explicitly excluded via $excludeJobsFile
        if ($excludeJobsList.Count -gt 0) {
            if ($excludeJobsList.Contains($objBackup.JobName)) {
                $processThisJob = $false
            }
        }
        # ignore jobs that have a match to $excludeJobs in their description
        if ($processThisJob -and ("" -ne $excludeJobs) ) {
            if ( $thisJob.Description -like $excludeJobs ) {
                $processThisJob = $false
            }
        }

        if ($processThisJob) {
            try {
                $objThisRepo = $null
                $objThisRepo = $objBackup.GetRepository()
            }
            catch {
            }
            $objRPs = $null
            try {
                # get most recent restore point of current job
                if ("" -eq $excludeVMs) {
                    $objRPs = Get-VBRRestorePoint -Backup $objBackup | Sort-Object -Property @{Expression = 'CreationTime'; Descending = $true }, VMName
                }
                else {
                    $objRPs = Get-VBRRestorePoint -Backup $objBackup | `
                        Where-Object { $_.VMName -notlike $excludeVMs } | `
                        Sort-Object -Property @{Expression = 'CreationTime'; Descending = $true }, VMName
                }
            }
            catch {
            }

            $countRPs = 0
            $excludeVMsCount = $excludeVMsList.Count
            # iterate through all discovered restore points
            foreach ($restorePoint in $objRPs) {            
                Write-Progress -Activity "Getting restore points" -PercentComplete ($countRPs / $objRPs.Count * 100) -Id 3 -ParentId 2
                $myBackupJob = $null

                # ignore restore point if VM is listed in the exclusion list file
                $processThisVM = $true
                if($excludeVMsCount -gt 0) {
                    if ($excludeVMsList.Contains($restorePoint.VmName)) {
                        $processThisVM = $false
                    }
                }
                if($processThisVM) {
                    # check valid completion time, otherwise ignore this (corrupt) restore point 
                    $completionTime = $restorePoint.CompletionTimeUTC
                    if ($null -ne $completionTime) {
                        $completionTime = $completionTime.ToLocalTime()
                    
                        # ignore restore points which are newer than the backup window end time
                        if ($completionTime -le $intervalEnd) {

                            # only proceed if we do NOT already have a restore point for this VM from this job
                            if ("$($restorePoint.VmName)-$($objBackup.Name)" -notin $VMJobList) {
                                
                                $rpDuration = New-TimeSpan -Start $restorePoint.CreationTimeUtc -End $restorePoint.CompletionTimeUTC
                                
                                try {
                                    $myBackupJob = $objBackup.GetJob()
                                }
                                catch {
                                    # ignore error
                                }
                                if ($null -eq $myBackupJob ) {
                                    $myBlockSize = "[n/a]"
                                }
                                else {
                                    $myBlocksize = $jobBlockSizes."$($restorePoint.GetStorage().Blocksize)"
                                }

                                $myBackupType = $restorePoint.algorithm
                                if ($myBackupType -eq "Increment") {
                                    $myDataRead = $restorePoint.GetStorage().stats.DataSize
                                }
                                else {
                                    $myDataRead = $restorePoint.ApproxSize
                                }
                                $myDedup = $restorePoint.GetStorage().stats.DedupRatio
                                $myCompr = $restorePoint.GetStorage().stats.CompressRatio
                                if ($myDedup -gt 1) { $myDedup = 100 / $myDedup } else { $myDedup = 1 }
                                if ($myCompr -gt 1) { $myCompr = 100 / $myCompr } else { $myCompr = 1 }

                                $myRepoName = $null
                                $extentName = $null
                                if ($null -ne $objThisRepo) {
                                    $myRepoName = $objThisRepo.Name
                                    if ($objThisRepo.TypeDisplay -eq "Scale-out") {
                                        $extentName = $restorePoint.FindChainRepositories().Name
                                    }
                                }
                                # check if rp is within backup window
                                $rpInBackupWindow = $false
                                if (($completionTime -ge $intervalStart) -and ($completionTime -le $intervalEnd)) {
                                    $rpInBackupWindow = $true
                                    $totalRPsInBackupWindow++
                                }

                                $countRPs++
                                $tmpObject = [PSCustomobject]@{
                                    RpId           = ++$rpID # will be set later!
                                    VMName         = $restorePoint.VmName
                                    BackupJob      = $objBackup.Name
                                    JobDescription = $thisJob.Description
                                    Repository     = $myRepoName
                                    Extent         = $extentName
                                    RepoType       = $restorePoint.FindChainRepositories().Type
                                    CreationTime   = $restorePoint.CreationTimeUTC.ToLocalTime()
                                    CompletionTime = $completionTime
                                    InBackupWindow = $rpInBackupWindow
                                    Duration       = $rpDuration
                                    BackupType     = $restorePoint.algorithm
                                    ProcessedData  = $restorePoint.ApproxSize
                                    DataSize       = $restorePoint.GetStorage().stats.DataSize
                                    DataRead       = $myDataRead
                                    BackupSize     = $restorePoint.GetStorage().stats.BackupSize
                                    DedupRatio     = $myDedup
                                    ComprRatio     = $myCompr
                                    Reduction      = $myDedup * $myCompr
                                    Blocksize      = $myBlocksize
                                    Folder         = get_backupfile_path $restorePoint
                                    Filename       = $restorePoint.GetStorage().PartialPath.Internal.Elements[0]
                                }

                                $totalRPs++
                                $allRPs.Add($tmpObject) | Out-Null
                                $VMJobList.Add("$($restorePoint.VmName)-$($objBackup.Name)")
                                $tmpObject = $null
                            }
                        }
                    }
                }
            }
        }
    }
    Write-Verbose "Disconnecting from backup server $vbrServer."
    Disconnect-VBRServer -ErrorAction SilentlyContinue
    
    Write-Progress -Activity "Getting restore points" -Id 3 -ParentId 2 -Completed
    Write-Progress -Activity "Iterating through backup jobs" -Id 2 -Completed

    Write-Progress -Activity "Calculating and preparing output..." -Id 2 -ParentId 1
    Write-Verbose "Calculating and preparing output."

    # sort restore points for processing
    $allRPs = $allRPs | Sort-Object -Property VMName, BackupJob, @{Expression = 'CreationTime'; Descending = $true }

    # ...and re-number sorted list
    $rpID = 0
    foreach ($rp in $allRPs) { $rp.RpId = ++$rpID }

    # create SLA output object
    $SLACompliance = 0
    if ($allRPs.Count -gt 0) {
        $SLACompliance = [math]::Round($totalRPsInBackupWindow / $allRPs.Count * 100, 2)
    }
    $procDuration = formatDuration(New-TimeSpan -Start $procStartTime)
    $SLAObject = [PSCustomobject]@{
        SLACheckTime         = $now
        SLACheckDuration     = $procDuration
        BackupWindowStart    = $intervalStart
        BackupWindowEnd      = $intervalEnd
        ExcludedJobsFilter   = $excludeJobs
        ExcludedVMsFilter    = $excludeVMs
        TotalRestorePoints   = $allRPs.Count
        RPsInBackupWindow    = $totalRPsInBackupWindow
        SLACompliancePercent = $SLACompliance
    }

    # output everything
    # -----------------
    if ($allRPs.Count -gt 0) {

        $allRPs | Export-Csv -Path $outfileRP -NoTypeInformation -Delimiter ';'
        Write-Verbose "output to file: $outfileRP"

        $SLAObject | Export-Csv -Path $outfileStatistics -NoTypeInformation -Delimiter ';' -Append
        Write-Verbose "output to file: $outfileStatistics"

        if ($displayGrid) {
            # prepare 'human readable' figures for GridViews
            Write-Verbose "Preparing GridViews."
            foreach ($rp in $allRPs) {
                $rp.ProcessedData = Format-Bytes $rp.ProcessedData
                $rp.DataSize = Format-Bytes $rp.DataSize
                $rp.DataRead = Format-Bytes $rp.DataRead
                $rp.BackupSize = Format-Bytes $rp.BackupSize
                if ($rp.Blocksize -gt 0) { $rp.BlockSize = Format-Bytes $rp.BlockSize }
                $rp.Duration = formatDuration($rp.Duration)
            }

            # output GridViews
            Write-Verbose "GridView display."
            $allRPs | Out-GridView -Title "List of most recent restore points ($outFileRP)" -Verbose 
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
