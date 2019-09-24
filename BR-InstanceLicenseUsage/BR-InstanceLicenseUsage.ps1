#Validate user is an Administrator
Write-Verbose "Checking Administrator credentials"
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
      [Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Warning "You are not running this as an Administrator!`nRe-running script and will prompt for administrator credentials."
  Start-Process -Verb "Runas" -File PowerShell.exe -Argument "-STA -noprofile -file $($myinvocation.mycommand.definition)"
  Break
}

Function Get-VBRInstanceLicenseUsage {
  $LicensedObjects = Get-WmiObject -Namespace Root\VeeamBS -Class LicenseConsumingObject

  [System.Collections.ArrayList]$AllLicensedObjects = @()

  foreach ($LicensedObject in $LicensedObjects) {

    switch ($LicensedObject.Platform) {
      0 { $ObjectType = 'VMware_VM' }
      1 { $ObjectType = 'HyperV_VM' }
      6 { $ObjectType = 'Windows_Agent' }
      7 { $ObjectType = 'Linux_Agent' }
    }

    $ObjectOutputResult = [pscustomobject][ordered] @{
      'ObjectType' = $ObjectType
      'Weight'     = $LicensedObject.Weight
    }

    $AllLicensedObjects.Add($ObjectOutputResult) | Out-Null

  }

  $LicensedObjectsGroup = $AllLicensedObjects | Group-Object -Property ObjectType

  $param = @{
    Property = @{N = "ObjectType"; E = { $_.Name } },
    @{N = "ObjectCount"; E = { $_.Count } },
    @{N = "LicenseUsage"; E = { ($_.Group | Measure-Object -Property Weight -Sum).Sum } }
  }

  Write-Output $LicensedObjectsGroup | Select-Object @param

}

Function Get-VBRInstanceLicenseUsageDetails {

  $LicensedObjects = Get-WmiObject -Namespace Root\VeeamBS -Class LicenseConsumingObject

  Add-PSSnapin -Name VeeamPSSnapIn

  [System.Collections.ArrayList]$AllVMs = @()

  $CIMVMs = Get-WmiObject -Namespace Root\VeeamBS -Class Vm

  foreach ($CIMVM in $CIMVMs) {
    $VMOutputResult = [pscustomobject][ordered] @{
      'Name'        = $CIMVM.Name
      'InstanceUid' = $CIMVM.InstanceUid
      'Platform'    = $CIMVM.Platform
    }

    $AllVMs.Add($VMOutputResult) | Out-Null

  }

  [System.Collections.ArrayList]$AllDiscoveredComputers = @()

  $DiscoveredComputers = Get-VBRDiscoveredComputer | Select-Object Name, ObjectId

  foreach ($DiscoveredComputer in $DiscoveredComputers) {

    $DiscoveredComputerOutputResult = [pscustomobject][ordered] @{
      'Name'     = $DiscoveredComputer.Name
      'ObjectId' = $DiscoveredComputer.ObjectId
    }

    $AllDiscoveredComputers.Add($DiscoveredComputerOutputResult) | Out-Null

  }

  [System.Collections.ArrayList]$AllLicensedObjects = @()

  foreach ($LicensedObject in $LicensedObjects) {

    switch ($LicensedObject.Platform) {
      0 { $ObjectType = 'VMware_VM' }
      1 { $ObjectType = 'HyperV_VM' }
      6 { $ObjectType = 'Windows_Agent' }
      7 { $ObjectType = 'Linux_Agent' }
    }

    if ($ObjectType -like "*VM") {
      $Name = $AllVMs | Where-Object { $_.InstanceUid -eq $LicensedObject.ObjectId } | Select-Object -ExpandProperty Name
    }
    elseif ($ObjectType -like "*Agent") {
      $Name = $AllDiscoveredComputers | Where-Object { $_.ObjectId -eq $LicensedObject.ObjectId } | Select-Object -ExpandProperty Name
    }

    $ObjectOutputResult = [pscustomobject][ordered] @{
      'Name'                = $Name
      'ObjectType'          = $ObjectType
      'ObjectId'            = $LicensedObject.ObjectId
      'RegistrationTimeUtc' = $LicensedObject.RegistrationTimeUtc
      'Weight'              = $LicensedObject.Weight
    }


    $AllLicensedObjects.Add($ObjectOutputResult) | Out-Null

  }

  Write-Output $AllLicensedObjects

  Disconnect-VBRServer

}

function Get-VBRLicenseDetails {
  $License = Get-WmiObject -Namespace Root\VeeamBS -ClassName License

  $LicenseSupportExpiration = $License.SupportExpirationDate -replace '000000.000000-360'
  $SupportExpiration = [datetime]::parseexact($LicenseSupportExpiration, 'yyyyMMdd', $null)
  $SupportExpirationDate = Get-Date $SupportExpiration -UFormat "%D"

  $LicenseDetails = [pscustomobject][ordered] @{
    'Edition'               = $License.Edition
    'LicenseType'           = $License.LicenseType
    'Plan'                  = $License.Plan
    'LicensedTo'            = $License.LicensedTo
    'ExpirationDate'        = $License.ExpirationDate
    'Status'                = $License.Status
    'IsSupportExpired'      = $License.IsSupportExpired
    'SupportExpirationDate' = $SupportExpirationDate
  }

  Write-Output $LicenseDetails
}