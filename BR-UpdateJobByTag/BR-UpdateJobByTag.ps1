# Johan Huttenga, Olivier Rossi, 20180605

$Version = "0.1.0.1"
$MaxSizePerJobGb = 10240
$MaxObjectsPerJob = 300

$VBRViPolicyCategory = 'Veeam Backup Policy'
$VBRViPolicyCategoryExclusion = 'No_Backup'

$ImportFunctions = { 
Add-PSSnapin VeeamPSSnapin > $null
Set-PowerCLIConfiguration -InvalidCertificateAction ignore -confirm:$false
Import-Module VMware.PowerCLI > $null
Import-Module "C:\Scripts\BR-UpdateJobByTag\BR-UpdateJobByTagModule" > $null
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
    $vivms += Get-ViTagVMs -Server $viservers[$k].Name
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
            $removaremovalcountls++;
            Write-Log "- Removing VM $($vm.Name) from job $($job.Name) ($($job.Id)) as it no longer exists in infrastructure."
            Update-VBRViJobVMs -Job $job -Remove $vm
        }
    }
    else {
        # get value for policy category tag
        $vivmbackuptag = (Get-ViVMTagCategoryValue -VM $vivms[$k] -TagCategory $VBRViPolicyCategory).Replace("Veeam_","")
        $vbrvmbackuppolicy = $vm.ParentJob.Substring(0, $vm.ParentJob.Length -4)
        # check if vm is using the correct policy based on tag
        if ($vivmbackuptag -ne $vbrvmbackuppolicy) {
            if ($job -eq $null -or $job.Id -ne $vm.ParentJobId) { $job = [Veeam.Backup.Core.CBackupJob]::Get($vm.ParentJobId) }
            if (!($job.Name -like "*template*") -and (!$job.IsRunning)) {
                ## remove vms with a tag that does not match the job they are in
                if ($vivmbackuptag -eq $VBRViPolicyCategoryExclusion) {
                    $removalcount++;
                    Write-Log "- Removing VM $($vm.Name) from job $($job.Name) ($($job.Id)) as it was manually excluded."
                    Update-VBRViJobVMs -Job $job -Remove $vm
                }
                else {
                    $movecount++;
                    $removalcount++;
                    Write-Log "- Removing VM $($vm.Name) from job $($job.Name) ($($job.Id)) as it is no longer associated with this job."
                    Update-VBRViJobVMs -Job $job -Remove $vm
                    ## add vms to the appropriate job
                    #Write-Log "Adding VM $($vm.Name) to a job for tag $($vivmbackuptag)."
                    $additioncount++;
                    Update-VBRViJobVMs -Add $vm -JobSizeLimit $MaxSizePerJobGb -JobObjectLimit $MaxObjectsPerJob -PolicyTag $vivmbackuptag -ViVmCache $vivms
                }
            }   
        }
    }
}
foreach($k in $vivms.Keys) {
    $vm = $vivms[$k]
    $vivmbackuptag = (Get-ViVMTagCategoryValue -VM $vivms[$k] -TagCategory $VBRViPolicyCategory).Replace("Veeam_","")
    if (!$vbrvms.ContainsKey($k) -and ($vivmbackuptag -ne $VBRViPolicyCategoryExclusion)) {
        ## add vms thave have been newly created
        #Write-Log "Adding VM $($vm.Name) to a job for tag $($vivmbackuptag)."
        $newcount++;
        $additioncount++;
        Update-VBRViJobVMs -Add $vm -JobSizeLimit $MaxSizePerJobGb -JobObjectLimit $MaxObjectsPerJob -PolicyTag $vivmbackuptag -ViVmCache $vivms
    }
}
if ($removalcount -eq 0 -and $additioncount -eq 0) {
    Write-Log "Found $($vbrvms.Count)/$($vivms.Count) tagged virtual machines in backup jobs. No changes were required."
}
else {
    Write-Log "Found $($vbrvms.Count)/$($vivms.Count) tagged virtual machines in backup jobs."
    Write-Log "$($removalcount) virtual machines were removed."
    Write-Log "$($additioncount) virtual machines were added."
    Write-Log "($($newcount) virtual machines were new and $($movecount) moved between jobs)"
}