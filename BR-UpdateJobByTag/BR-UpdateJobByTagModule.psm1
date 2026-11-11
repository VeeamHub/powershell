# Johan Huttenga, Olivier Rossi, 20180605

$LogFile = "BR-UpdateJobByTag.log"
$CurrentPid = ([System.Diagnostics.Process]::GetCurrentProcess()).Id
$ViConnections = @{}

Function Write-Log {
    param([string]$str)      
    Write-Host $str
    $dt = (Get-Date).toString("yyyy.MM.dd HH:mm:ss")
    $str = "[$dt] <$CurrentPid> $str"
    Add-Content $LogFile -value $str
}

function Get-VBRCredential {
    param ($id)
    $cred = ([Veeam.Backup.Core.CDbCredentials]::Get([System.Guid]::new($id))).Credentials
    if ($cred -eq $null) { 
        Write-Log "Error: Unable to query credential ($($cred)). Ensure it exists and this process is run with administrator permissions."
    }
    $decoded = [Veeam.Backup.Common.CStringCoder]::Decode($cred.EncryptedPassword, $true)
    $secpwd = ConvertTo-SecureString $decoded -AsPlainText $true
    return New-Object System.Management.Automation.PSCredential($cred.UserName, $secpwd)
}

function Add-VIConnection {
    param($Server, $Credential)

    $result = $null

    if ($Credential -eq $null) {
        Write-Log "Error: Cannot connect to $server as no credentials were specified."
        return
    }

    if (!($VIConnections.ContainsKey($Server)))
    {
            Write-Log "Connecting to $Server using credentials ($($Credential.UserName))."
            $VIConnections[$Server] = Connect-VIServer $Server -Credential $Credential
            if ($VIConnections[$Server] -eq $null) {
                Write-Log "Error: A connectivity issue has occurred when connecting to $Server."
            }
    }
    else {
        $result = $VIConnections[$Server]
    }

    return $result
}

Function Get-VBRViServerConfig {
    $result = @{}
    $viservers = [Veeam.Backup.Core.Common.CHost]::FindAllVisibleByType([Veeam.Backup.Model.CDBHost+EType]::VC, $true)
    foreach($viserver in $viservers)
    {
        $viservercreds = Get-VBRCredential -Id ($($viserver.GetSoapCreds()).CredsId)
        $p = @{
            'Name'=$viserver.Name
            'Id'=$viserver.Id
            'Credential'=$viservercreds
        }
        $result[$viserver.Name] = New-Object -TypeName PSObject -Prop $p
    }
    return $result
}

Function Get-ViTagVMs {
    param($Server)
    
    $result = @{}
    $tagassignments = Get-TagAssignment
    
    foreach($tagassignment in $tagassignments) {
        $vm = $tagassignment.Entity
        $tag = $tagassignment.Tag
        if ($result.ContainsKey($vm.Name)) {
            $result[$vm.Name].Tags =  $result[$vm.Name].Tags + $tag.Category.ToString() + '/' + $tag.Name.ToString() + ';'
        }
        else {
            $vmtags = $tag.Category.ToString() + '/' + $tag.Name.ToString()+ ';'
            $p = @{
                'Name'=$vm.Name
                'Id'=$vm.Id
                'UsedSpaceGb'=$vm.UsedSpaceGb
                'Tags'=$vmtags
                'ParentHost'=$vm.VMHost
                'ParentHostId'=$vm.VMHostId
                'ParentServer'=$Server
            }
            $result[$Server + "/" + $vm.Name] = New-Object -TypeName PSObject -Prop $p
        }
    }

    return $result
}

Function Get-ViVMTagCategoryValue {
    param($VM, $TagCategory)
    $result = $null
    foreach($tag in $vm.Tags.Split(';')) {
        if ($tag -like "*$($TagCategory)/*") { $result = $tag.Replace("$TagCategory/","") }
    }
    return $result
}
Function Get-VBRViJobVMs {
    
    $result = @{}

    $jobs = [Veeam.Backup.Core.CBackupJob]::GetByType([Veeam.Backup.Model.EDbJobType]::Backup)
    if ($jobs -eq $null) {
        Write-Log "Warning: No backup job information found."
        return
    }
    foreach($job in $jobs) {
        $vms = $job.GetViOijs()
        foreach($vm in $vms)
        {
            if ($vm.IsIncluded) {
                $parentserver = $vm.Location.Split('\')[0]
                $p = @{
                    'ObjectId'=$vm.ObjectId
                    'Name'=$vm.Name
                    'ApproxSpaceStr'=$vm.ApproxSizeString
                    'ParentJob'=$job.Name
                    'ParentJobId'=$job.Id
                    'ParentServer'=$parentserver
                    'Location'=$vm.Location
                }
                $result[$parentserver + "/" + $vm.Name] = New-Object -TypeName PSObject -Prop $p
            }
        }
    }
    return $result
}

Function Get-VBRViJobSize {
    param($Job, $ViVmCache)
    foreach($jobobject in $jobobjects) {
        if ($ViVmCache -ne $null) {
            $server = $jobobject.Location.Split('/')[0]
            $k = $server + "/" + $vm.Name
            if ($ViVmCache[$k] -ne $null) { $result += $vm.UsedSpaceGb }
            else { $result += (Get-Vm -Name $vm.Name -Server $vm.ParentServer).UsedSpaceGB }
        }
        else {
            $result += (Get-Vm -Name $vm.Name -Server $vm.ParentServer).UsedSpaceGB
        }
    }
}

Function Update-VBRViJobVMs {
    param($Job = $null, $Add = $null, $Remove = $null, $JobSizeLimit = $null, $JobObjectLimit = $null, $PolicyTag =$null, $ViVmCache = $null)
    if (($Job -ne $null) -and ($Remove -ne $null)) {
        # remove vm from job
        $vm = $Remove
        $jobobjects = $job.GetViOijs()
        foreach($jobobject in $jobobjects) {
            if ($jobobject.ObjectId -eq $vm.ObjectId) { $jobobject.Delete() }
        }
        $job.Update()
    }
    if ($Add -ne $null) {
        # select job to mach the policy
        $vm = $Add
        $jobassigned = $false
        $jobindex = 0;
        $jobs = [Veeam.Backup.Core.CBackupJob]::GetByType([Veeam.Backup.Model.EDbJobType]::Backup)
        $entity = Find-VBRViEntity -Name $vm.Name -Server ([Veeam.Backup.Core.Common.CHost]::Find($vm.ParentServer))
        foreach($job in $jobs) {
            if (($job.Name -like "*$($PolicyTag)_*") -and (($job.Name -like "*template*") -eq $false)) {
                $jobindex += 1;
                if (!$job.IsRunning) {
                    $jobobjects = $job.GetViOijs()
                    $jobsize = Get-VBRViJobSize -Job $job -ViVmCache $ViVmCache
                    if (($jobobjects.Count -lt $JobObjectLimit) -and (($jobsize + $vm.UsedSpaceGb) -lt $JobSizeLimit)) {
                        Write-Log "+ Adding VM $($vm.Name) to existing job $($job.Name) ($($job.Id))."
                        $obj = Add-VBRViJobObject -Job $job -Entities $entity; $jobassigned = $true; break;
                    }
                }
            }
        }
        # otherwise create new job to match policy
        if (!$jobassigned) {
            $template = [Veeam.Backup.Core.CBackupJob]::Find($PolicyTag + "_Template");
            if ($template -eq $null) {
                Write-Log "Error: Template job ($($PolicyTag)_Template) cannot be found. Cannot clone new job for VM $($vm.Name)."
            }
            else {
                $job = $null; $jobcreated = $false; $retries = 0;
                do {
                    $jobsuffix = ($jobindex+1).ToString('000');
                    $newjobname = "$($PolicyTag)_$($jobsuffix)"
                    $jobexists = [Veeam.Backup.Core.CBackupJob]::Find($newjobname);
                    if (!$jobexists) { 
                        Write-Log "Cloning template job ($($PolicyTag)_Template) to create a new job $newjobname."
                        $job = Copy-VBRJob -Job $template -Name "$newjobname"
                        Start-Sleep 30
                        $jobcreated = ([Veeam.Backup.Core.CBackupJob]::Find($newjobname) -ne $null)
                    }
                    if (!$jobcreated) { $retries += 1; }
                }
                until ($jobcreated -eq $true -or $retries -gt 2)
                
                Write-Log "+ Adding VM $($vm.Name) to new job $($job.Name) ($($job.Id))."
                $jobobjects = $job.GetViOijs()
                foreach($jobobject in $jobobjects) {
                    $jobobject.Delete()
                }
                $obj = Add-VBRViJobObject -Job $job -Entities $entity; $jobassigned = $true;
                $job.Update()
                Enable-VBRJob -Job $job | Out-Null
            }
        }
    }
}