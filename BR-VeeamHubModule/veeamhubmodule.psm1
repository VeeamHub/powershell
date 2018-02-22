$script:VeeamHubVersion = "0.0.1"

<#
    Version cmdlets
#>
function Get-VHMVersion {
	return $script:VeeamHubVersion
}
function Get-VHMVBRVersion {
	$versionstring = "Unknown Version"

    $pssversion = (Get-PSSnapin VeeamPSSnapin -ErrorAction SilentlyContinue)
    if ($pssversion -ne $null) {
        $versionstring = ("{0}.{1}" -f $pssversion.Version.Major,$pssversion.Version.Minor)
    }

    $corePath = Get-ItemProperty -Path "HKLM:\Software\Veeam\Veeam Backup and Replication\" -Name "CorePath" -ErrorAction SilentlyContinue
    if ($corePath -ne $null) {
        $depDLLPath = Join-Path -Path $corePath.CorePath -ChildPath "Packages\VeeamDeploymentDll.dll" -Resolve -ErrorAction SilentlyContinue
        if ($depDLLPath -ne $null -and (Test-Path -Path $depDLLPath)) {
            $file = Get-Item -Path $depDLLPath -ErrorAction SilentlyContinue
            if ($file -ne $null) {
                $versionstring = $file.VersionInfo.ProductVersion
            }
        }
    }
    $clientPath = Get-ItemProperty -Path "HKLM:\Software\Veeam\Veeam Mount Service\" -name "installationpath" -ErrorAction SilentlyContinue
    if ($clientPath -ne $null) {
        $depDLLPath = Join-Path -Path $clientPath.installationpath -ChildPath  "Packages\VeeamDeploymentDll.dll" -Resolve -ErrorAction SilentlyContinue
        if ($depDLLPath -ne $null -and (Test-Path -Path $depDLLPath)) {
            $file = Get-Item -Path $depDLLPath -ErrorAction SilentlyContinue
            if ($file -ne $null) {
                $versionstring = $file.VersionInfo.ProductVersion
            }
        }
    }
	return $versionstring
}

<#
    Schedule Info  
#>

function New-VHM24x7Array {
    param([int]$defaultvalue=0)
    $a = (New-Object 'int[][]' 7,24) 
    foreach($d in (0..6)) {
        foreach($h in (0..23)) {
            $a[$d][$h] = $defaultvalue
        }
    }
    return $a
}
function Format-VHMVBRScheduleInfo {
    param([parameter(ValueFromPipeline,Mandatory=$true)][Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]$schedule)
    $days = 'S','M','T','W','T','F','S'

    $cells = $schedule.GetCells()
    foreach($d in (0..6)) {
        write-host ("{0} | {1} |" -f $days[$d],($cells[$d] -join " | ")) 
    }
}

function New-VHMVBRScheduleInfo {
    param(
        [ValidateSet("Anytime","BusinessHours","WeekDays","Weekend","Custom","Never")]$option,
        [int[]]$hours = (0..23),
        [int[]]$days = (0..6)
    )
    $result = $null
    switch($option) {
        "Anytime" {
            $result = [Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]::CreateAllPermitted()
        }
        "BusinessHours" {
            $a = New-VHM24x7Array -defaultvalue 1
            foreach($d in (1..5)) {
                foreach($h in (8..17)) {
                    $a[$d][$h] = 0
                }
            }
            $result = [Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]::new($a)
        }
        "WeekDays" {
            $a = New-VHM24x7Array -defaultvalue 1
            foreach($d in (1..5)) {
                foreach($h in (0..23)) {
                    $a[$d][$h] = 0
                }
            }
            $result = [Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]::new($a)
        }
        "Weekend" {
            $a = New-VHM24x7Array -defaultvalue 1
            foreach($d in @(0,6)) {
                foreach($h in (0..23)) {
                    $a[$d][$h] = 0
                }
            }
            $result = [Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]::new($a)
        }
        "Custom" {
            $a = New-VHM24x7Array -defaultvalue 1
            foreach($d in $days) {
                foreach($h in $hours) {
                    $a[$d][$h] = 0
                }
            }
            $result = [Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]::new($a)
        }
        "Never" {
            $a = New-VHM24x7Array -defaultvalue 1
            $result = [Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]::new($a)
        }
    }
    return $result
}

<#
    Traffic rules
    //Implementing hacks from Tom Sightler on : https://forums.veeam.com/powershell-f26/backup-proxy-traffic-throttling-rules-t31732.html#p228501
#>

function Get-VHMVBRTrafficRule {
    param(
        $ruleId=$null
    )
    $rls = [Veeam.Backup.Core.SBackupOptions]::GetTrafficThrottlingRules().GetRules()
    if($ruleId -ne $null) {
        $rls = $rls | ? { $_.RuleId -eq $ruleId }
    }
    return $rls
}


function Update-VHMVBRTrafficRule {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline)][Veeam.Backup.Model.CTrafficThrottlingRule]$TrafficRule
    )
    #Seems like the object needs to be removed by the same instance that returned them 
    begin {
        $ttr = [Veeam.Backup.Core.SBackupOptions]::GetTrafficThrottlingRules()
        $rules = $ttr.GetRules()
    }
    process {
        $m = $rules | ? { $_.RuleId -eq $TrafficRule.RuleId } 
        if ($m -ne $null) {
            Write-Verbose ("Updated rule {0}" -f $TrafficRule.RuleId)
            $m.SpeedLimit = $TrafficRule.SpeedLimit
            $m.SpeedUnit = $TrafficRule.SpeedUnit
            $m.AlwaysEnabled = $TrafficRule.AlwaysEnabled
            $m.EncryptionEnabled = $TrafficRule.EncryptionEnabled
            $m.ThrottlingEnabled = $TrafficRule.ThrottlingEnabled
            $m.SetScheduleInfo($TrafficRule.GetScheduleInfo())
            $m.FirstDiapason.FirstIp = $TrafficRule.FirstDiapason.FirstIp
            $m.FirstDiapason.LastIp = $TrafficRule.FirstDiapason.LastIp
            $m.SecondDiapason.FirstIp = $TrafficRule.SecondDiapason.FirstIp
            $m.SecondDiapason.LastIp = $TrafficRule.SecondDiapason.LastIp
            
        } else {
            Write-Verbose ("Did not found match for {0}" -f $TrafficRule.RuleId)
        }
    }
    end {
        [Veeam.Backup.Core.SBackupOptions]::SaveTrafficThrottlingRules($ttr)
    }
}
function New-VHMVBRTrafficRule {
    param(
        [Parameter(Mandatory=$true)][ValidateScript({$_ -match [IPAddress]$_ })]$SourceFirstIp="",
        [Parameter(Mandatory=$true)][ValidateScript({$_ -match [IPAddress]$_ })]$SourceLastIp="",
        [Parameter(Mandatory=$true)][ValidateScript({$_ -match [IPAddress]$_ })]$TargetFirstIp="",
        [Parameter(Mandatory=$true)][ValidateScript({$_ -match [IPAddress]$_ })]$TargetLastIp="",
        $SpeedLimit=10,
        $SpeedUnit="Mbps",
        $AlwaysEnabled=$true,
        $EncryptionEnabled=$false,
        $ThrottlingEnabled=$true,
        [Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]$Schedule=[Veeam.Backup.Common.UI.Controls.Scheduler.ScheduleInfo]::CreateAllPermitted()
    )
    $ttr = [Veeam.Backup.Core.SBackupOptions]::GetTrafficThrottlingRules()

    # Add a new default traffic throttling rule to existing rules
    $nttr = $ttr.AddRule()

    # Set options for the new traffic throttling rule
    $nttr.SpeedLimit = $SpeedLimit
    $nttr.SpeedUnit = $SpeedUnit
    $nttr.AlwaysEnabled = $AlwaysEnabled
    $nttr.EncryptionEnabled = $EncryptionEnabled
    $nttr.ThrottlingEnabled = $ThrottlingEnabled
    $nttr.SetScheduleInfo($schedule)
    $nttr.FirstDiapason.FirstIp = $SourceFirstIp
    $nttr.FirstDiapason.LastIp = $SourceLastIp
    $nttr.SecondDiapason.FirstIp = $TargetFirstIp
    $nttr.SecondDiapason.LastIp = $TargetLastIp

    # Save new traffic throttiling rules
    [Veeam.Backup.Core.SBackupOptions]::SaveTrafficThrottlingRules($ttr)
    return $nttr
}

function Delete-VHMVBRTrafficRule {
    [cmdletbinding()]
    param(
        [parameter(ValueFromPipeline)][Veeam.Backup.Model.CTrafficThrottlingRule]$TrafficRule
    )
    #Seems like the object needs to be removed by the same instance that returned them 
    begin {
        $ttr = [Veeam.Backup.Core.SBackupOptions]::GetTrafficThrottlingRules()
        $rules = $ttr.GetRules()
    }
    process {
        $m = $rules | ? { $_.RuleId -eq $TrafficRule.RuleId } 
        if ($m -ne $null) {
            Write-Verbose ("Removed rule {0}" -f $TrafficRule.RuleId)
            $ttr.RemoveRule($m)
        } else {
            Write-Verbose ("Did not found match for {0}" -f $TrafficRule.RuleId)
        }
    }
    end {
        [Veeam.Backup.Core.SBackupOptions]::SaveTrafficThrottlingRules($ttr)
    }
}



# gc .\veeamhubmodule.psm1 | Select-String "^function (.*) {"  | % { "Export-ModuleMember -Function {0}" -f $_.Matches.groups[1].value }
# gc .\veeamhubmodule.psm1 | Select-String "^Export-ModuleMember -Function (.*)"  | % { "`t'{0}'," -f $_.Matches.groups[1].value }
Export-ModuleMember -Function Get-VHMVersion
Export-ModuleMember -Function Get-VHMVBRVersion
Export-ModuleMember -Function Format-VHMVBRScheduleInfo
Export-ModuleMember -Function New-VHMVBRScheduleInfo
Export-ModuleMember -Function Get-VHMVBRTrafficRule
Export-ModuleMember -Function Update-VHMVBRTrafficRule
Export-ModuleMember -Function New-VHMVBRTrafficRule
Export-ModuleMember -Function Delete-VHMVBRTrafficRule