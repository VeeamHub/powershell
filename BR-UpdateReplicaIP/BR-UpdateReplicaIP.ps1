# Johan Huttenga, 20180425

Param([string] $JobId, 
      [string] $SessionId)

$Version = "0.1.0.3"

$ImportFunctions = { 
      Add-PSSnapin VeeamPSSnapin > $null
      Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false
      Import-Module VMware.PowerCLI > $null
      Import-Module "C:\Scripts\BR-UpdateReplicaIp\BR-UpdateReplicaIPModule" > $null
}

Invoke-Command -ScriptBlock $ImportFunctions -NoNewScope

Write-Log $("="*78)
Write-Log "{"
Write-Log "`tScript: $($MyInvocation.MyCommand.Name)"
Write-Log "`tVersion: { $($Version) }"
Write-Log "}"

if (($jobid -eq $null) -or ($sessionid -eq $null)) { Write-Log "Error: Cannot continue. Invalid parameters given."; return }

$job = [Veeam.Backup.Core.CBackupJob]::Get([System.Guid]::new($jobid))
if ($job -eq $null) { Write-Log "Error: Cannot continue. Job ($($jobid)) not found."; return }

$failoverplan = Get-VBRFailoverPlan -Name $job.Name
if ($failoverplan -eq $null) { Write-Log "Error: Cannot continue. Failover plan ($($job.Name)) not found."; return }

$session = [Veeam.Backup.Core.CBackupSession]::Get([System.Guid]::new($sessionid))
if ($session -eq $null) { Write-Log "Error: Cannot continue. Session ($($sessionid)) not found."; return }

Write-Log "Attaching to $($job.Name) ($($jobid)) session ($($sessionid))."

$taskinfo = Write-VBRSessionLog -Session $session -Text "Executing pre-failover script: Child script running in background."

$vms = Get-VBRFailoverPlanVMs -FailoverPlan $failoverplan

#Invoke-Command -ScriptBlock $ImportFunctions -NoNewScope
#Wait-Boot -Name $vm.ReplicaName -SkipWaitForTools $true  | Out-Null

$ReipVm = {
      param($VM)
      $LogFile = "C:\Scripts\BR-UpdateReplicaIp\BR-UpdateReplicaIp-$($VM.SourceName).log"
      Write-Log $("="*78)
      Write-Log "Failover monitoring for ($($VM.ReplicaName)) started."
      Write-Log "Connecting to replica target host ($($vm.TargetHostId)) parent server $($vm.TargetParentConnectionInfo.DnsName)."
      $cred = $vm.TargetParentCredential
      $server = Add-VIConnection -Server $vm.TargetParentConnectionInfo.DnsName -Credential $cred
      Write-Log "Waiting for $($vm.ReplicaName) to boot and guest integration components to become available."
      Wait-VMBoot -Name $vm.ReplicaName | Out-Null
      Write-Log "Using VIX to to change IP addresses of $($vm.ReplicaName) based on replication job ($($vm.JobName))."
      $guestcred = $vm.GuestCredential
      Update-VMIPAddresses -VM $vm.ReplicaName -ReIpRules $vm.ReipRules -GuestCredential $guestcred
}

foreach ($vm in $vms)
{
      $LogFile = "C:\Scripts\BR-UpdateReplicaIp\BR-UpdateReplicaIp.log"
      Write-Log "Starting child monitoring process for $($vm.SourceName). See BR-UpdateReplicaIp-$($VM.SourceName).log for details."
      Start-Job -InitializationScript $ImportFunctions -ScriptBlock $ReipVm -ArgumentList $vm
}

Get-Job | Wait-Job | Receive-Job
Get-Job | Remove-Job

Update-VBRSessionTask -Session $session -RecordId $taskinfo.RecordId -Text "Executing pre-failover script: Child script completed." -Status "Success"