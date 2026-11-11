# Johan Huttenga, 20220308

$LogFile = "$($MyInvocation.MyCommand.Name).log"
$CurrentPid = ([System.Diagnostics.Process]::GetCurrentProcess()).Id

Function Write-Log {
    param([string]$str, $consoleout = $true, $foregroundcolor = (get-host).ui.rawui.ForegroundColor, $backgroundcolor = (get-host).ui.rawui.BackgroundColor)      
    if ($consoleout) { Write-Host -ForegroundColor $foregroundcolor -BackgroundColor $backgroundcolor $str }
    $dt = (Get-Date).toString("yyyy.MM.dd HH:mm:ss")
    $str = "[$dt] <$CurrentPid> $str"
    Add-Content $LogFile -value $str
}   

Function Get-VBRInstallPath {
    $uninstallinfo = Get-Item -Path "Registry::HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\{3A15F9E8-BD07-4A61-9A0D-C29B8369A662}"
    return $uninstallinfo.GetValue("InstallLocation")
}

Function Get-VBRSessionTaskStatus {
    param ($status)
    [Veeam.Backup.Common.ETaskLogRecordStatus] $result = [Veeam.Backup.Common.ETaskLogRecordStatus]::ENone 
    if ($status -eq "Warning") { $result = [Veeam.Backup.Common.ETaskLogRecordStatus]::EWarning }
    elseif ($status -eq "Failed") { $result = [Veeam.Backup.Common.ETaskLogRecordStatus]::EFailed }
    elseif ($status -eq "Success") { $result = [Veeam.Backup.Common.ETaskLogRecordStatus]::ESucceeded }
    return $result
}

Function Write-VBRSessionLog {
    param($session, $text, $status)
    $task = New-VBRSessionTask $text -Status $status
    $recordid = $session.Logger.AddLog($task)
    $p = @{
            'RecordId'=$recordid
            'Task'=$task
    }
    $result = New-Object -TypeName PSObject -Prop $p
    return $result
}

Function Update-VBRSessionTask {
    param($session, $recordid, $text, $status)
    $result = 0
    if ($status -eq "Warning") {
            $result = $session.Logger.UpdateWarning($recordid, $text)
    }
    elseif ($status -eq "Failed") {
            $result = $session.Logger.UpdateErr($recordid, $text)
    }
    elseif ($status -eq "Success") {
            $result = $session.Logger.UpdateSuccess($recordid, $text)
    }
    else {
            $result = $session.Logger.UpdateLog($recordid, -1, $text, $null)
    }
}

Function Complete-VBRSessionTask {
    param($session, $cookie, $status)
    $_status = Get-VBRSessionTaskStatus $status
    $session.Logger.Complete($cookie,$_status)
}

Function New-VBRSessionTask {
    param ($text, $status = "Success")
    $_status = Get-VBRSessionTaskStatus $status
    $cookie = [System.Guid]::NewGuid().ToString()
    [Veeam.Backup.Common.CTaskLogRecord] $result = [Veeam.Backup.Common.CTaskLogRecord]::new($_status, [Veeam.Backup.Common.ETaskLogStyle]::ENone, 0, 0, $text, "", [System.DateTime]::Now, [System.DateTime]::Now, "", $cookie, 0)
    return $result
}

Function Get-MPHealthState {
    param($computerName = ".", $credential = $null)

    $healthState = "Error"
    $healthDetails = ""
    
    try {
    
        $s = $null
        if ($null -eq $credential)
        {
            $s = Get-WmiObject -ClassName "MSFT_MpComputerStatus" -Namespace "root/microsoft/windows/defender" -ComputerName $computerName
        }
        else {
            $s = Get-WmiObject -ClassName "MSFT_MpComputerStatus" -Namespace "root/microsoft/windows/defender" -ComputerName $computerName -Credential $credential
        }
        
        if ($null -ne $s) {
            #$p = Get-WmiObject -ClassName "MSFT_MpPreference" -Namespace "root\microsoft\windows\defender" -ComputerName $computerName
            #todo: compare with defaults https://docs.microsoft.com/en-us/mem/intune/protect/antivirus-microsoft-defender-settings-windows
            
            $requiredAge = 2
            $activeProtectionAvailable = (($s.OnAccessProtectionEnabled) -and ($s.RealTimeProtectionEnabled))
            $requiredEnginesAvailable = (($s.IoavProtectionEnabled) -and ($s.BehaviorMonitorEnabled) -and ($s.AntivirusEnabled) -and ($s.AMServiceEnabled) -and ($s.AntispywareEnabled) -and ($s.NISEnabled))

            $requiredEnginesUptoDate = (($s.AntivirusSignatureAge -le $requiredAge) -and ($s.AntispywareSignatureAge -le $requiredAge) -and ($s.NISSignatureAge -le $requiredAge))
            
            if ($activeProtectionAvailable -and $requiredEnginesAvailable -and $requiredEnginesUptoDate) {
                if ([MP_COMPUTER_STATE].GetEnumName($s.ComputerState) -eq "Clean") {
                $healthState = "Healthy"
                }
                else {
                $healthState = "Warning"
                }
            }
            elseif ($activeProtectionAvailable -and $requiredEnginesAvailable) {
                $healthState = "Warning"
                $healthDetails += "definitions are out of date, "
            }
            else {
                $healthState = "Error"
                if ($s.QuickScanAge -gt $requiredAge) { $healthDetails += " last quick scan was $($s.QuickScanAge) days ago, " }
                if ($s.AntivirusSignatureAge -gt $requiredAge) { $healthDetails += " last antivirus signature update was $($s.AntivirusSignatureAge) days ago, " }
                if ($s.AntispywareSignatureAge -gt $requiredAge) { $healthDetails += " last anti-spyware signature update was $($s.AntispywareSignatureAge) days ago, " }
                if ($s.NISSignatureAge -gt $requiredAge) { $healthDetails += " last network inspection signature update was $($s.NISSignatureAge) days ago, " }
            }
            if ([MP_COMPUTER_STATE].GetEnumName($s.ComputerState) -ne "Clean") { $overallState += ", defender state is : $([MP_COMPUTER_STATE].GetEnumName($s.ComputerState))" }
            $strNeedtoEnable = ""
            if (!$s.RealTimeProtectionEnabled) { $strNeedtoEnable += "real-time protection, " }
            if (!$s.OnAccessProtectionEnabled) { $strNeedtoEnable += "on-access protection, " }
            if (!$s.IoavProtectionEnabled) { $strNeedtoEnable += "IOAV protection, " }
            if (!$s.BehaviorMonitorEnabled) { $strNeedtoEnable += "behavior monitor, " }
            if (!$s.AntiVirusEnabled) { $strNeedtoEnable += "antivirus, " }
            if (!$s.AMServiceEnabled) { $strNeedtoEnable += "anti-malware service, " }
            if (!$s.AntiSpywareEnabled) { $strNeedtoEnable += "anti-spyware, " }
            if (!$s.NISEnabled) { $strNeedtoEnable += "network inspection, " }
            if ($strNeedtoEnable.Length -gt 0) {
                $healthDetails += ", need to enable $($strNeedtoEnable.TrimEnd(", "))"
            }
            if (!$s.IsTamperProtected) {
                    $healthDetails += "recommend turning on tamper protection, "
            }
            if ($s.FullScanAge -gt 14 -or $null -ne $s.FullScanEndTime) {
                    $healthDetails += "recommend running a full system scan, "
            }
            $computerNameResolved = $s.PSComputerName
            $computerLastUpdated = $([array] $s.AntispywareSignatureAge,$s.AntispywareSignatureAge,$s.NISSignatureAge | measure -maximum).Maximum
        }
    }
    catch {
        $healthDetails += "$($_) $($_.ScriptStackTrace)".Replace("`r`n","")
    }

    $healthDetails = $healthDetails.TrimEnd(", ")
    
    if ($null -eq $computerNameResolved) { $computerNameResolved = $computerName }

    if ($s -ne $null) {
        Write-Log "{" 
        Write-Log "`tComputer name : $($computerNameResolved), id : $($s.ComputerID)"
        Write-Log "`tComputer state : $($s.ComputerState), $([MP_COMPUTER_STATE].GetEnumName($s.ComputerState))"
        Write-Log "`tHealth state: $($healthState)"
        Write-Log "`tHealth details: $($healthDetails)"
        Write-Log "`tProduct version : $($s.AMProductVersion)"
        Write-Log "`tService version : $($s.AMServiceVersion)"
        Write-Log "`tEngine version : $($s.AMEngineVersion)"
        Write-Log "`tAntivirus enabled : $($s.AntiVirusEnabled)"
        Write-Log "`tAntimalware enabled : $($s.AMServiceEnabled)"
        Write-Log "`tAntispyware enabled : $($s.AntispywareEnabled)"
        Write-Log "`tNetwork inspection (NIS) enabled : $($s.NISEnabled)"
        Write-Log "`tIOV protection enabled : $($s.IoavProtectionEnabled)"
        Write-Log "`tBehavior monitor enabled : $($s.BehaviorMonitorEnabled)"
        Write-Log "`tOn access protection enabled : $($s.OnAccessProtectionEnabled)"
        Write-Log "`tReal time protection enabled : $($s.RealTimeProtectionEnabled)"
        Write-Log "`tIs tamper protected : $($s.IsTamperProtected)"
        Write-Log "`tQuick scan age : $($s.QuickScanAge)"
        Write-Log "`tFull scan age : $($s.FullScanAge)"
        Write-Log "`tAntivirus signature age : $($s.AntivirusSignatureAge), version : $($s.AntivirusSignatureVersion)"
        Write-Log "`tAntispyware signature age : $($s.AntispywareSignatureAge), version : $($s.AntispywareSignatureVersion)"
        Write-Log "`tNetwork inspection (NIS) signature age : $($s.NISSignatureAge), version : $($s.NISSignatureVersion)"
        Write-Log "}" 
    }
    else {
        Write-Log "{" 
        Write-Log "`tComputer name: $($computerNameResolved)"
        Write-Log "`tHealth state: $($healthState)"
        Write-Log "`tHealth details: $($healthDetails)"
        Write-Log "}" 
    }
    $p = @{
            'ComputerName'=$computerNameResolved
            'HealthState'=$healthState
            'HealthDetails'=$healthDetails
            'LastUpdated'= $computerLastUpdated
    }
    $result = New-Object -TypeName PSObject -Prop $p
    return $result
}

enum MP_COMPUTER_STATE {
  Clean = 0
  PendingFullScan = 1
  PendingReboot = 2
  PendingManualSteps = 4
  PendingOfflineScan = 8
  PendingCriticalFailure = 16
}

Function Get-DnsInfo {
  param($computerName)
  
  $hostnames = new-object System.Collections.Generic.HashSet[string]
  $hostaddr = new-object System.Collections.Generic.HashSet[System.Net.IPAddress]

  $entries = [System.Net.Dns]::GetHostEntry("$($computerName)")
  foreach($e in $entries) {
    foreach($a in $e.AddressList) {
      try {
        $s = [System.Net.Dns]::GetHostEntry($a)
        $_ = $hostnames.Add($s.HostName)
        foreach($i in $s.AddressList) {
          $_ = $hostaddr.Add($i)
        }
      }
      catch {}
    }
  }
  $p = @{
          'HostNames'=$hostnames
          'AddressList'=$hostaddr
  }
  $result = New-Object -TypeName PSObject -Prop $p
  return $result
}

function Find-VBRCredentials {
  param($Filter, $FilterType)
  
  $credentials = Get-VBRCredentials
  $result = @()
  foreach($c in $credentials) {
    if (($c.UserName -like $Filter -and $FilterType.ToLower() -eq "name") -or ($c.DomainName -like $Filter -and $FilterType.ToLower() -eq "domain")) { $userSelected = $true}
    if ($null -eq $filter) { $userSelected = $true }
    if ($userSelected) {
        $cred = [veeam.backup.core.cdbcredentials]::Get([system.guid]::new("$($c.Id)"))
        $pwd = $cred.Info.Credentials.GetEncryptedPassword()
        $decoded = [Veeam.Backup.Common.CStringCoder]::Decode($pwd,$true)
        if ($decoded.Length -gt 0) {
            $secpwd = ConvertTo-SecureString $decoded -AsPlainText -Force
        }
        $p = @{
          'Username'=$cred.Info.Credentials.UserName
          'UsernameAtNotation'=$cred.Info.Credentials.UserNameAtNotation
          'UsernameSlashNotation'=$cred.Info.Credentials.UserNameSlashNotation
          'Password'= $secpwd
        }
        $result += New-Object -TypeName PSObject -Prop $p
    }
  }
  return $result
}

Export-ModuleMember -Function Write-Log, Get-VBRSessionTaskStatus, Write-VBRSessionLog, Update-VBRSessionTask, Complete-VBRSessionTask, New-VBRSessionTask, Get-MPHealthState, Find-VBRCredentials, Get-VBRCredentials, Get-DecryptedString, Get-DnsInfo