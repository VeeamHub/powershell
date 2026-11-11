#region InstallOptions

#Paths
[string]$Script:InstallSource = 'C:\temp\VeeamBackup&Replication_10.0.0.4461' #No trailing slash required
[string]$Script:InstallLogDir = 'C:\temp\InstallLogs' #No trailing slash required
[string]$Script:LicenseFile = 'C:\temp\Veeam_Availability_Suite_v10.lic'

#Remote vs. local SQL
[bool]$Script:UseRemoteSQL = $false

#User account
[string]$Script:User_Account_Type = 'Local'
#[string]$Script:User_Account_Type = 'Domain'

[string]$Script:All_Service_Username = 'svc_veeam'
[string]$Script:All_Service_Password = 'P@ssw0rd'



###Not to be modified
if ($Script:All_Service_Username) {
  [string]$Script:All_Service_User = switch ($Script:User_Account_Type) {
    'Local' { $env:COMPUTERNAME + '\' + $Script:All_Service_Username }
    'Domain' { $env:USERDOMAIN + '\' + $Script:All_Service_Username }
  }
}

if ($Script:InstallSource -match "\\$") {
  $Script:InstallSource = $Script:InstallSource.TrimEnd('\')
}

if ($Script:InstallLogDir -match "\\$") {
  $Script:InstallLogDir = $Script:InstallLogDir.TrimEnd('\')
}

#endregion InstallOptions

#region BackupCatalog

#Paths
[string]$Script:VBR_CatalogPath = 'C:\VBRCatalog'
#[string]$Script:VBR_InstallDir = 'C:\Program Files\Veeam\Backup and Replication\' #Will add a 'Backup Catalog' subfolder in this path

#Service account & port
#[string]$Script:VBRC_Service_Username = 'svc_veeam_vbrc'
#[string]$Script:VBRC_Service_Password = 'VBRCP@ssw0rd'
#[int]$Script:VBRC_Service_Port = '9393'



###Not to be modified
if ($Script:VBRC_Service_Username) {
  [string]$Script:VBRC_Service_User = switch ($User_Account_Type) {
    'Local' { $env:COMPUTERNAME + '\' + $VBRC_Service_Username }
    'Domain' { $env:USERDOMAIN + '\' + $VBRC_Service_Username }
  }
}

[string]$Script:VBRC_MSIFile = "$InstallSource\Catalog\VeeamBackupCatalog64.msi"
[string]$Script:VBRC_LogPath = "$InstallLogDir\01_VeeamBackupCatalog.txt"

#endregion BackupCatalog

#region BackupServer

#Paths
[string]$Script:vPowerNFSPath = 'C:\vPowerNFS'
[string]$Script:IRWriteCache = 'C:\ProgramData\Veeam\Backup\IRCache'
#[string]$Script:VBR_InstallDir = 'C:\Program Files\Veeam\Backup and Replication\' #Will add a 'Backup' subfolder in this path

#Update & Upgrade
[bool]$Script:VBR_Check_Updates = $true #Automatically check for new product patches and versions
[bool]$Script:VBR_Upgrade_Components = $true #Automatically upgrade existing components in the backup infrastructure

#Service account & port
#[string]$Script:VBR_Service_Username = 'svc_veeam_vbr'
#[string]$Script:VBR_Service_Password = 'VBRP@ssw0rd'
#[int]$Script:VBR_Service_Port = '9392'
#[int]$Script:VBR_Secure_Connections_Port = '9401'

#SQL Options
#[string]$Script:VBR_SQLServer_Server = 'SQLSERVER.domain.local'
#[string]$Script:VBR_SQLServer_Database = 'VEEAMSQL2016'
#[string]$Script:VBR_SQLServer_Authentication = $true #Use SQL Server authentication mode (rather than Windows authentication mode)
#[string]$Script:VBR_SQLServer_Username = 'sa'
#[string]$Script:VBR_SQLServer_Password = 'SQLP@ssw0rd'



###Not to be modified
if ($Script:VBR_Service_Username) {
  [string]$Script:VBR_Service_User = switch ($User_Account_Type) {
    'Local' { $env:COMPUTERNAME + '\' + $Script:VBR_Service_Username }
    'Domain' { $env:USERDOMAIN + '\' + $Script:VBR_Service_Username }
  }
}

[string]$Script:VBR_MSIFile = "$InstallSource\Backup\Server.x64.msi"
[string]$Script:VBR_LogPath = "$InstallLogDir\02_VeeamBackupServer.txt"

#endregion BackupServer

#region BackupConsole

#Path
#[string]$Script:VBC_InstallDir = 'C:\Program Files\Veeam\Backup and Replication\' #Will add a 'Console' subfolder in this path



###Not to be modified
[string]$Script:VBC_MSIFile = "$InstallSource\Backup\Shell.x64.msi"
[string]$Script:VBC_LogPath = "$InstallLogDir\03_VeeamBackupConsole.txt"

#endregion BackupConsole

#region Explorers
###Nothing to modify here

[string]$Script:ExplorerAD_MSIFile = "$InstallSource\Explorers\VeeamExplorerForActiveDirectory.msi"
[string]$Script:ExplorerAD_LogPath = "$InstallLogDir\Explorer01_VeeamExplorerForActiveDirectory.txt"

[string]$Script:ExplorerExchange_MSIFile = "$InstallSource\Explorers\VeeamExplorerForExchange.msi"
[string]$Script:ExplorerExchange_LogPath = "$InstallLogDir\Explorer03_VeeamExplorerForExchange.txt"

[string]$Script:ExplorerOracle_MSIFile = "$InstallSource\Explorers\VeeamExplorerForOracle.msi"
[string]$Script:ExplorerOracle_LogPath = "$InstallLogDir\Explorer05_VeeamExplorerForOracle.txt"

[string]$Script:ExplorerSharePoint_MSIFile = "$InstallSource\Explorers\VeeamExplorerForSharePoint.msi"
[string]$Script:ExplorerSharePoint_LogPath = "$InstallLogDir\Explorer04_VeeamExplorerForSharePoint.txt"

[string]$Script:ExplorerSQL_MSIFile = "$InstallSource\Explorers\VeeamExplorerForSQL.msi"
[string]$Script:ExplorerSQL_LogPath = "$InstallLogDir\Explorer02_VeeamExplorerForSQL.txt"


#endregion Explorers

#region BackupEnterpriseManager

#Path

#[string]$Script:VBREM_InstallDir = 'C:\Program Files\Veeam\Enterprise Manager\'

#Service account & port
#[string]$Script:VBREM_Service_Username = 'svc_veeam_vbrem'
#[string]$Script:VBREM_Service_Password = 'VBREMP@ssw0rd'
#[int]$Script:VBREM_Service_Port = '9394'
#[int]$Script:VBREM_Website_TCPPort = '9080'
#[int]$Script:VBREM_Website_SSLPort = '9443'

#REST API Options
#[string]$Script:VBREM_Thumbprint = '0677d0b8f27caccc966b15d807b41a101587b488'
#[string]$Script:VBREM_REST_API_Service_Port = '9399'
#[string]$Script:VBREM_REST_API_Service_SSLPort = '9398'
#[bool]$Script:VBREM_Config_SChannel = $true

#SQL Options
#[string]$Script:VBREM_SQLServer_Server = 'SQLSERVER.domain.local'
#[string]$Script:VBREM_SQLServer_Database = 'VEEAMSQL2016'
#[string]$Script:VBREM_SQLServer_Authentication = $true #Use SQL Server authentication mode (rather than Windows authentication mode)
#[string]$Script:VBREM_SQLServer_Username = 'sa'
#[string]$Script:VBREM_SQLServer_Password = 'SQLP@ssw0rd'

###Not to be modified
if ($Script:VBREM_Service_Username) {
  [string]$Script:VBREM_Service_User = switch ($User_Account_Type) {
    'Local' { $env:COMPUTERNAME + '\' + $Script:VBREM_Service_Username }
    'Domain' { $env:USERDOMAIN + '\' + $Script:VBREM_Service_Username }
  }
}

[string]$Script:VBREM_MSIFile = "$InstallSource\EnterpriseManager\BackupWeb_x64.msi"
[string]$Script:VBREM_LogPath = "$InstallLogDir\04_VeeamBackupEnterpriseManagerWeb.txt"

#endregion BackupEnterpriseManager

#region CloudConnectPortal

#Path
#[string]$Script:CCP_InstallDir = 'C:\Program Files\Veeam\Backup and Replication\CloudPortal\'

###Not to be modified
[string]$Script:CCP_MSIFile = "$InstallSource\Cloud Portal\BackupCloudPortal_x64.msi"
[string]$Script:CCP_LogPath = "$InstallLogDir\04_VeeamBackupEnterpriseManagerWeb.txt"

#endregion CloudConnectPortal

#region MSIArguments - DO NOT MODIFY

[string]$Script:ServerEULA = ' ACCEPTEULA="YES"'
[string]$Script:ExplorerEULA = ' ACCEPT_EULA="1"'
[string]$Script:ThirdPartyLicenses = ' ACCEPT_THIRDPARTY_LICENSES="1"'


$Script:MSIArgs = @(
  '/i'
  '"{0}"'
  '/qn'
  '/norestart'
  '/L*v'
  '"{1}"'
)

#endregion MSIArguments


#region SQL Express MSIArguments - DO NOT MODIFY

[string]$Script:SQLSysAdmins = ("`"NT AUTHORITY\SYSTEM`" `"BUILTIN\Administrators`"")

if ($Script:All_Service_User) {

  [string]$Script:SQLSysAdmin = $Script:All_Service_User
  $Script:SQLSysAdmins += " `"$SQLSysAdmin`""

}

if ($Script:VBR_Service_User) {

  [string]$Script:SQLSysAdmin = $Script:VBR_Service_User
  $Script:SQLSysAdmins += " `"$SQLSysAdmin`""

}

if ($Script:VBREM_Service_User) {

  [string]$Script:SQLSysAdmin = $Script:VBR_Service_User
  $Script:SQLSysAdmins += " `"$SQLSysAdmin`""

}

$Script:SQLExpress_Args = @(
  "/ACTION=Install"
  "/SUPPRESSPRIVACYSTATEMENTNOTICE"
  "/IACCEPTSQLSERVERLICENSETERMS"
  "/ENU"
  "/UpdateEnabled=False"
  "/ROLE=AllFeatures_WithDefaults"
  "/FEATURES=SQLENGINE"
  "/INDICATEPROGRESS=False"
  "/INSTANCEID=VEEAMSQL2016"
  "/INSTANCENAME=VEEAMSQL2016"
  "/QUIET"
  "/HIDECONSOLE"
  "/AGTSVCACCOUNT=`"NT AUTHORITY\NETWORK SERVICE`""
  "/AGTSVCSTARTUPTYPE=Disabled"
  "/BROWSERSVCSTARTUPTYPE=Automatic"
  "/ENABLERANU"
  "/SQLCOLLATION=SQL_Latin1_General_CP1_CI_AS"
  "/ADDCURRENTUSERASSQLADMIN"
  "/SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`""
  "/SQLSVCSTARTUPTYPE=Automatic"
  "/SQLSYSADMINACCOUNTS={0}"
  "/SQLTEMPDBFILESIZE=8"
  "/SQLTEMPDBLOGFILESIZE=8"
  "/TCPENABLED=1"
  "/NPENABLED=1"
)

#endregion  SQL Express MSIArguments - DO NOT MODIFY

<#
function Install-PrereqMSI {
  Param(
    [string]$MSIFile,
    [string]$LogPath
  )

  $MSIParameters = @(
    "/i"
    '"{0}"' -f $MSIFile
    "/qn"
    "/norestart"
    "/L*v"
    '"{0}"' -f $LogPath
  )

  Start-Process 'msiexec.exe' -Wait -ArgumentList $params -Passthru -NoNewWindow
}

function Install-ComponentMSI {
  Param(
    [string]$MSIFile,
    [string]$LogFile
  )

  $MSIParameters = @(
    "/i"
    '"{0}"' -f $MSIFile
    "/qn"
    "/norestart"
    "/L*v"
    '"{0}"' -f $LogFile
    'ACCEPTEULA="yes"'
    'ACCEPT_THIRDPARTY_LICENSES="1"'
  )

  Start-Process 'msiexec.exe' -Wait -ArgumentList $params -Passthru -NoNewWindow
}

function Install-ServerMSI {
  Param(
    [string]$MSIFile,
    [string]$LogFile,
    [string]$LicenseFile
  )

  $MSIParameters = @(
    "/i"
    '"{0}"' -f $MSIFile
    "/qn"
    "/norestart"
    "/L*v"
    '"{0}"' -f $LogFile
    'VBR_LICENSE_FILE="{0}"' -f $LicenseFile
    'ACCEPTEULA="yes"'
    'ACCEPT_THIRDPARTY_LICENSES="1"'
  )

  Start-Process 'msiexec.exe' -Wait -ArgumentList $params -Passthru -NoNewWindow
}

function Install-ExplorerMSI {
  Param(
    [string]$MSIFile,
    [string]$LogFile
  )

  $MSIParameters = @(
    "/i"
    '"{0}"' -f $MSIFile
    "/qn"
    "/norestart"
    "/L*v"
    '"{0}"' -f $LogPath
    'ACCEPT_EULA="1"'
    'ACCEPT_THIRDPARTY_LICENSES="1"'
  )

  Start-Process 'msiexec.exe' -Wait -ArgumentList $params -Passthru -NoNewWindow
}

#>