# Requires PowerShell 5.1
# Requires .Net 4.5.2 and Reboot

#region: Variables
$source = "X:"
$licensefile = "C:\_install\veeam.lic"
$username = "svc_veeam"
$fulluser = $env:COMPUTERNAME+ "\" + $username
$password = "Password!"
$CatalogPath = "D:\VbrCatalog"
$vPowerPath = "D:\vPowerNfs"
#endregion

#region: logdir
$logdir = "C:\logdir"
$trash = New-Item -ItemType Directory -path $logdir  -ErrorAction SilentlyContinue
#endregion

### Optional .Net 4.5.2
<#
Write-Host "    Installing .Net 4.5.2 ..." -ForegroundColor Yellow
$Arguments = "/quiet /norestart"
Start-Process "$source\Redistr\NDP452-KB2901907-x86-x64-AllOS-ENU.exe" -ArgumentList $Arguments -Wait -NoNewWindow
Restart-Computer -Confirm:$true
#>

### Optional PowerShell 5.1
<#
Write-Host "    Installing PowerShell 5.1 ..." -ForegroundColor Yellow
$Arguments = "C:\_install\Win8.1AndW2K12R2-KB3191564-x64.msu /quiet /norestart"
Start-Process "wusa.exe" -ArgumentList $Arguments -Wait -NoNewWindow
Restart-Computer -Confirm:$true
#>

#region: create local admin
Write-Host "Creating local user '$fulluser' with password '$password' ..." -ForegroundColor Yellow
$trash = New-LocalUser -Name $username -Password ($password | ConvertTo-SecureString -AsPlainText -Force) -Description "Service Account for Veeam" -AccountNeverExpires -ErrorAction Stop
Add-LocalGroupMember -Group "Administrators" -Member $username -ErrorAction Stop
#endregion

#region: Installation
#  Info: https://www.veeam.com/unattended_installation_ds.pdf

## Global Prerequirements
Write-Host "Installing Global Prerequirements ..." -ForegroundColor Yellow
### 2012 System CLR Types
Write-Host "    Installing 2012 System CLR Types ..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Redistr\x64\SQLSysClrTypes.msi"
    "/qn"
    "/norestart"
    "/L*v"
    "$logdir\01_CLR.txt"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\01_CLR.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

### 2012 Shared management objects
Write-Host "    Installing 2012 Shared management objects ..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Redistr\x64\SharedManagementObjects.msi"
    "/qn"
    "/norestart"
    "/L*v"
    "$logdir\02_Shared.txt"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\02_Shared.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

### SQL Express
### Info: https://msdn.microsoft.com/en-us/library/ms144259.aspx
Write-Host "    Installing SQL Express ..." -ForegroundColor Yellow
$Arguments = "/HIDECONSOLE /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=install /FEATURES=SQLEngine,SNAC_SDK /INSTANCENAME=VEEAMSQL2012 /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$fulluser`" `"Builtin\Administrators`" /TCPENABLED=1 /NPENABLED=1 /UpdateEnabled=0"
Start-Process "$source\Redistr\x64\SQLEXPR_x64_ENU.exe" -ArgumentList $Arguments -Wait -NoNewWindow

## Veeam Backup & Replication
Write-Host "Installing Veeam Backup & Replication ..." -ForegroundColor Yellow
### Backup Catalog
Write-Host "    Installing Backup Catalog ..." -ForegroundColor Yellow
$trash = New-Item -ItemType Directory -path $CatalogPath -ErrorAction SilentlyContinue
$MSIArguments = @(
    "/i"
    "$source\Catalog\VeeamBackupCatalog64.msi"
    "/qn"
    "/L*v"
    "$logdir\04_Catalog.txt"
    "VM_CATALOGPATH=$CatalogPath"
    "VBRC_SERVICE_USER=$fulluser"
    "VBRC_SERVICE_PASSWORD=$password"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\04_Catalog.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

### Backup Server
Write-Host "    Installing Backup Server ..." -ForegroundColor Yellow
$trash = New-Item -ItemType Directory -path $vPowerPath -ErrorAction SilentlyContinue
$MSIArguments = @(
    "/i"
    "$source\Backup\Server.x64.msi"
    "/qn"
    "/L*v"
    "$logdir\05_Backup.txt"
    "ACCEPTEULA=YES"
    "VBR_LICENSE_FILE=$licensefile"
    "VBR_SERVICE_USER=$fulluser"
    "VBR_SERVICE_PASSWORD=$password"
    "PF_AD_NFSDATASTORE=$vPowerPath"
    "VBR_SQLSERVER_SERVER=$env:COMPUTERNAME\VEEAMSQL2012"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\05_Backup.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

### Backup Console
Write-Host "    Installing Backup Console ..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Backup\Shell.x64.msi"
    "/qn"
    "/L*v"
    "$logdir\06_Console.txt"
    "ACCEPTEULA=YES"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\06_Console.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

### Explorers
Write-Host "    Installing Explorer For ActiveDirectory ..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Explorers\VeeamExplorerForActiveDirectory.msi"
    "/qn"
    "/L*v"
    "$logdir\07_ExplorerForActiveDirectory.txt"
    "ACCEPTEULA=YES"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\07_ExplorerForActiveDirectory.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

Write-Host "    Installing Explorer For Exchange ..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Explorers\VeeamExplorerForExchange.msi"
    "/qn"
    "/L*v"
    "$logdir\08_VeeamExplorerForExchange.txt"
    "ACCEPTEULA=YES"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\08_VeeamExplorerForExchange.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

Write-Host "    Installing Explorer For SQL ..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Explorers\VeeamExplorerForSQL.msi"
    "/qn"
    "/L*v"
    "$logdir\09_VeeamExplorerForSQL.txt"
    "ACCEPTEULA=YES"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\09_VeeamExplorerForSQL.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

Write-Host "    Installing Explorer For Oracle ..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Explorers\VeeamExplorerForOracle.msi"
    "/qn"
    "/L*v"
    "$logdir\10_VeeamExplorerForOracle.txt"
    "ACCEPTEULA=YES"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\10_VeeamExplorerForOracle.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

Write-Host "    Installing Explorer For SharePoint ..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Explorers\VeeamExplorerForSharePoint.msi"
    "/qn"
    "/L*v"
    "$logdir\11_VeeamExplorerForSharePoint.txt"
    "ACCEPTEULA=YES"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\11_VeeamExplorerForSharePoint.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

## Enterprise Manager
Write-Host "Installing Enterprise Manager ..." -ForegroundColor Yellow
### Enterprise Manager Prereqirements
Write-Host "    Installing Enterprise Manager Prereqirements ..." -ForegroundColor Yellow
$trash = Install-WindowsFeature Web-Default-Doc,Web-Dir-Browsing,Web-Http-Errors,Web-Static-Content,Web-Windows-Auth -Restart:$false -WarningAction SilentlyContinue
$trash = Install-WindowsFeature Web-Http-Logging,Web-Stat-Compression,Web-Filtering,Web-Net-Ext45,Web-Asp-Net45,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Mgmt-Console -Restart:$false  -WarningAction SilentlyContinue

$MSIArguments = @(
    "/i"
    "$source\Redistr\x64\rewrite_amd64.msi"
    "/qn"
    "/norestart"
    "/L*v"
    "$logdir\12_Rewrite.txt"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\12_Rewrite.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

### Enterprise Manager Web
Write-Host "    Installing Enterprise Manager Web ..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\EnterpriseManager\BackupWeb_x64.msi"
    "/qn"
    "/L*v"
    "$logdir\13_EntWeb.txt"
    "ACCEPTEULA=YES"
    "VBREM_LICENSE_FILE=$licensefile"
    "VBREM_SERVICE_USER=$fulluser"
    "VBREM_SERVICE_PASSWORD=$password"
    "VBREM_SQLSERVER_SERVER=$env:COMPUTERNAME\VEEAMSQL2012"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\13_EntWeb.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

### Enterprise Manager Cloud Portal
Write-Host "    Installing Enterprise Manager Cloud Portal ..." -ForegroundColor Yellow
<#
$MSIArguments = @(
    "/i"
    "$source\Cloud Portal\BackupCloudPortal_x64.msi"
    "/L*v"
    "$logdir\14_EntCloudPortal.txt"
    "/qn"
    "ACCEPTEULA=YES"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow
#>
Start-Process "msiexec.exe" -ArgumentList "/i `"$source\Cloud Portal\BackupCloudPortal_x64.msi`" /l*v $logdir\14_EntCloudPortal.txt /qn ACCEPTEULA=`"YES`"" -Wait -NoNewWindow

if (Select-String -path "$logdir\14_EntCloudPortal.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

### Update 2
Write-Host "Installing Update 2 ..." -ForegroundColor Yellow
$Arguments = "/silent /noreboot /log $logdir\15_update.txt VBR_AUTO_UPGRADE=1"
Start-Process "$source\Updates\veeam_backup_9.5.0.1038.update2_setup.exe" -ArgumentList $Arguments -Wait -NoNewWindow
#endregion