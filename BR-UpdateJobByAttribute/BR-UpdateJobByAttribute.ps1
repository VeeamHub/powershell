# Johan Huttenga, Olivier Rossi, 20180611

$Version = "0.1.0.0"
$MaxSizePerJobGb = 10240
$MaxObjectsPerJob = 300

$VBRViPolicyAttribute = "VRA_Backup"
$VBRViPolicyTemplate = "Daily_Backup_7i"

$ImportFunctions = { 
Add-PSSnapin VeeamPSSnapin > $null
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false
Import-Module VMware.PowerCLI > $null
Import-Module "C:\Scripts\BR-UpdateJobByAttribute\BR-UpdateJobByAttributeModule" > $null
Connect-VBRServer > $null
}

Invoke-Command -ScriptBlock $ImportFunctions -NoNewScope | Out-Null

Write-Log $("="*78)
Write-Log "{"
Write-Log "`tScript: $($MyInvocation.MyCommand.Name)"
Write-Log "`tVersion: { $($Version) }"
Write-Log "}"

$viservers = Get-VBRViServerConfig
$vivms = $()
foreach($k in $viservers.Keys)
{
    Add-VIConnection -Server $viservers[$k].Name -Credential $viservers[$k].Credential | Out-Null
    $vivms += Get-ViAttributeVMs -Server $viservers[$k].Name -Attribute $VBRViPolicyAttribute -Value "yes"
}

if (($vivms -eq $null) -or ($vivms.Count -eq 0)) {
    Write-Log "Error: Unable to query virtual machine information. This script requires rights elevation to work. Cannot continue."
    return
}

$vbrvms = Get-VBRViJobVMs
$job = $null
$removalcount = 0
$additioncount = 0
$movecount = 0
$newcount = 0

foreach($k in $vbrvms.Keys) {
    $vm = $vbrvms[$k]
    if (!$vivms.ContainsKey($k)) {
        if ($job -eq $null -or $job.Id -ne $vm.ParentJobId) { $job = [Veeam.Backup.Core.CBackupJob]::Get($vm.ParentJobId) }
        if (!($job.Name -like "*template*") -and (!$job.IsRunning)) {
            ## remove vms that no longer exist
            $removalcount++;
            Write-Log "- Removing VM $($vm.Name) from job $($job.Name) ($($job.Id)) as it no longer exists or no longer needs to be protected."
            Update-VBRViJobVMs -Job $job -Remove $vm
        }
    }
}
foreach($k in $vivms.Keys) {
    $vm = $vivms[$k]
    if (!$vbrvms.ContainsKey($k)) {
        ## add vms thave have been newly created
        $newcount++;
        $additioncount++;
        Update-VBRViJobVMs -Add $vm -JobSizeLimit $MaxSizePerJobGb -JobObjectLimit $MaxObjectsPerJob -PolicyTag $VBRViPolicyTemplate -ViVmCache $vivms
    }
}
if ($removalcount -eq 0 -and $additioncount -eq 0) {
    Write-Log "Found $($vbrvms.Count)/$($vivms.Count) virtual machines in backup jobs. No changes were required."
}
else {
    Write-Log "Found $($vbrvms.Count)/$($vivms.Count) virtual machines in backup jobs."
    Write-Log "$($removalcount) virtual machines were removed."
    Write-Log "$($additioncount) virtual machines were added."
}