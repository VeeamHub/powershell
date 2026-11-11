# Johan Huttenga, 20220308

Param([string] $JobId, [string] $SessionId)

$Version = "0.0.0.1"

$ImportFunctions = { 
      Import-Module Veeam.Backup.PowerShell
      Import-Module "C:\Scripts\BR-MPPreJobStatus\BR-MPPreJobModule.psm1" -Force > $null
}

Invoke-Command -ScriptBlock $ImportFunctions -NoNewScope

Write-Log $("="*78)
Write-Log "{"
Write-Log "`tScript: $($MyInvocation.MyCommand.Name)"
Write-Log "`tVersion: { $($Version) }"
Write-Log "}"

# attaching to Veeam Backup and Replication job

# load necessary objects in memory
$servers = Get-VBRServer

$job = [Veeam.Backup.Core.CBackupJob]::Get([System.Guid]::new($jobid))
if ($job -eq $null) { Write-Log "Error: Cannot continue. Job ($($jobid)) not found."; return }

$session = [Veeam.Backup.Core.CBackupSession]::Get([System.Guid]::new($sessionid))
if ($session -eq $null) { Write-Log "Error: Cannot continue. Session ($($sessionid)) not found."; return }

Write-Log "Attaching to $($job.Name) ($($jobid)) session ($($sessionid))."
$taskinfo = Write-VBRSessionLog -Session $session -Text "Executing pre-job script: Child script running in background."

# getting health status per machine in job and outputing to job session log
$objects = $job.GetObjectsInJob() # could also use vioijs / hvoijs / desktopoijs

$output = "Getting Windows Defender health state for objects in job."
Write-Log $output
Update-VBRSessionTask -Session $session -RecordId $taskinfo[0].RecordId -Text "Executing pre-job script: $($output)" -Status "None"
$taskstatus = "Success"
$taskstatustext = ""
try {
  foreach($o in $objects) { 
    $dnsinfo = Get-DnsInfo $o.Name 
    if ($null -ne $dnsinfo) {
      
      $localDomain = $(Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem | Select Domain).Domain
      
      # pick first fqdn available if possible
      $computerName = $o.Name
      $computerHasLocalDomain = $false

      foreach($hn in $dnsinfo.HostNames) { if ($hn.ToLower().Contains($localDomain.ToLower())) { $computerHasLocalDomain = $true; $computerName = $hn; break; } }
      if(!$computerHasLocalDomain) { foreach($hn in $dnsinfo.HostNames) { if ($hn.Contains(".")) { $computerName = $hn; break; } } }

      $_substatus = "Failed"
      $_substatustext = "" 
      if ($computerName -eq "." -or $computerName -eq "localhost") {
        $h = Get-MPHealthState -ComputerName $computerName
      }
      else
        {
          # see if there is a stored credential we can access
          $domain = $computerName.Split('.')[1]
          if ($null -eq $domain -or $domain.Length -eq 0) { # cannot find domain associated
            $domain = $localDomain # try with local domain credentials
          }
          $creds = Find-VBRCredentials -Filter $domain -FilterType "Domain"
          if ($null -ne $creds) {
            $c = New-Object System.Management.Automation.PSCredential ($creds[0].UserName, $creds[0].Password) 
            $h = Get-MPHealthState -ComputerName $computerName -Credential $c
          }
          else {
            $_substatustext = "$($computerName): Cannot find valid credentials to use. Did not query Windows Defender status."
            Write-Log $_substatustext
          }
        }
      }
      if ($h.healthState -eq "Healthy") { $_substatus = "Success" }
      if ($h.healthState -eq "Warning") { $_substatus = "Warning" }
      if ($_substatustext.Length -eq 0) { $_substatustext = "$($h.computerName): Windows Defender status is '$($h.healthState)', last updated $($h.lastUpdated) days ago, $($h.healthDetails)" }
      Write-VBRSessionLog -Session $session -Text $_substatustext -Status $_substatus
    }
  $taskstatustext ="Executing pre-job script completed: Retrieved Windows Defender health state for objects in job."
}
catch {
  $taskstatus = "Failed"
  $taskerror = $_
  $taskstacktrace = $_.ScriptStackTrace.Replace("`r`n","")
  $taskstatustext = "Executing pre-job script failed with error: $($taskerror) $($taskstacktrace)"
}

Update-VBRSessionTask -Session $session -RecordId $taskinfo.RecordId -Text $taskstatustext -Status $taskstatus