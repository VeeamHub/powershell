# get-rpstatistics.ps1
#
# Parameters:
#   -vbrServer [server] = Veeam backup server name or IP to connect to
#   -suppressGridDisplay = do not show GridViews after processing
#   -ouputDir [folder-path] = where to create output files (folder must exist, defaulting to script folder otherwise)
# 
# This script enumerates all existing restore points and
# creates 2 output files with following content 
#   - [VBR-Servername]-RestorePoints.csv:
#       a list of all restore points incl. type of backup,
#       backup file size, creation time, compression and dedupe ratios,
#       change rates (for incremental restore points only) and
#       a few blocksize calculations (for object storage sizing assistance)
#   - [VBR-Servername]-statistics.csv:
#       average change and reduction rates per vm and job
#       (separated for full and incremental restore points)
#
# the contents of these files will also be displayed interactively via GridView
# (if not suppressed by using switch parameter -suppressGridDisplay)
#
# 2020.10.23 by Matthias Mehrtens
# 2021.01.25 fixed from loading "Add-PSSnapin -Name VeeamPSSnapIn" to "Import-Module Veeam.Backup.PowerShell" by Michael L.
# 2022.02.01 fixed several minor bugs
# 2022.02.09 added blocksize calculations, mainly to assist object storage sizing
# 2022.03.02 fixed and enhanced some calculations (vbr sometimes provides weird dedupe ratios, I've tried to identifiy and ignore those)
# 2022.03.03 vbr server name now accepted as parameter, parameter "suppressGridDisplay" added
# 2022.03.03 added credential file read/write and enabled passing an array of vbr servers via pipeline, e.g.
#            'vbr-1', 'vbr-2' | .\get-rp-statistics -suppressGridDisplay
# 2022.05.27 uploaded to Github
# 2022.06.17 added CompletionTime and corrupt/consistent info
# -----------------------------------------------

# vbrServer passed as parameter (script will ask for credentials if there is no credentials file!)
Param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$vbrServer,
    [Parameter(Mandatory = $false)]
    [switch]$suppressGridDisplay = $false,
    [Parameter(Mandatory = $false)]
    [string]$outputDir = ""
)
# -----------------------------------------------


Begin {
    #Add-PSSnapin VeeamPSSnapin -ErrorAction SilentlyContinue
    #Import-Module Veeam.Backup.PowerShell

    #$jobTypesStandard = @("Backup",
    #                      "BackupSync",
    #                      "SimpleBackupCopyPolicy",
    #                      "SimpleBackupCopyWorker")
    #$jobTypeAgents   =  @("EndpointBackup",
    #                      "EpAgentBackup",
    #                      "EpAgentManagement")
    $jobTypesUnsuppd = @("OracleRMANBackup",
        "SapHanaBackintBackup",
        "SqlLogBackup",
        "VmbApiPolicyTempJob")

    $jobBlockSizes = [PSCustomobject]@{ kbBlockSize256 = 256 * 1024
        kbBlockSize512                                 = 512 * 1024
        kbBlockSize1024                                = 1024 * 1024
        kbBlockSize4096                                = 4096 * 1024
        kbBlockSize8192                                = 8192 * 1024
        Automatic                                      = "[Automatic]"
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
    Write-Verbose "Backup Server: $vbrServer"

    if ($outputDir -eq "") {
        $outputDir = $PSScriptRoot
    }
    elseif (-not (Test-Path -PathType Container $outputDir)) {
        $outputDir = $PSScriptRoot
    }
    else {
        $outputDir = $outputDir.TrimEnd("\")
    }
    # output files path/name prefix
    $outfilePrefix = "$($procStartTime.ToString("yyyy-MM-ddTHH-mm-ss"))-$($vbrServer)"

    # -----------------------------------------------

    # credential file for this server
    $credFile = "$PSScriptRoot\$vbrServer-creds.xml"
    # output file of restore points
    $outfileRP = "$outputDir\$outfilePrefix-RPs.csv"
    #output file for statistics
    $outfileStatistics = "$outputDir\$outfilePrefix-Statistics.csv"

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

    Write-Progress -Activity "Getting repository infos from $vbrServer" -Id 1

    Write-Progress -Activity "Getting all backup jobs from $vbrServer" -Id 1

    # get all backup jobs
    Write-Verbose "Getting all backup jobs."
    $allBackups = Get-VBRBackup | Where-Object { $_.JobType -inotin $jobTypesUnsuppd }
    $allRPs = New-Object -TypeName 'System.Collections.Generic.List[object]'
    $countJobs = 0
    $rpId = 0

    Write-Progress -Activity $vbrServer -Id 1

    # iterate through backup jobs
    foreach ($objBackup in $allBackups) {
        Write-Verbose "Working on job: $($objBackup.JobName)"
        $countJobs++
        Write-Progress -Activity "Iterating through backup jobs" -CurrentOperation "$($objBackup.JobName)" -PercentComplete ($countJobs / $allBackups.Count * 100) -Id 2 -ParentId 1

        try {
            $objThisRepo = $null
            $objThisRepo = $objBackup.GetRepository()
        }
        catch {
        }
        $objRPs = $null
        try {
            # get all restore points of current job
            $objRPs = Get-VBRRestorePoint -Backup $objBackup
        }
        catch {
        }

        $countRPs = 0
        # iterate through all restore points
        foreach ($restorePoint in $objRPs) {
            Write-Progress -Activity "Getting restore points" -PercentComplete ($countRPs / $objRPs.Count * 100) -Id 3 -ParentId 2
            
            $myBackupJob = $null
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

            # check valid completion time 
            $completionTime = $restorePoint.CompletionTimeUTC
            $durationSpan = $null
            if ($null -ne $completionTime) {
                if ($completionTime -gt $restorePoint.CreationTimeUTC) {
                    $completionTime = $completionTime.ToLocalTime()
                    $durationSpan = New-TimeSpan -Start $restorePoint.CreationTimeUTC -End $restorePoint.CompletionTimeUTC
                }
                else {
                    $completionTime = $null
                }
            }
            $countRPs++
            $tmpObject = [PSCustomobject]@{
                RpId                = ++$rpID # will be set later!
                VMName              = $restorePoint.VmName
                BackupJob           = $objBackup.Name
                Repository          = $myRepoName
                Extent              = $extentName
                RepoType            = $restorePoint.FindChainRepositories().Type
                CreationTime        = $restorePoint.CreationTimeUTC.ToLocalTime()
                CompletionTime      = $completionTime
                Duration            = $durationSpan
                IsCorrupted         = $restorePoint.IsCorrupted
                IsConsistent        = $restorePoint.IsConsistent
                BackupType          = $restorePoint.algorithm
                ProcessedData       = $restorePoint.ApproxSize
                DataSize            = $restorePoint.GetStorage().stats.DataSize
                DataRead            = $myDataRead
                BackupSize          = $restorePoint.GetStorage().stats.BackupSize
                DedupRatio          = $myDedup
                ComprRatio          = $myCompr
                Reduction           = $myDedup * $myCompr
                IncrInterval        = $null
                ChangeRate          = $null
                ChangeRate24h       = $null
                Blocksize           = $myBlocksize
                NumOfBlocksRead     = $null
                NumOfBlocksWritten  = $null
                AvgBlocksizeWritten = $null
                Folder              = get_backupfile_path $restorePoint
                Filename            = $restorePoint.GetStorage().PartialPath.Internal.Elements[0]
            }
            # calculate blocksize statistics if dedupe ratio is reasonable (vbr provides weird numbers sometimes...)
            if ($tmpObject.BackupSize -gt 0) {
                if ($tmpObject.DedupRatio -le ($tmpObject.DataRead / $tmpObject.BackupSize)) {
                    if ( ($myBlockSize -gt 0) -and ($tmpObject.BackupSize -le $tmpObject.DataRead) ) {
                        $tmpObject.NumOfBlocksRead = $tmpObject.DataRead / $myBlockSize
                        if ($tmpObject.NumOfBlocksRead -gt 0) {
                            $tmpObject.NumOfBlocksWritten = [int]([math]::Round($tmpObject.NumOfBlocksRead / $tmpObject.DedupRatio))
                            $tmpObject.AvgBlocksizeWritten = $tmpObject.BackupSize / $tmpObject.NumOfBlocksWritten
                        }
                    }
                }
            }
            $allRPs.Add($tmpObject) | Out-Null
            $tmpObject = $null
        }
    }
    Write-Verbose "Disconnecting from backup server $vbrServer."
    Disconnect-VBRServer -ErrorAction SilentlyContinue
    
    Write-Progress -Activity "Getting restore points" -Id 3 -ParentId 2 -Completed
    Write-Progress -Activity "Iterating through backup jobs" -Id 2 -Completed

    Write-Progress -Activity "Calculating and preparing output..." -Id 2 -ParentId 1
    Write-Verbose "Calculating and preparing output."

    # sort restore points for processing
    $allRPs = $allRPs | Sort-Object -Property VMName, BackupJob, CreationTime

    # ...and re-number sorted list
    $rpID = 0
    foreach ($rp in $allRPs) { $rp.RpId = ++$rpID }

    # create master list of unique vm-job combinations
    $masterList = New-Object -TypeName 'System.Collections.Generic.List[object]'
    foreach ($rp in $allRPs) {
        # create object of vm/job combination, if it hasn't been added to master list yet
        if ($null -eq ($masterList | Where-Object { ($_.VM -eq $rp.VMName) -and ($_.Job -eq $rp.BackupJob) -and ($_.Repository -eq $rp.Repository) }) ) {
            
            if ($null -ne $rp.Extent) {
                $myRepoType = "SOBR"
            }
            else {
                $myRepoType = $rp.RepoType
            }

            $combiObject = [PSCustomobject]@{ 
                VM                   = $rp.VMName
                Job                  = $rp.BackupJob
                Repository           = $rp.Repository
                RepoType             = $myRepoType
                Blocksize            = $rp.Blocksize
                RPList               = New-Object -TypeName 'System.Collections.Generic.List[object]'
                # the following properties will be populated later
                FullCount            = $null
                IncrCount            = $null
                SyntCount            = $null
                AvgFullDuration      = $null
                AvgSyntDuration      = $null
                AvgIncrDuration      = $null
                AvgFullDedup         = $null
                AvgFullCompr         = $null
                AvgFullReduction     = $null
                AvgIncrDedup         = $null
                AvgIncrCompr         = $null
                AvgIncrReduction     = $null
                #AvgIncrChangeRate = $null
                AvgIncrChangeRate24h = $null
                OldestBackupDate     = $null
                NewestBackupDate     = $null
                FullSize             = 0
                IncrSize             = 0
                TotalSize            = 0
                AvgBlocksizeWritten  = $null
            }
            # add all restore points of this vm/job combination to this object
            $rpSelection = $allRPs | Where-Object { ($_.VMName -eq $rp.VMName) -and ($_.BackupJob -eq $rp.BackupJob) -and ($_.Repository -eq $rp.Repository) } | Sort-Object -Property RpId
            foreach ($selectedRp in $rpSelection) {
                $combiObject.RPList.Add($selectedRP) | Out-Null
            }
            # add the object to the mater list
            $masterList.Add($combiObject) | Out-Null
            $combiObject = $null
        }
    }

    # calculate change rates for incremental backups
    foreach ($combi in $masterList) {
        $fullDetected = $false

        foreach ($rp in $combi.RPList) {
            if ($rp.BackupType -ne "Increment") {
                # store last full backup size for change rate calculation
                $lastFullSize = $rp.BackupSize
                $fullDetected = $true
            }
            elseif ($fullDetected) {
                # perform change rate calculation and store result in combi object's restore point
                $interval = (New-TimeSpan -Start $lastRPDate -End $rp.CreationTime).TotalSeconds
                if ($interval -gt 0) {
                    $rp.IncrInterval = $interval
                    if ($lastFullSize -gt 0) {
                        $rp.ChangeRate = $rp.BackupSize / $lastFullSize
                        # calculate normalized change rate for 24 hour interval (= 86400 seconds)
                        $rp.ChangeRate24h = ($rp.ChangeRate / $interval) * 86400
                    }
                }
            }
            $lastRPDate = $rp.CreationTime
        }
    }

    # calculate averages for change rates, durations, deduplication and compression ratios
    foreach ($combi in $masterList) {
        # reset all running variables
        $fullCount = $syntCount = $incrCount = 0
        $fullDedupSum = $fullComprSum = 0
        $incrDedupSum = $incrComprSum = 0
        $incrCRSum = $incrCR24hSum = 0
        $RPswithBlocksize = $BlocksWrittenTotal = 0
        $fullDurationSum = $syntDurationSum = $incrDurationSum = $null

        # iterate restore points
        foreach ($rp in $combi.RPList) {
            $combi.TotalSize += $rp.BackupSize
            
            if ($rp.BackupType -ne "Increment") {
                # look at full backups
                $combi.FullSize += $rp.BackupSize
                $fullCount++
                $fullDedupSum += $rp.DedupRatio
                $fullComprSum += $rp.ComprRatio
                if ($rp.BackupType -eq "Full") {
                    if ($null -ne $rp.Duration) {
                        $fullDurationSum += $rp.Duration.TotalSeconds
                    }
                }
                else {
                    $syntCount++
                    if ($null -ne $rp.Duration) {
                        $syntDurationSum += $rp.Duration.TotalSeconds
                    }
                }
            }
            else {
                # look at incremental and synthetic backups
                $combi.IncrSize += $rp.BackupSize
                $incrCount++
                $incrDedupSum += $rp.DedupRatio
                $incrComprSum += $rp.ComprRatio
                $incrCRSum += $rp.ChangeRate
                $incrCR24hSum += $rp.ChangeRate24h
                if ($null -ne $rp.Duration) {
                    $incrDurationSum += $rp.Duration.TotalSeconds
                }
            }
            # build blocksize statistics
            if ($rp.NumOfBlocksWritten -gt 0 ) {
                $RPswithBlocksize++
                $BlocksWrittenTotal += $rp.AvgBlocksizeWritten
            }
        }
        # calculate averages and add results to object
        if ($fullCount -gt 0) {
            $combi.FullCount = $fullCount
            $combi.AvgFullDedup = $fullDedupSum / $fullCount
            $combi.AvgFullCompr = $fullComprSum / $fullCount
            if ($fullCount -eq $syntCount) { $divisor = $fullCount } else { $divisor = $fullCount - $syntCount }
            if ($fullDurationSum -gt 0 ) { $combi.AvgFullDuration = New-TimeSpan -Seconds ($fullDurationSum / $divisor) }
            $combi.IncrCount = $incrCount
        }
        if ($incrCount -gt 0) {
            $combi.AvgIncrDedup = $incrDedupSum / $incrCount
            $combi.AvgIncrCompr = $incrComprSum / $incrCount
            #$combi.AvgIncrChangeRate = $incrCRSum / $incrCount
            $combi.AvgIncrChangeRate24h = $incrCR24hSum / $incrCount
            if ($incrDurationSum -gt 0) {
                $combi.AvgIncrDuration = New-TimeSpan -Seconds ($incrDurationSum / $incrCount)
            }
            if (($syntDurationSum -gt 0) -and ($syntCount -gt 0)) {
                $combi.SyntCount = $syntCount
                $combi.AvgSyntDuration = New-TimeSpan -Seconds ($syntDurationSum / $syntCount)
            }
        }
        $combi.OldestBackupDate = $combi.RPList[0].CreationTime
        $combi.NewestBackupDate = $combi.RPList[$combi.RPList.Count - 1].CreationTime

        if ($RPswithBlocksize -gt 0) {
            $combi.AvgBlocksizeWritten = [int](($BlocksWrittenTotal / $RPswithBlocksize) + 0.5)
        }
        else {
            $combi.AvgBlocksizeWritten = $null
        }
    }

    # create statistics output
    $outStats = New-Object -TypeName 'System.Collections.Generic.List[object]'
    foreach ($combi in $masterlist) {
        $outObject = [PSCustomObject]@{
            # properties to be included in output
            VM                  = $combi.VM
            Job                 = $combi.Job
            Repository          = $combi.Repository
            RepoType            = $combi.RepoType
            oldestBackup        = $combi.OldestBackupDate
            newestBackup        = $combi.NewestBackupDate
            TotalBackupVolume   = $combi.TotalSize
            nofFulls            = $combi.FullCount
            nofIncrs            = $combi.IncrCount
            nofSynts            = $combi.SyntCount
            avgFullDuration     = $combi.AvgFullDuration
            avgIncrDuration     = $combi.AvgIncrDuration
            avgSyntDuration     = $combi.AvgSyntDuration
            FullBackupVolume    = $combi.FullSize
            avgFullDedup        = $combi.AvgFullDedup
            avgFullCompr        = $combi.AvgFullCompr
            avgFullReduction    = $combi.AvgFullDedup * $combi.AvgFullCompr
            IncrBackupVolume    = $combi.IncrSize
            avgIncrDedup        = $combi.AvgIncrDedup
            avgIncrCompr        = $combi.AvgIncrCompr
            avgIncrReduction    = $combi.AvgIncrDedup * $combi.AvgIncrCompr
            avgChangeRate24h    = $combi.AvgIncrChangeRate24h
            Blocksize           = $combi.Blocksize
            AvgBlocksizeWritten = $combi.AvgBlocksizeWritten
        }
        $outStats.Add($outObject) | Out-Null
        $outObject = $null
    }
    Write-Progress -Activity "Calculating and preparing output..." -Id 2 -ParentId 1 -Completed


    # output everything
    # -----------------

    if ($allRPs.Count -gt 0) {

        $allRPs | Export-Csv -Path "$outfileRP" -NoTypeInformation -Delimiter ';'
        Write-Verbose "output file created: $outfileRP"
        $outStats | Export-Csv -Path "$outfileStatistics" -NoTypeInformation -Delimiter ';'
        Write-Verbose "output file created: $outfileStatistics"

        if (-not $suppressGridDisplay) {
            # prepare 'human readable' figures for GridViews
            Write-Verbose "Preparing GridViews."
            foreach ($rp in $allRPs) {
                $gridDuration = $null
                if ($null -ne $rp.Duration) {
                    $gridDuration = formatDuration($rp.Duration)
                }
                $rp.Duration = $gridDuration
                $rp.ProcessedData = Format-Bytes $rp.ProcessedData
                $rp.DataSize = Format-Bytes $rp.DataSize
                $rp.DataRead = Format-Bytes $rp.DataRead
                $rp.BackupSize = Format-Bytes $rp.BackupSize
                if ($rp.AvgBlocksizeWritten -gt 0) { $rp.AvgBlocksizeWritten = Format-Bytes $rp.AvgBlocksizeWritten }
                if ($rp.Blocksize -gt 0) { $rp.BlockSize = Format-Bytes $rp.BlockSize }
                if ($null -ne $rp.ChangeRate) { $rp.ChangeRate = [math]::Round($rp.ChangeRate * 100, 2) }
                if ($null -ne $rp.ChangeRate24h) { $rp.ChangeRate24h = [math]::Round($rp.ChangeRate24h * 100, 2) }
            }
            foreach ($statItem in $outStats) {
                $statItem.TotalBackupVolume = Format-Bytes $statItem.TotalBackupVolume
                $statItem.FullBackupVolume = Format-Bytes $statItem.FullBackupVolume
                $statItem.IncrBackupVolume = Format-Bytes $statItem.IncrBackupVolume
                if ($statItem.AvgBlocksizeWritten -gt 0) { $statItem.AvgBlocksizeWritten = Format-Bytes $statItem.AvgBlocksizeWritten }
                if ($statItem.BlockSize -gt 0) { $statItem.BlockSize = Format-Bytes $statItem.BlockSize }
                if ($null -ne $statItem.avgChangeRate24h) { $statItem.avgChangeRate24h = [math]::Round($statItem.avgChangeRate24h * 100, 2) }
                if ($null -ne $statItem.avgFullDuration) { $statItem.avgFullDuration = formatDuration($statItem.avgFullDuration) }
                if ($null -ne $statItem.avgIncrDuration) { $statItem.avgIncrDuration = formatDuration($statItem.avgIncrDuration) }
                if ($null -ne $statItem.avgSyntDuration) { $statItem.avgSyntDuration = formatDuration($statItem.avgSyntDuration) }
            }

            # output GridViews
            Write-Verbose "GridView display."
            $allRPs | Out-GridView -Title "List of restore points ($outfileRP)" -Verbose 
            $outStats | Out-GridView -Title "Restore point statistics ($outfileStatistics)"
        }
    }
    $procDuration = formatDuration(New-TimeSpan -Start $procStartTime)
    Write-Progress -Activity $vbrServer -Id 1 -Completed
    Write-Output "Finished processing backup server ""$vbrServer"" ($($allRPs.Count) restore points, processing time: $procDuration)"
}
