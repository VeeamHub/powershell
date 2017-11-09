Function Check-UACElevated {
  $myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
  $myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
  $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
  return $myWindowsPrincipal.IsInRole($adminRole)
}

Function Register-VeeamPSSnapin {
  $registered = $false
  foreach($snapin in (get-pssnapin)) { if ($snapin.Name -eq "veeampssnapin") { $registered = $true }}
  if ($registered -eq $false) { add-pssnapin veeampssnapin }
}

Function Register-Assemblies {

  $corepath = $null
  try { $corepath = [Microsoft.Win32.Registry]::GetValue("HKEY_LOCAL_MACHINE\Software\Veeam\Veeam Backup and Replication","CorePath","") }
  catch { }
  if (($corepath -eq $null) -or ($corepath -eq "")) { $corepath = "C:\Program Files\Veeam\Backup and Replication\Backup" }

  Add-Type -Path "$($corepath)\Veeam.Backup.Core.dll"
  # -- all dependencies of veeam.backup.core
  #Add-Type -Path "$regsettings.CorePath\Veeam.Backup.Common.dll"
  #Add-Type -Path "$regsettings.CorePath\Veeam.Backup.Model.dll"
  #Add-Type -Path "$regsettings.CorePath\Veeam.Backup.LicenseLib.dll"
  #Add-Type -Path "$regsettings.CorePath\Veeam.Backup.DBManager.dll"
}

Function Get-RegexMatch
{
param ([string]$license,[string]$regex,[string]$split)
  $match = [regex]::matches($license, $regex)
  $result = $null
  if ($match)
  {
	if ($match.count -gt 0)
    {
      $result = $match[0].Value.Split($split)
	  $result = $result[$result.count-1]
    }
  }
  return $result
}

Function Get-VBRHostLicenseUsage {
	param($lic)

	$socketusg = $null

	if (($lic.ViCpuCount -gt 0) -or ($lic.HvCpuCount -gt 0))
	{
		$vSphereSocketsUsed = 0
		$HyperVSocketsUsed = 0
		$vSphereSocketsUsedDetails = @()
		$HyperVSocketsUsedDetails = @()
		$licensedHosts = [Veeam.Backup.DBManager.CDBManager]::instance.LicHosts.GetLicensedHostsAll()

		foreach ($lHost in $licensedHosts)
		{
			$pHost = [Veeam.Backup.Core.Common.CHost]::FindByPhysHostId($lHost.PhysicalHostId);
			$physHost = $pHost.GetPhysicalHost()
			$socketsused = [Veeam.Backup.LicenseLib.CLicenseValidator]::CalculateUsedCpuNum($lHost,$physHost.Info,$lHost.SocketType);
			$oHost = @{
				Info = $pHost.Info
				Id = $pHost.Id
				PhysHostId = $pHost.PhysHostId
				ParentId = $pHost.ParentId
				Name = $pHost.Name
				Reference = $pHost.Reference
				Description = $pHost.Description
				Type = $pHost.Type
				ApiVersion = $pHost.ApiVersion
				IsUnavailable = $pHost.IsUnavailable
				CPUSockets = $physHost.HardwareInfo.CPUCount
				CPUCores = $physHost.HardwareInfo.CoresCount
				RAM = [math]::Ceiling($physHost.HardwareInfo.PhysicalRAMTotal / [math]::pow(1024,2))
				SocketsUsed = $socketsused
				SocketType = $lHost.SocketType
				IsLicensed = $lHost.IsLicensed
			}

			if ($lHost.SocketType.ToString() -eq "ViLicensed") {
				$vSphereSocketsUsed += $socketsused
				$vSphereSocketsUsedDetails += $oHost
			}
			if ($lHost.SocketType.ToString() -eq "HvLicensed")
			{
				$HyperVSocketsUsed += $socketsused
				$HyperVSocketsUsedDetails += $oHost
			}
		}
		$socketusg = @{
		SocketLicensingAvailable = $true
		ViSocketsLicensed = $lic.ViCpuCount
		ViSocketsUsed = $vSphereSocketsUsed
		ViSocketsUsageInfo = $vSphereSocketsUsedDetails
		HvSocketsLicensed = $lic.HvCpuCount
		HvSocketsUsed = $HyperVSocketsUsed
		HvSocketsUsageInfo = $HyperVSocketsUsedDetails
		}
	}
	else {
		$socketusg = @{ SocketLicensingUnavailable = $true }
	}

	return $socketusg
}

Function Get-VBRRentalLicenseUsage {
	param($lic)

	$rentalusg = $null

  $ViRentalVMs = $null
  $HvRentalVMs = $null
  $ViVMsUsed = 0
  $ViVMsNew = 0
  $HvVMsUsed = 0
  $HvVMsNew = 0

  $HvRentalUsage = $null
  $HvRentalDetailsUsed = $null
  $HvRentalDetailsNew = $null

  try { $licPlatformAvail = [bool]([Veeam.Backup.Model.CLicensePlatform])}
  catch {}

  # v9.5 way
  if ($licPlatformAvail)
  {
    try { $hlic = [Veeam.Backup.LicenseLib.CHostingLicense]::new($lic) }
    catch {}
    if ($hlic) {
      $ViRentalVMs = $hlic.GetManagedVms([Veeam.Backup.Model.CLicensePlatform]::Vmware)
      $HvRentalVMs = $hlic.GetManagedVms([Veeam.Backup.Model.CLicensePlatform]::HyperV)
    }
    $ViRentalUsage = [Veeam.Backup.DBManager.CDBManager]::Instance.VmLicensing.GetVmsNumbers($true, [Veeam.Backup.Common.EPlatform]::EVmware)
    $ViVMsUsed = $ViRentalUsage.NonTrialVmsCount
    $ViVMsNew = $ViRentalUsage.TrialVmsCount
    $ViRentalDetailsUsage = [Veeam.Backup.DBManager.CDBManager]::Instance.VmLicensing.GetPerVMUsageStats($true, [Veeam.Backup.Common.EPlatform]::EVmware)
    #$ViRentalDetailsUsed = [Veeam.Backup.DBManager.CDBManager]::Instance.VmLicensing.GetLicensedVmsInfos($true, [Veeam.Backup.Common.EPlatform]::EVmware)
		#$ViRentalDetailsNew = [Veeam.Backup.DBManager.CDBManager]::Instance.VmLicensing.GetLicensedVmsInfos($false, [Veeam.Backup.Common.EPlatform]::EVmware)
		$HvRentalUsage = [Veeam.Backup.DBManager.CDBManager]::Instance.VmLicensing.GetVmsNumbers($true, [Veeam.Backup.Common.EPlatform]::EHyperV)
    $HvVMsUsed = $HvRentalUsage.NonTrialVmsCount
    $HvVMsNew = $HvRentalUsage.TrialVmsCount
    $HvRentalDetailsUsage = [Veeam.Backup.DBManager.CDBManager]::Instance.VmLicensing.GetPerVMUsageStats($true, [Veeam.Backup.Common.EPlatform]::EHyperV)
    #$HvRentalDetailsUsed = [Veeam.Backup.DBManager.CDBManager]::Instance.VmLicensing.GetLicensedVmsInfos($true, [Veeam.Backup.Common.EPlatform]::EHyperV)
		#$HvRentalDetailsNew = [Veeam.Backup.DBManager.CDBManager]::Instance.VmLicensing.GetLicensedVmsInfos($false, [Veeam.Backup.Common.EPlatform]::EHyperV)
  }
  else {
    # v9.0 way
    try { $hlic = New-Object Veeam.Backup.LicenseLib.CHostingLicense($lic) }
    catch {
    }
    if ($hlic) {
      $ViRentalVMs = $hlic.GetManagedVms([Veeam.Backup.Common.EPlatform]::EVmware)
      $HvRentalVMs = $hlic.GetManagedVms([Veeam.Backup.Common.EPlatform]::EHyperV)
    }
    try {
      $ViRentalDetailsUsage = [Veeam.Backup.DBManager.CDBManager]::Instance.VmLicensing.GetPerVMUsageStats([Veeam.Backup.Common.EPlatform]::EVmware)
      $HvRentalDetailsUsage = [Veeam.Backup.DBManager.CDBManager]::Instance.VmLicensing.GetPerVMUsageStats([Veeam.Backup.Common.EPlatform]::EHyperV)
    }
    catch {
      write-host "WARNING: [RentalVMUsage] Unable to get statistics. Ensure you use the latest version of Veeam Backup & Replication." -Foreground Yellow
    }
    [System.Collections.ArrayList]$ViVMArray = @()
    foreach ($vm in $ViRentalDetailsUsage)
    {
      if ($vm.FirstBackupDate) { $dt = $vm.FirstBackupDate } else { $dt = $vm.LastBackupDate }
      #write-host $dt; $dt = [datetime]::Parse($dt);
      $ts = New-TimeSpan -start $dt -end ([datetime]::now)
      $daysallowed = [datetime]::DaysInMonth(([datetime]::now).Year,([datetime]::now).Month)
      if ($ViVMArray.Contains($vm.VmRef) -eq $false) {
        $ViVMArray.Add($vm.VmRef) | out-null
        if ($ts.Totaldays -gt $daysallowed) { $ViVMsUsed += 1 } else { $ViVMsNew += 1 }
      }
    }
    [System.Collections.ArrayList]$HvVMArray = @()
    foreach ($vm in $HvRentalDetailsUsage)
    {
      if ($vm.FirstBackupDate) { $dt = $vm.FirstBackupDate } else { $dt = $vm.LastBackupDate }
      #write-host $dt; $dt = [datetime]::Parse($dt);
      $ts = New-TimeSpan -start $dt -end ([datetime]::now)
      $daysallowed = [datetime]::DaysInMonth(([datetime]::now).Year,([datetime]::now).Month)
      if ($HvVMArray.Contains($vm.VmRef) -eq $false) {
        $HvVMArray.Add($vm.VmRef) | out-null
        if ($ts.Totaldays -gt $daysallowed) { $HvVMsUsed += 1 } else { $HvVMsNew += 1 }
      }
    }
  }

  if ($lic.IsRental) {
  $rentalusg = @{
    RentalLicensingAvailable = $true
    ViVMsLicensed = $ViRentalVMs
    ViVMsUsed = $ViVMsUsed
    ViVMsUsageInfo = $ViRentalDetailsUsage
    ViVMsNew = $ViVMsNew
    HvVMsLicensed = $HvRentalVMs
    HvVMsUsed = $HvVMsUsed
    HvVMsUsageInfo = $HvRentalDetailsUsage
    HvVMsNew = $HvVMsNew
    }
  }
  else {
  $rentalusg = @{
    RentalLicensingUnavailable = $true
    ViVMsLicensed = 0
    ViVMsUsed = $ViVMsUsed
    ViVMsUsageInfo = $ViRentalDetailsUsage
    ViVMsNew = $ViVMsNew
    HvVMsLicensed = 0
    HvVMsUsed = $HvVMsUsed
    HvVMsUsageInfo = $HvRentalDetailsUsage
    HvVMsNew = $HvVMsNew
    }
  }

	return $rentalusg
}

Function Get-VBRCloudLicenseUsage {
	param($lic)

	$cloudusg = $null
	$bCount = Get-RegexMatch -License $lic.LicenseInformation -Regex "Cloud Connect \(Backup\):\\t\d+" -Split "t"
	$rCount = $null

	if (($lic.CloudBackupCount -gt 0) -or ($lic.CloudReplicaCount -gt 0) -or ($bCount -gt 0))
	{
		$bStrategy = $null
		$rStrategy = $null
		$isUnlimited = $null
		$isEnterprise = $null
		$bUsed = $null
    $bNew = $null
    $rUsed = $null
    $rNew = $null
		$rCounters = $null
    $bUsageInfo = $null
    $rUsageInfo = $null

    $lStrategyAvail = $false
    try { $lStrategyAvail = [bool] ([Veeam.Backup.Core.CCloudBackupVmLicensingStrategy]) }
    catch {}

		if ($lStrategyAvail)
    { # v9.0 and v9.5
			$bStrategy = new-object Veeam.Backup.Core.CCloudBackupVmLicensingStrategy($lic)
			$rStrategy = new-object Veeam.Backup.Core.CCloudReplicaVmLicensingStrategy($lic)
			$isUnlimited = $bStrategy.License.IsUnlimitedCloudConnect()
			$isEnterprise = $bStrategy.License.IsCloudEnterprise()

			if ($bStrategy.Registry.PSobject.Methods.name -match "GetVMsCounters")
			{ 	# v9.5 way of getting usage data

				$bUsed = ($bStrategy.Registry.GetVmsCounters()).NonTrialVmsCount
        $bNew = ($bStrategy.Registry.GetVmsCounters()).TrialVmsCount
        $bCount = $bStrategy.LicenseCounters.LicensedVmAmount
				$rUsed = ($rStrategy.Registry.GetVmsCounters()).NonTrialVmsCount
        $rNew = ($rStrategy.Registry.GetVmsCounters()).TrialVmsCount
				$rCount = $rStrategy.LicenseCounters.LicensedVmAmount

        $bUsageInfo = $bStrategy.Registry.GetTenantVmCounts()
        $rUsageInfo = $rStrategy.Registry.GetTenantVmCounts()

			}
			elseif ($bStrategy.Registry.PSobject.Methods.name -match "GetCurrentEnabledVmsNumber")
			{	# v9.0 way of getting usage data
        # [TBD]
        $bNew = 0
        $bUsed = $bStrategy.Registry.GetCurrentEnabledVmsNumber()
				$bCount = $rStrategy.License.GetLicensedVmNumber()
        $rNew = 0
        $rUsed = $rStrategy.Registry.GetCurrentEnabledVmsNumber()
        $rCount = $rStrategy.License.GetLicensedVmNumber()

        $bUsageInfo = $bStrategy.Registry.GetTenantVmCounts()
        $rUsageInfo = $rStrategy.Registry.GetTenantVmCounts()
			}

      if (($lic.CloudBackupCount) -and (!$bCount)) { $bCount = $lic.CloudBackupCount }
  		if (($lic.CloudReplicaCount) -and (!$rCount)) { $rCount = $lic.CloudReplicaCount }

      $cloudusg = @{
      CloudLicensingAvailable = $true
      CCBackupLicensed = $bCount
      CCBackupUsed = $bUsed
      CCBackupNew = $bNew
      CCBackupUsageInfo = $bUsageInfo
      CCReplicaLicensed = $rCount
      CCReplicaUsed = $rUsed
      CCReplicaNew = $rNew
      CCReplicaUsageInfo = $rUsageInfo
      CCIsUnlimited = $isUnlimited
      CCIsEnterprise = $isEnterprise
      }

		}
		else { # v8.0

      # v8.0 way of getting usage data
      # [TBD] unsupported for now
      write-host "WARNING: [CloudVMUsage] Unable to get statistics. Ensure you use the latest version of Veeam Backup & Replication." -Foreground Yellow

      $cloudusg = @{
      CloudLicensingAvailable = $true
      CCBackupLicensed = $bCount
      CCBackupUsed = $bUsed
      CCBackupNew = $bNew
      CCBackupUsageInfo = $bUsageInfo
      CCIsUnlimited = $isUnlimited
      CCIsEnterprise = $isEnterprise
      }

		}
	}
	else {
		$cloudusg = @{ CloudLicensingUnavailable = $true }
	}
	return $cloudusg
}

function Get-VBRAgentLicenseUsage
{
	param($lic)
  $agentusg = @()
  $agentlics = $null

  if ([Veeam.Backup.DBManager.CDBManager]::Instance.PSobject.Methods.name -match "AgentLicenses") {

  $agentlics = [Veeam.Backup.DBManager.CDBManager]::Instance.AgentLicenses.GetAll()

  $awinwkused = [Veeam.Backup.DBManager.CDBManager]::Instance.LicAgents.GetLicensedAgentsCount([Veeam.Backup.Common.EPlatform]::EEndPoint,[Veeam.Backup.Model.Endpoint.EEpLicenseMode]::Workstation)
  $awinsvused = [Veeam.Backup.DBManager.CDBManager]::Instance.LicAgents.GetLicensedAgentsCount([Veeam.Backup.Common.EPlatform]::EEndPoint,[Veeam.Backup.Model.Endpoint.EEpLicenseMode]::Server)
  $alinwkused = [Veeam.Backup.DBManager.CDBManager]::Instance.LicAgents.GetLicensedAgentsCount([Veeam.Backup.Common.EPlatform]::ELinuxPhysical,[Veeam.Backup.Model.Endpoint.EEpLicenseMode]::Workstation)
  $alinsvused = [Veeam.Backup.DBManager.CDBManager]::Instance.LicAgents.GetLicensedAgentsCount([Veeam.Backup.Common.EPlatform]::ELinuxPhysical,[Veeam.Backup.Model.Endpoint.EEpLicenseMode]::Server)

  }

  foreach ($alic in $agentlics)
  {
    $alicinfo = Get-RegexMatch -License $alic.LicenseText -Regex "License information\=[\w+\(+\)+\-+\:+ +\\+]+" -Split "="
    $issuedate = Get-RegexMatch -License $alic.LicenseText -Regex "Issue date\=\d{1,2}\/\d{1,2}\/\d{1,4}" -Split "="
    $expirydate = Get-RegexMatch -License $alic.LicenseText -Regex "Expiration date\=\d{1,2}\/\d{1,2}\/\d{1,4}" -Split "="
    $expiryinfo = $expirydate -split '/'
    $expirydate = Get-Date -Day $expiryinfo[0] -Month $expiryinfo[1] -Year $expiryinfo[2]
    $daysleft = ($expirydate - (get-date)).Totaldays.toString().split(",")[0]

    $awinwklicensed = [int]($(Get-RegexMatch -License $alicinfo -Regex "Agent for Windows \(Workstation\):\\t\d+" -Split "t"))
    $awinsvlicensed = [int]($(Get-RegexMatch -License $alicinfo -Regex "Agent for Windows \(Server\):\\t\d+" -Split "t"))
    $alinwklicensed = [int]($(Get-RegexMatch -License $alicinfo -Regex "Agent for Linux \(Workstation\):\\t\d+" -Split "t"))
    $alinsvlicensed = [int]($(Get-RegexMatch -License $alicinfo -Regex "Agent for Linux \(Server\):\\t\d+" -Split "t"))

    $agentusg += @{
      ProductName = Get-RegexMatch -License $alic.LicenseText -Regex "Product\=[\w ]+" -Split "="
      ProductVersion =  Get-RegexMatch -License $alic.LicenseText -Regex "Version\=[\w\. ]+" -Split "="
      LicenseType = Get-RegexMatch -License $alic.LicenseText -Regex "License type\=[\w\. ]+" -Split "="
      Company = Get-RegexMatch -License $alic.LicenseText -Regex "Company\=[\w\. ]+" -Split "="
      Contact = $(Get-RegexMatch -License $alic.LicenseText -Regex "First name\=[\w\. ]+" -Split "=") + " " + $(Get-RegexMatch -License $alic.LicenseText -Regex "Last name\=[\w\. ]+" -Split "=")
      AgentLicensingAvailable = $true
      AgentWinWkstnLicensed = $awinwklicensed + 0
      AgentWinSrvrLicensed = $awinsvlicensed + 0
      AgentLinWkstnLicensed =  $alinwklicensed + 0
      AgentLinSrvrLicensed = $alinsvlicensed + 0
      AgentWinWkstnUsed = $awinwkused + 0
      AgentWinSrvrUsed = $awinsvused + 0
      AgentLinWkstnUsed =  $alinwkused + 0
      AgentLinSrvrUsed = $alinsvused + 0
      IssueDate = $issuedate
      ExpirationDate = $expirydate
      DaysLeft = $daysleft
    }

  }

	if (($lic.AgentWinWorkstationCount -gt 0) -or ($lic.AgentWinServerCount -gt 0) -or ($lic.AgentLinWorkstationCount -gt 0) -or ($lic.AgentLinServerCount -gt 0)) {

  	$agentusg += @{
        ProductName = $lic.ProductName
        ProductVersion = $lic.ProductVersion
        LicenseType = $lic.LicenseType
        Company = $lic.Company
        Contact = $lic.ContactPerson
    		AgentLicensingAvailable = $true
    		AgentWinWkstnLicensed = $lic.AgentWinWorkstationCount
    		AgentWinSrvrLicensed = $lic.AgentWinServerCount
    		AgentLinWkstnLicensed = $lic.AgentLinWorkstationCount
    		AgentLinSrvrLicensed = $lic.AgentLinServerCount
        AgentWinWkstnUsed = $awinwkused + 0
        AgentWinSrvrUsed = $awinsvused + 0
        AgentLinWkstnUsed =  $alinwkused + 0
        AgentLinSrvrUsed = $alinsvused + 0
        IssueDate = $lic.IssueDate
        ExpirationDate = $lic.ExpirationDate
        DaysLeft = $lic.DaysLeft
  	 }
     $agentusg += $agentusgobj
  }

  if ($agentusg.Count -eq 0)
  {
    $agentusg += @{
      AgentLicensingUnavailable = $true
    }
  }

	return $agentusg
}

Function Get-VBRLicenseUsage {

$elevated = Check-UACElevated
if ($elevated -eq $false) { Write-Host "Error: Administrator access required (UAC elevation). Unable to continue."; break }
Register-VeeamPSSnapin
Register-Assemblies

$lic = [Veeam.Backup.LicenseLib.CLicense]::LoadLicFromRegistry()

# get per-socket (perpetual) usage
$socketusg = Get-VBRHostLicenseUsage($lic)

# get per-vm (rental) usage
$rentalusg = Get-VBRRentalLicenseUsage($lic)

# get per-vm (cloud) usage
$cloudusg = Get-VBRCloudLicenseUsage($lic)

# get per-agent (physical) usage
$agentusg = Get-VBRAgentLicenseUsage($lic)


$objoutput = @{
ProductName = $lic.ProductName
ProductEdition = $lic.Edition
ProductVersion = $lic.ProductVersion
LicenseType = $lic.LicenseType
LicensePlan = $lic.Plan
Company = $lic.Company
Contact = $lic.ContactPerson
PerHostSocketUsage = $socketusg
PerAgentUsage = $agentusg
PerVMRentalUsage = $rentalusg
PerVMCloudUsage = $cloudusg
GracePeriodActive = $lic.IsInGracePeriod
GracePeriodExpired = $lic.IsGracePeriodExpired
GracePeriodDaysLeft = $lic.GracePeriodDaysLeft
IssueDate = $lic.IssueDate
ExpirationDate = $lic.ExpirationDate
DaysLeft = $lic.DaysLeft
}

$objoutput

}

$licusage = Get-VBRLicenseUsage
$licusage

$div = "-"*18
$xdiv = " " + "-"*35
Write-Host "`r`nPerHostSocketUsage"
Write-Host $div
$licusage.PerHostSocketUsage

if($licusage.PerHostSocketUsage.SocketLicensingAvailable)
{
  Write-Host "`r`n [PerHostSocketUsage.ViSocketsUsageInfo]"
  Write-Host $xdiv
  $licusage.PerHostSocketUsage.ViSocketsUsageInfo
  Write-Host "`r`n [PerHostSocketUsage.HvSocketsUsageInfo]"
  Write-Host $xdiv
  $licusage.PerHostSocketUsage.HvSocketsUsageInfo
}

Write-Host "`r`nPerAgentUsage"
Write-Host $div
foreach($agentusg in $licusage.PerAgentUsage) { $agentusg; }

Write-Host "`r`nPerVMRentalUsage"
Write-Host $div
$licusage.PerVMRentalUsage

if ($licusage.PerVMRentalUsage.RentalLicensingAvailable) {
  Write-Host "`r`n [PerVMRentalUsage.ViVMsUsageInfo]"
  Write-Host $xdiv
  $licusage.PerVMRentalUsage.ViVMsUsageInfo
  Write-Host "`r`n [PerVMRentalUsage.HvVMsUsageInfo]"
  Write-Host $xdiv
  $licusage.PerVMRentalUsage.HvVMsUsageInfo
}

Write-Host "`r`nPerVMCloudUsage"
Write-Host $div
$licusage.PerVMCloudUsage

if ($licusage.PerVMCloudUsage.CloudLicensingAvailable) {
  Write-Host "`r`n [PerVMCloudUsage.CCBackupUsageInfo]"
  Write-Host $xdiv
  $licusage.PerVMCloudUsage.CCBackupUsageInfo
  Write-Host "`r`n [PerVMCloudUsage.CCReplicaUsageInfo]"
  Write-Host $xdiv
  $licusage.PerVMCloudUsage.CCReplicaUsageInfo
}
