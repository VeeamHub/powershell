

<#
    Version cmdlets
#>
function Get-VHMVersion {
	return (Get-Module VeeamHubModule).Version.ToString()
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
    Generic functions
#>
function Get-VHMVBRWinServer {
    return [Veeam.Backup.Core.CWinServer]::GetAll($true)
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

function Remove-VHMVBRTrafficRule {
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


<#
    Guest interaction proxies
    //Implementing hacks from Tom Sightler on :  https://forums.veeam.com/powershell-f26/set-guest-interaction-proxy-server-t35234.html#p272191
#>


function Add-VHMVBRViGuestProxy {
    param(
        [Parameter(Mandatory=$True)][Veeam.Backup.Core.CBackupJob]$job,
        [Parameter(Mandatory=$True)][Veeam.Backup.Core.CWinServer[]]$proxies= $null
    )  
    $gipspids = [Veeam.Backup.Core.CJobProxy]::GetJobProxies($job.id) | ? { $_.Type -eq "EGuest" } | % { $_.ProxyId }
    foreach($proxy in $proxies) {
            if($proxy.Id -notin $gipspids) {
                [Veeam.Backup.Core.CJobProxy]::Create($job.id,$proxy.Id,"EGuest")
            }
    }
}
function Remove-VHMVBRViGuestProxy {
    param(
        [Parameter(Mandatory=$True)][Veeam.Backup.Core.CBackupJob]$job,
        [Parameter(Mandatory=$True)][Veeam.Backup.Core.CWinServer[]]$proxies= $null
    )    
    $gips = [Veeam.Backup.Core.CJobProxy]::GetJobProxies($job.id) | ? { $_.Type -eq "EGuest" }
    $pids = $proxies.id

    foreach($gip in $gips) {
        if($gip.ProxyId -in $pids) {
            [Veeam.Backup.Core.CJobProxy]::Delete($gip.id)           
        }
    } 
}
function Set-VHMVBRViGuestProxy {
    [CmdletBinding(DefaultParameterSetName='Auto')]
    param(
        [Parameter(Mandatory=$True)][Veeam.Backup.Core.CBackupJob]$job,
        [Parameter(Mandatory = $true, ParameterSetName = 'Auto')][switch]$auto,
        [Parameter(Mandatory = $true, ParameterSetName = 'Manual')][switch]$manual,
        [Parameter(Mandatory = $true, ParameterSetName = 'Manual')][Veeam.Backup.Core.CWinServer[]]$proxies= $null
    )
    if($manual) {
        $o = $job.GetVssOptions()
        $o.GuestProxyAutoDetect = $false
        $job.SetVssOptions($o)
    }
    if($auto) {
        $o = $job.GetVssOptions()
        $o.GuestProxyAutoDetect = $true
        $job.SetVssOptions($o)
    }
    if($proxies -ne $null) {
        $gips = [Veeam.Backup.Core.CJobProxy]::GetJobProxies($job.id) | ? { $_.Type -eq "EGuest" }
        $pids = $proxies.id

        foreach($gip in $gips) {
            if($gip.ProxyId -notin $pids) {
                [Veeam.Backup.Core.CJobProxy]::Delete($gip.id)           
            }
        }
        $gipspids = [Veeam.Backup.Core.CJobProxy]::GetJobProxies($job.id) | ? { $_.Type -eq "EGuest" } | % { $_.ProxyId }
        foreach($proxy in $proxies) {
            if($proxy.Id -notin $gipspids) {
                [Veeam.Backup.Core.CJobProxy]::Create($job.id,$proxy.Id,"EGuest")
            }
        }

    }
}
function Get-VHMVBRViGuestProxy {
    param(
        [Parameter(Mandatory=$True)][Veeam.Backup.Core.CBackupJob]$job
    )
    return [Veeam.Backup.Core.CJobProxy]::GetJobProxies($job.id) | ? { $_.Type -eq "EGuest" }
}


<#
    User Roles
    //Implementing hacks from Tom Sightler on : https://forums.veeam.com/powershell-f26/add-user-to-users-and-roles-per-ps-t41011.html#p271679
#>

function Add-VHMVBRUserRoleMapping {
    Param (
        [string]$UserOrGroupName, 
        [ValidateSet('Veeam Restore Operator','Veeam Backup Operator','Veeam Backup Administrator','Veeam Backup Viewer')][string]$RoleName
     )

    $CDBManager = [Veeam.Backup.DBManager.CDBManager]::CreateNewInstance()

    # Find the SID for the named user/group
    $AccountSid = [Veeam.Backup.Common.CAccountHelper]::FindSid($UserOrGroupName)

    # Detect if account is a User or Group
    If ([Veeam.Backup.Common.CAccountHelper]::IsUser($AccountSid)) {
        $AccountType = [Veeam.Backup.Model.AccountTypes]::User
    } Else {
        $AccountType = [Veeam.Backup.Model.AccountTypes]::Group
    }

    # Parse out full name (with domain component) and short name
    $FullAccountName = [Veeam.Backup.Common.CAccountHelper]::GetNtAccount($AccountSid).Value;
    $ShortAccountName = [Veeam.Backup.Common.CAccountHelper]::ParseUserName($FullAccountName);

    # Check if account already exist in Veeam DB, add if required
    If ($CDBManager.UsersAndRoles.FindAccount($AccountSid.Value)) {
        $Account = $CDBManager.UsersAndRoles.FindAccount($AccountSid.Value)
    } else {
        $Account = $CDBManager.UsersAndRoles.CreateAccount($AccountSid.Value, $ShortAccountName, $FullAccountName, $AccountType);
    }

    # Get the Role object for the named Role
    $Role = $CDBManager.UsersAndRoles.GetRolesAll() | ?{$_.Name -eq $RoleName}

    # Check if account is already assigned to Role and assign if not
    if ($CDBManager.UsersAndRoles.GetRolesByAccountId($Account.Id)) {
        write-host "Account $UserOrGroupName is already assigned to role $RoleName"
    } else {
        $CDBManager.UsersAndRoles.CreateRoleAccount($Role.Id,$Account.Id)
    }

    $CDBManager.Dispose()
}

function Remove-VHMVBRUserRoleMapping {
    Param ([string]$UserOrGroupName, 
    [ValidateSet('Veeam Restore Operator','Veeam Backup Operator','Veeam Backup Administrator','Veeam Backup Viewer')][string]$RoleName)
    $CDBManager = [Veeam.Backup.DBManager.CDBManager]::CreateNewInstance()

    # Find the SID for the named user/group
    $AccountSid = ([Veeam.Backup.Common.CAccountHelper]::FindSid($UserOrGroupName)).Value

    # Get the Veeam account ID using the SID
    $Account = $CDBManager.UsersAndRoles.FindAccount($AccountSid)

    # Get the Role ID for the named Role
    $Role = $CDBManager.UsersAndRoles.GetRolesAll() | ?{$_.Name -eq $RoleName}

    # Check if name user/group is assigned to role and delete if so
    if ($CDBManager.UsersAndRoles.GetRoleAccountByAccountId($Account.Id)) {
        $CDBManager.UsersAndRoles.DeleteRoleAccount($Role.Id,$Account.Id)
    } else {
        write-host "Account $UserOrGroupName is not assigned to role $RoleName"
    }

    $CDBManager.Dispose()
}

function Get-VHMVBRUserRoleMapping {
    $CDBManager = [Veeam.Backup.DBManager.CDBManager]::CreateNewInstance()

    $mappings = @()
    $accounts = $CDBManager.UsersAndRoles.GetAccountsAll()

    foreach( $r in ($CDBManager.UsersAndRoles.GetRolesAll())) {
        $roleaccounts = $CDBManager.UsersAndRoles.GetRoleAccountByRoleId($r.Id)
        foreach($ra in $roleaccounts) {
            $account = $accounts | ? { $ra.AccountId -eq $_.Id }
            $mappings += (New-Object -TypeName psobject -Property @{
                AccountName=$account.Nt4Name
                RoleName=$r.Name;
                RoleAccount=$ra;
                Role=$r;
                Account=$account
            })
        }
    }
    return $mappings
}

<#
gc .\veeamhubmodule.psm1 | Select-String "^function (.*) {"  | % { "Export-ModuleMember -Function {0}" -f $_.Matches.groups[1].value }
gc .\veeamhubmodule.psm1 | Select-String "^Export-ModuleMember -Function (.*)"  | % { "`t'{0}'," -f $_.Matches.groups[1].value }
#>
Export-ModuleMember -Function Get-VHMVersion
Export-ModuleMember -Function Get-VHMVBRVersion
Export-ModuleMember -Function Get-VHMVBRWinServer
Export-ModuleMember -Function Format-VHMVBRScheduleInfo
Export-ModuleMember -Function New-VHMVBRScheduleInfo
Export-ModuleMember -Function Get-VHMVBRTrafficRule
Export-ModuleMember -Function Update-VHMVBRTrafficRule
Export-ModuleMember -Function New-VHMVBRTrafficRule
Export-ModuleMember -Function Remove-VHMVBRTrafficRule
Export-ModuleMember -Function Add-VHMVBRViGuestProxy
Export-ModuleMember -Function Remove-VHMVBRViGuestProxy
Export-ModuleMember -Function Set-VHMVBRViGuestProxy
Export-ModuleMember -Function Get-VHMVBRViGuestProxy
Export-ModuleMember -Function Add-VHMVBRUserRoleMapping
Export-ModuleMember -Function Remove-VHMVBRUserRoleMapping
Export-ModuleMember -Function Get-VHMVBRUserRoleMapping