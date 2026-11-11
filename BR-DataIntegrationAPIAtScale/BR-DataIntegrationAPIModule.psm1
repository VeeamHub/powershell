# Johan Huttenga, 20220517

$LogFile = "C:\Scripts\BR-DataIntegrationAPIAtScale\$($MyInvocation.MyCommand.Name).log"
$CurrentPid = ([System.Diagnostics.Process]::GetCurrentProcess()).Id

Function Write-Log {
    param([string]$str, $consoleout = $true, $foregroundcolor = (get-host).ui.rawui.ForegroundColor, $backgroundcolor = (get-host).ui.rawui.BackgroundColor)      
    if ($consoleout) { Write-Host -ForegroundColor $foregroundcolor -BackgroundColor $backgroundcolor $str }
    $dt = (Get-Date).toString("yyyy.MM.dd HH:mm:ss")
    $str = "[$dt] <$CurrentPid> $str"
    Add-Content $LogFile -value $str
}

Function DisplayInBytes {
    param([int]$value, [int]$unit = -1)

    $suffix = "B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"
    $index = 0
    if ($unit = -1) {
        # see how many times $value can be divided by 1024
        $unit = 1
        while ($value -gt 1024) {
            $value = $value / 1024
            $unit *= 1024
            $index += 1
        }
    }
    return "{0:N1} {1}" -f $value, $suffix[$index]
}

Function Queue-VBRPublishBackupContent {
    param([Veeam.Backup.Core.COib]$RestorePoint, [Veeam.Backup.Core.Common.CHost[]]$targetServers, [string]$Description)

    Write-Log "Finding resources to process secure restore for $($restorepoint.Name) created $($restorepoint.CreationTimeUTC)."
    $restoresessions = Get-VBRPublishedBackupContentSession
    
    if ($restoresessions -ne $null) {

        # find target server with least number of restore sessions where not exceeding 2 sessions
        # can improve this by doing math on cpu and memory usage of target servers. need one additional core for base OS

        $maxSessionsPerTarget = 2
        $targetServer = $null
        $targetServerSessions = @{}
        foreach($target in $targetServers) {
            $targetServerSessions[$target.Name] = ($restoresessions | Where-Object {$_.InitiatorName -eq $target.Name} | measure-object).Count
            Write-Log "Target server $($target.Name) has $($targetServerSessions[$target.Name]) restore sessions."
        }
        
        $leastSessionsServer = $targetServerSessions.GetEnumerator() | sort-object -property Value | select-object -first 1
        if ($leastSessionsServer.Value -lt $maxSessionsPerTarget) {
            $targetServer = $targetServers | Where-Object {$_.Name -eq $leastSessionsServer.Name}
        }
        
        # loop if target servers all have too many restore sessions, wait 30 seconds with a maximum of 30 minutes
        $waittime = 0
        while ($targetServer -eq $null -and $waittime -lt 1800) {
            Write-Log "No target server found with less than $($maxSessionsPerTarget) restore sessions. Waiting 30 seconds."
            Start-Sleep -Seconds 30
            $waittime += 30
            $restoresessions = @()
            foreach($targets in $targetServers) {
                $restoresessions += Get-VBRPublishedBackupContentSession
            }
            $targetServerName = $restoresessions | Group-Object -Property InitiatorName | Sort-Object -Property Count | Where-Object {$_.Count -lt $maxSessionsPerTarget} | Select-Object -First 1 -ExpandProperty Name
            $targetServer = $targetServers | Where-Object {$_.Name -eq $targetServerName}
        }
    } else {
        # pick random target server if no running restore sessions found
        $targetServer = $targetServers | Get-Random
    }
    
    if ($targetServer -eq $null) {
        Write-Log "Error: No target server found to process secure restore for $($restorepoint.Name)."
        return
    }
    # publish restore session
    Publish-SecureRestoreSession -RestorePoint $restorepoint -TargetServer $targetServer -ScanType 3
    
}

function Enable-RemoteLogging {
    param([System.Management.Automation.Runspaces.PSSession]$session)
    $script = {
        param([string]$Version,[string]$CommandName)
        # create directory
        $dir = "C:\Scripts\BR-DataIntegrationAPIAtScale"
        if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
        
        Function Write-Log {
            param([string]$str, $consoleout = $false, $foregroundcolor = (get-host).ui.rawui.ForegroundColor, $backgroundcolor = (get-host).ui.rawui.BackgroundColor)      
            
            $LogFile = "C:\Scripts\BR-DataIntegrationAPIAtScale\BR-DataIntegrationAPIMount.log"
            $CurrentPid = ([System.Diagnostics.Process]::GetCurrentProcess()).Id
            
            if ($consoleout) { Write-Host -ForegroundColor $foregroundcolor -BackgroundColor $backgroundcolor $str }
            $dt = (Get-Date).toString("yyyy.MM.dd HH:mm:ss")
            $str = "[$dt] <$CurrentPid> $str"
            Add-Content $LogFile -value $str
        }

        Write-Log $("="*78)
        Write-Log "{"
        Write-Log "`tScript: BR-DataIntegrationAPIModule"
        Write-Log "`tVersion: { $($Version) }"
        Write-Log "}"
    }

    Invoke-Command -ScriptBlock $script -Session $session -ArgumentList $Version
}

function Get-RemoteRestoredVolumes {
    param([string]$restorePointName, [System.Management.Automation.Runspaces.PSSession]$session)
    
    $result = $null

    $script = {
        param([string]$restorePointName)
        # find volumes to scan
        $volumes = Get-WmiObject win32_volume | Where-Object {$_.name -match "c:\\VeeamFLR\\$($restorePointName)" -and $_.label -ne "System Reserved"} | Select-Object Name, FileSystem, Label

        if ($volumes -eq $null) {
            Write-Log "Error: No volumes found to scan for $($restorePointName)."
        }
        else {
            $output = "Volumes found to scan for $($restorePointName): "
            foreach ($volume in $volumes) { $output += "$($volume.Name), " }
            Write-log $output
        }

        $volumes
    }
    
    $result = Invoke-Command -ScriptBlock $script -ArgumentList $restorePointName -Session $session
    return $result;
}

function Get-RemoteDefenderVersion {
    param([System.Management.Automation.Runspaces.PSSession]$session)

    $result = $null

    $script = {
        $defenderVersion = Get-Childitem 'C:\ProgramData\Microsoft\Windows Defender\Platform' | ? { $_.PSIsContainer } | sort CreationTime -desc | select -f 1
        if ($defenderVersion -eq $null) {
            Write-Log "Error: No Microsoft Defender version found on $($env:COMPUTERNAME)."
        }
        else {
            Write-Log "Microsoft Defender version found for $($env:COMPUTERNAME): $($defenderVersion.Name)"
        }
        $defenderVersion
    }

    $result = Invoke-Command -ScriptBlock $script -Session $session

    return $result
}
function Start-RemoteDefenderScan {
    param([System.Management.Automation.Runspaces.PSSession]$session, [string]$defenderVersion, [string]$volumeName, [int]$defenderScanType = 3)

    $script = {
        param([string]$defenderVersion, [string]$volumeName, [int]$defenderScanType)
        
        Function DisplayInBytes {
            param([long]$value, [int]$unit = -1)
        
            $suffix = "B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"
            $index = 0
            if ($unit -gt 0) { $index = [math]::Log($unit, 1024)}
            if ($unit = -1) {
                # see how many times $value can be divided by 1024
                $unit = 1
            }
            while ($value -gt 1024) {
                $value = $value / 1024
                $unit *= 1024
                $index += 1
            }
            return "{0:N1} {1}" -f $value, $suffix[$index]
        }

        $defenderProductVersion = $(Get-ItemProperty "C:\ProgramData\Microsoft\Windows Defender\Platform\$defenderVersion\MpCmdRun.exe").VersionInfo.ProductVersion
        Write-Log "Scanning: Microsoft Defender $($defenderProductVersion) scan (type: $($defenderScanType)) for $($volumeName) started on $($env:COMPUTERNAME) at $((Get-Date).toString("yyyy.MM.dd HH:mm:ss"))." -consoleout $true
        
        #replace start-process with System.Diagnostics.Process
        $startinfo = New-Object System.Diagnostics.ProcessStartInfo
        $startinfo.RedirectStandardError = $true
        $startinfo.RedirectStandardOutput = $true
        $startinfo.UseShellExecute = $false
        $startinfo.FileName = "C:\ProgramData\Microsoft\Windows Defender\Platform\$defenderVersion\MpCmdRun.exe"
        $startinfo.Arguments = "-Scan -ScanType $($defenderScanType) -File $($volumeName) -DisableRemediation"
        $scanprocess = New-Object System.Diagnostics.Process
        $scanprocess.StartInfo = $startinfo
        
        Write-Log "Process started: $($scanprocess.StartInfo.FileName) $($scanprocess.StartInfo.Arguments)"
        
        $starttime = (Get-Date)
        $scanprocess.Start() | Out-Null
        
        # get child process id
        $childprocesses = Get-WmiObject win32_process | Where-Object {$_.ParentProcessId -eq $scanprocess.Id}

        #wait for scan process and log we're waiting every 30 seconds
        $waittime = 0 
        while (!$scanprocess.HasExited -and $waittime -lt 1800) {
            # log current cpu and ram usage of machine 
            $cpuused = (Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select Average).Average
            $ramavail = (Get-WmiObject win32_physicalmemory | Measure-Object -property Capacity -Sum | Select Sum).Sum
            $ramfree = (Get-WmiObject win32_operatingsystem | Measure-Object -property FreePhysicalMemory -Average | Select Average).Average
            $ramused = $ramavail - ($ramfree*1024) 
            $rampct = [math]::round($ramused / $ramavail, 2) * 100
            Write-Log "Scanning: Overall host CPU usage: $($cpuused)%, RAM usage: $($rampct)%, RAM avail: $(DisplayInBytes($ramavail)), RAM used: $(DisplayInBytes($ramused)) ..." -consoleout $true

            $processmetrics = Get-Process -Name MsMpEng | Measure-Object -property CPU, WorkingSet64 -Sum
            $scanram = DisplayInBytes($($processmetrics | Where-Object {$_.Property -like "WorkingSet64" } | Select Sum).Sum)
            Write-Log "Scanning: Scan process (MpCmdRun pid $($scanprocess.Id)) calling (MsMpEng) RAM usage: $($scanram) ..." -consoleout $true

            $waitincrement = 30
            if ($defenderScanType -eq 1) { $waitincrement = 5 }
            Start-Sleep -Seconds $waitincrement
            $waittime += 30
            Write-Log "Scanning: Waiting for scan process to complete, $($waittime) seconds have elapsed since start time..." -consoleout $true
        }

        # if scan process still running, kill it
        if (!$scanprocess.HasExited) {
            Write-Log "Error: Scan process still running after 30 minutes. Killing process."
            $scanprocess.Kill()
        }

        # get process output
        $stdout = $scanprocess.StandardOutput.ReadToEnd()
        $stderr = $scanprocess.StandardError.ReadToEnd()
        if ($stderr -eq $null -or $stderr.length -eq 0) {  $stderr = "No Errors" }
        $outVolume = $volumeName
        $status = "Scanning complete."
        $stdout = [system.string]::Join(" ",$stdout.ToString()).TrimEnd()
        if ($defenderScanType -eq 1) {
            $status = $stdout.Split("`n")[-1].Trim()
            write-log "Scan Type 1, details: { $($stdout) }"
        }
        elseif ($defenderScanType -eq 2) {
            $status = $stdout.Split("`n")[-1].Trim()
            write-log "Scan Type 2, details: { $($stdout) }"
        }
        elseif ($defenderScanType -eq 3) {
            $d = $stdout.IndexOf('Volume')
            $e = $stdout.IndexOf('found')
            $f = $e - $d
            $outVolume = $stdout.Substring($d, $f - 2 )
            $status = $stdout.Substring($e)
            write-log "Scan Type 3, details: { $($stdout) }"
        }
        $duration = $(Get-Date)-$starttime
        Write-Log "Scan completed of $($outVolume) at $((Get-Date).toString("yyyy.MM.dd HH:mm:ss")) with result: $($status)"
        $p = @{
            'Volume' = $outVolume
            'Status' = $status
            'Output' = $stdout
            'Error' = $stderr
            'StartTime' = $starttime
            'Duration' = $duration
            'ScanType' = $defenderScanType
        }
        return New-Object -TypeName PSObject -Prop $p
    }

    $result = Invoke-Command -ScriptBlock $script -Session $session -ArgumentList $defenderVersion, $volumeName, $defenderScanType

    return $result
}

function Write-Report {
param($CSVFile = "C:\Scripts\BR-DataIntegrationAPIAtScale\BR-DataIntegrationAPIReport.csv")
    
    # check if csv file exists
    if (!(Test-Path $CSVFile)) { Write-Log "Error: Cannot find CSV file $($CSVFile) to generate report." return }
    $csv = Import-Csv $CSVFile
    $csv = $csv | Where-Object { [datetime]::parse($_.ReportTime) -gt (Get-Date).AddDays(-1) }

    # generate html with tables of csv data with veeam green header
    $random = Get-Random -Minimum 0 -Maximum 9
    $HTMLFile = "C:\Scripts\BR-DataIntegrationAPIAtScale\BR-DataIntegrationAPIReport-$((Get-Date).toString("yyyyMMdd-HHmmss")+$random).html"

    Add-Content $HTMLFile "<html><head>"
    Add-Content $HTMLFile "<style>"

    Add-Content $HTMLFile "table { border-collapse: collapse; }"
    Add-Content $HTMLFile "table, th, td { border: 1px solid black; }"
    Add-Content $HTMLFile "th { background-color: #00b050; color: white; }"
    Add-Content $HTMLFile "td, th { padding: 0.5rem; }"
    Add-Content $HTMLFile "tr:nth-child(even) { background-color: #f3f3f3; }"
    Add-Content $HTMLFile "tr:hover { background-color: #e5e5e5; }"

    Add-Content $HTMLFile "@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap');"
    Add-Content $HTMLFile "body { font-family: 'Inter', sans-serif; }"
    Add-Content $HTMLFile "h1 { font-size: 2.25rem; font-weight: 800; }"
    Add-Content $HTMLFile "h2 { font-size: 1.25rem; font-weight: 700; }"
    Add-Content $HTMLFile "table { font-size: 1rem; font-weight: 500; }"


    Add-Content $HTMLFile "</style>"
    Add-Content $HTMLFile "</head><body>"
    Add-Content $HTMLFile "<h1>BR-DataIntegrationAPI Report</h1>"
    Add-Content $HTMLFile "<h2>Report Period: $((Get-Date).AddDays(-1).toString("yyyy.MM.dd HH:mm:ss")) - $((Get-Date).toString("yyyy.MM.dd HH:mm:ss"))</h2>"
    Add-Content $HTMLFile "<table>"
    Add-Content $HTMLFile "<tr><th>ReportTime</th><th>RestorePoint</th><th>RestorePointCreationTime</th><th>Volume</th><th>ScanType</th><th>ScanStartTime</th><th>ScanDuration</th><th>ScanStatus</th></tr>"
    foreach ($line in $csv) {
        Add-Content $HTMLFile "<tr><td>$($line.ReportTime)</td><td>$($line.RestorePoint)</td><td>$($line.RestorePointCreationTime)</td><td>$($line.Volume)</td><td>$($line.ScanType)</td><td>$($line.ScanStartTime)</td><td>$($line.ScanDuration)</td><td>$($line.ScanStatus)</td></tr>"
    }
    Add-Content $HTMLFile "</table></body></html>"
}

function Write-CSV {
    param([Veeam.Backup.Core.COib]$RestorePoint, $ScanResult, $CSVFile = "C:\Scripts\BR-DataIntegrationAPIAtScale\BR-DataIntegrationAPIReport.csv")
    write-log "Writing output for $($restorepoint.Name) to CSV file. Total scantime was $($ScanResult.Duration.TotalSeconds) seconds."
    # check if file does not exist and create first line with columns
    if (!(Test-Path $CSVFile)) {
        $columns = "ReportTime, RestorePoint, RestorePointCreationTime, Volume, ScanType, ScanStartTime, ScanDuration, ScanStatus"
        Add-Content $CSVFile -Value $columns
    }
    $line =  "$((Get-Date).toString("yyyy.MM.dd HH:mm:ss")), $($restorepoint.name), $($restorepoint.creationtime),"
    $line += "$($ScanResult.Volume), $($ScanResult.ScanType), $($ScanResult.StartTime), $($ScanResult.Duration), $($ScanResult.Status.ToLoWer())"
    Add-Content $CSVFile -Value $line
}
    
function Initialize-VBRCredentialStore {
    
    $result = $null
    $dbconfig = [Veeam.Backup.Configuration.ProductExtensions]::GetActiveDatabaseConfiguration([Veeam.Backup.Common.SProduct]::Instance)
    $dbaccessor = [Veeam.Backup.DBManager.CDatabaseAccessorFactory]::Create($dbconfig)
    $creds = [Veeam.Backup.DBManager.CCredentialsDbScope]::new($dbaccessor)
    $localcreds = [Veeam.Backup.Core.CLocalCredentialsScope]::new($creds)
    $sshcreds = [Veeam.Backup.DBManager.CSshCredsDbScope]::new($dbaccessor)
    $localsshcreds = [Veeam.Backup.Core.CLocalSshCredentialsScope]::new($sshcreds)
    $localpwdcrypto =  [Veeam.Backup.DBManager.CLocalPasswordCryptoKeysScope]::new($dbaccessor)
    $cloudcreds = [Veeam.Backup.DBManager.CCloudCredentialsDbScope]::new($dbaccessor)
    $onsitecreds =[Veeam.Backup.DBManager.COnsiteCredentialsDbScope]::new($dbaccessor)
    $platsvccreds =[Veeam.Backup.DBManager.CPlatformServiceCredentialsDbScope]::new($dbaccessor)

    $result = [Veeam.Backup.Model.CCredentialsStrore]::Initialize($localcreds,$localsshcreds, $localpwdcrypto, $cloudcreds, $onsitecreds, $platsvccreds)

    return $result
}

function Get-VBRCredentialCache {

    $result = @()
    $credentials = @()

    $credstore = Initialize-VBRCredentialStore
  
    $credentials = [Veeam.Backup.Model.CCredentialsStrore]::Instance.Credentials.GetAllCreds($true)
  
    foreach($cred in $credentials) { 
      $pswd = $cred.get_Credentials().EncryptedPassword
      $decoded = [Veeam.Backup.Common.CStringCoder]::Decode($pswd,$true)
      if ($decoded.Length -gt 0) {
      $secpwd = ConvertTo-SecureString $([Veeam.Backup.Common.CStringCoder]::Decode($pswd,$true)) -AsPlainText -Force
      }
          $p = @{
            'Id'=$cred.Id
            'Username'=$cred.Credentials.UserName
            'UsernameAtNotation'=$cred.Credentials.UserNameAtNotation
            'UsernameSlashNotation'=$cred.Credentials.UserNameSlashNotation
            'Password'= $secpwd
          }
          $result += New-Object -TypeName PSObject -Prop $p
    }
  
    return $result
  
  }

  function Publish-SecureRestoreSession {
    param([Veeam.Backup.Core.COib]$RestorePoint, [Veeam.Backup.Core.Common.CHost]$TargetServer, [int]$ScanType = 3)
    # initialize credential cache
    $credentialcache = Get-VBRCredentialCache
    Write-Log "Publishing restore session for $($restorepoint.Name) created $($restorepoint.CreationTimeUTC) to $($targetServer.Name)."
    $targetcreds = get-vbrcredentials -Name $targetServer.ProxyServicesCreds.Name
    write-log "Target server credentials: $($targetcreds.Name)"

    # publish restore session, this is a synchronous process
    $publishsession = Publish-VBRBackupContent -RestorePoint $restorepoint -targetServerName $targetServer.Name -targetServerCredentials $targetcreds
    
    # superstitiously waiting to make sure it is really mounted
    $waittime = 0
    while ($waittime -lt 300) {
        $restoresession = Get-VBRPublishedBackupContentSession -Id $publishsession.Id
        if ($restoresession.MountState -eq "Mounted") { break }
        Write-Log "Waiting 30 seconds for restore session to mount."
        Start-Sleep -Seconds 30
        $waittime += 30
    }

    # if not mounted, unmount and return
    if ($restoresession.MountState -ne "Mounted") {
        Write-Log "Error: Restore session not mounted after 5 minutes. Sending unmount command and ending restore session for $($restorepoint.Name)."
        Unpublish-VBRBackupContent -Session $publishsession
        return
    }

    # open session for remote commands
    $targetcredsfromcache = $credentialcache | Where-Object { $_.Username -eq $targetcreds.Name }
    $targetpwshcreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $targetcredsfromcache.UserName, $targetcredsfromcache.Password
    $pssession = New-PSSession -ComputerName $targetServer.Name -Credential $targetpwshcreds

    Enable-RemoteLogging -Session $pssession
    $volumes = Get-RemoteRestoredVolumes -RestorePointName $RestorePoint.Name -Session $pssession

    if ($volumes -eq $null) {
        Write-Log "Error: No volumes found to scan for $($restorepoint.Name)."
        Unpublish-VBRBackupContent -Session $publishsession
        return
    } else {
        $output = "Volumes found to scan for $($restorepoint.Name): "
        foreach ($volume in $volumes) {
            $output += "$($volume.Name), "
        }
        Write-log $output
    }

    # create script block to find latest defender version
    $defenderVersion = Get-RemoteDefenderVersion -Session $pssession
    
    if ($defenderVersion -eq $null) {
        Write-Log "Error: No Microsoft Defender version found on $($targetServer.Name)."
        Unpublish-VBRBackupContent -Session $publishsession
        return
    }

    # create script block to run defender scan
    $scanresults = @()
    foreach($volume in $volumes) {
        $scanresults += Start-RemoteDefenderScan -Session $pssession -defenderVersion $defenderVersion.Name -volumeName $volume.Name -defenderScanType $ScanType
    }

    $CSVFile = "C:\Scripts\BR-DataIntegrationAPIAtScale\BR-DataIntegrationAPIReport.csv"
    foreach($result in $scanresults) {
        write-log $result
        Write-CSV -RestorePoint $restorepoint -ScanResult $result -CSVFile $CSVFile
        if ($result.status -eq $null) {
            Write-Log "Error: Occurred when processing $($result.Volume): $($result.output)"
            continue
        } 
        Write-Log "Completed: Scanning of $($volume.Name): $($result.Status)"
    }

    Write-Report -CSVFile $CSVFile
    
    # if not mounted, unmount and return
    if ($restoresession.MountState -eq "Mounted") {
        Write-Log "Unmounting restore session for $($restorepoint.Name)."
        Unpublish-VBRBackupContent -Session $publishsession
        return
    }
    
}
