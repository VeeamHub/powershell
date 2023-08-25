# =======================================================
# NAME: VBM365audit.ps1
# AUTHOR: Commenge Damien, Axians Cloud Builder
# DATE: 11/07/2022
#
# VERSION 1.08
# COMMENTS: This script is created to Audit Veeam backup for microsoft 365
# <N/A> is used for not available
# =======================================================

<#
# 16/07/2022 
    Update lot of code for better performance
# 18/07/2022 
    Change date format and replace VBM to VB365
# 26/07/2022 
    Optimize path creation
# 09/08/2023 
    Add storage account
    Add backup copy
    Add encryption key
    Add Teams graph API
    Add modern authentication notifications
# 21/08/2023
    Fix issue on storage repository function with B instead of GB
# 22/08/2023
    Can get several organizations
# 25/08/2023
    Fix issue on Get-DCVB365Proxy reporting only 1 proxy
#>

# =======================================================

#Requires -Modules @{ ModuleName="Veeam.Archiver.PowerShell"; ModuleVersion="6.0" }
#Date to create folder
$Date = Get-Date -Format "yyyy-MM-dd HH_mm"
#ReportPath to create folder
$ReportPath="C:\temp\VBM365Audit\$Date"
#Create folder
New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
#Report path
$HTMLReportPath = "$ReportPath\VeeamBackupMicrosoft365.html"
#Web page title
$HTMLTitle = "VBM365 report"
#Web page CSS style
$HTMLCSS = @'
<style>
    body{color:black;font-family:Vinci Sans Light;font-size:0.79em;line-height:1.25;margin:5;}
    a{color:black;}
    H1{color:white;font-family:Verdana;font-weight:bold;font-size:20pt;margin-bottom:50px;margin-top:40px;text-align:center;background-color:#005EB8;}
    H2{color:#A20067;font-family:Verdana;font-size:16pt;margin-left:14px;text-align:left;}
    H3{color:#005EB8;font-family:Verdana;font-size:13pt;margin-left:16px;}
    H4{color:black;font-family:Verdana;font-size:11pt;margin-left:16px;}
    table {border-collapse: collapse;margin-left:10px;border-radius:7px 7px 0px 0px;}
    th, td {padding: 8px;text-align: left;border-bottom: 1px solid #ddd;}
    th {background-color: #006400;color: white;}
    td:first-child{font-weight:bold;}
    tr:nth-child(even){background-color: #f2f2f2}
    table.table2 td:first-child{background-color: #A20067;color: white}
</style>
'@

#Connect to VBO Server
Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - Connecting to VBM 365 server"
try {
    Connect-VBOServer -ErrorAction Stop
    Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - Connected to VBM 365 server"
}
catch [System.Management.Automation.RuntimeException]{
    Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - Connexion is already done"
}
catch {
    Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - $($_.Exception.message) " -ForegroundColor Red
    return
}

 <#
 .SYNOPSIS
    Get configuration Summary from Veeam Microsoft 365 server
 .DESCRIPTION
    Get server name, OS, OS build and VBM365 version
 .EXAMPLE 
    Get-DCVB365Summary
 #>
function Get-DCVB365Summary
{
    Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Summary"

    $ServerName   = $env:COMPUTERNAME
    $ServerOS     = (Get-CimInstance Win32_OperatingSystem).Caption
    $OSBuild      = Get-ItemPropertyValue -path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion" -name 'UBR'
    $VB365build   = (Get-VBOVersion).ProductVersion
    
    
    [PScustomObject]@{
        Name            = $ServerName
        OS              = $ServerOS
        OSBuild         = $OSBuild
        VB365Version    = $VB365build
    }
}

 <#
 .SYNOPSIS
    Get configuration about organizations
 .DESCRIPTION
    Get organization name, account used, type (on premise, hybride, O365), service (exchange, sharepoint), region, authentication (basic, modern with legacy protocol, modern), auxiliar backup account/application number
 .EXAMPLE 
    Get-DCVB365Organization
 #>
 function Get-DCVB365Organization
 {
     Write-host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Organization"
 
     $Organization = Get-VBOOrganization
     foreach ($org in $Organization)
     {
 
         if ($Org.Office365ExchangeConnectionSettings)
         {
             $OrgAuth = $org.Office365ExchangeConnectionSettings.AuthenticationType
         }
         else
         {
             $OrgAuth = $org.Office365SharePointConnectionSettings.AuthenticationType
         }
         if ($OrgAuth -eq "Basic")
         {
             $AuxAccount = $org.backupaccounts.count
         }
         else
         {
             $AuxAccount = $org.backupapplications.count
         }
 
         [PScustomObject]@{
             Name            = $org.OfficeName
             Account         = $org.username
             Type            = $org.type
             Service         = $org.BackupParts
             Region          = $org.region
             Authentication  = $OrgAuth
             AuxAccount      = $AuxAccount
         }
     }
 }

 <#
 .SYNOPSIS
    Get configuration about backup job configuration
 .DESCRIPTION
    Get job name, type, included object, excluded object, repository, proxy, schedule, active or disabled state
 .EXAMPLE 
    Get-DCVB365BackupJob
 #>
function Get-DCVB365BackupJob
{
    Write-host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Backup Jobs"

    foreach ($Job in Get-VBOJob)
    {
        #Get proxy name from associated proxy ID repository
        $JobSchedule = "<N/A>"
        if ($Job.schedulepolicy.EnableSchedule -and $Job.SchedulePolicy.Type -eq "daily")
        {
             $JobSchedule = [string]$Job.SchedulePolicy.DailyTime + " " + $Job.SchedulePolicy.DailyType
        }
        if ($Job.schedulepolicy.EnableSchedule -and $Job.SchedulePolicy.Type -eq "Periodically")
        {
             $JobSchedule = $Job.SchedulePolicy.PeriodicallyEvery
        }

        [PScustomObject]@{
            Name        = $Job.Name
            Type        = $Job.JobBackupType
            InclObject  = $Job.SelectedItems -join ", "
            ExclObject  = $Job.ExcludedItems -join ", "
            Repository  = $Job.Repository
            Proxy       = (Get-VBOProxy -id (Get-VBORepository -Name $Job.Repository).Proxy.Id -ExtendedView:$False).Hostname
            Schedule    = $JobSchedule
            Enabled     = $Job.IsEnabled
        }
    }
}

<#
 .SYNOPSIS
    Get configuration about backup copy job configuration
 .DESCRIPTION
    Get job name, repository, backupjob linked, schedule, active or disabled state
 .EXAMPLE 
    Get-DCVB365BackupCopyJob
 #>
function Get-DCVB365BackupCopyJob
{
    Write-host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Backup copy Jobs"
    $CopyJobs = Get-VBOCopyJob
    if ($CopyJobs)
    {
        foreach ($CopyJob in $CopyJobs)
        {
            if ($CopyJob.SchedulePolicy.Type -eq "daily")
            {
                 $JobSchedule = [string]$CopyJob.SchedulePolicy.DailyTime + " " + $CopyJob.SchedulePolicy.DailyType
            }
            if ($CopyJob.SchedulePolicy.Type -eq "Periodically")
            {
                 $JobSchedule = $CopyJob.SchedulePolicy.PeriodicallyEvery
            }
            else 
            {
                $JobSchedule = $CopyJob.SchedulePolicy.Type
            }
            [PScustomObject]@{
                Name            = $CopyJob.name
                Repository      = $CopyJob.Repository
                BackupLinked    = $CopyJob.BackupJob.name
                Schedule        = $JobSchedule
                Enabled         = $CopyJob.IsEnabled
            }
        }
    }
    else
    {
        [PScustomObject]@{
            Name            = "<N/A>"
            Repository      = "<N/A>"
            BackupLinked    = "<N/A>"
            Schedule        = "<N/A>"
            Enabled         = "<N/A>"
        }        
    }
}


 <#
 .SYNOPSIS
    Get configuration about proxy configuration
 .DESCRIPTION
    Get proxy name, port, thread number, throttling, internet proxy used or not, internet proxy port and account
 .EXAMPLE 
    Get-DCVB365Proxy
 #>
 function Get-DCVB365Proxy
 {
 
     Write-host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Proxy"
 
     foreach ($Proxy in (Get-VBOProxy -ExtendedView:$False))
     {
        [PScustomObject]@{
             Name            = $Proxy.hostname
             Port            = $Proxy.port
             Thread          = $Proxy.ThreadsNumber
             Throttling      = [string]$Proxy.ThrottlingValue + " " + $Proxy.ThrottlingUnit
             IntProxyHost    = "<N/A>"
             IntProxyPort    = "<N/A>"
             IntProxyAccount = "<N/A>"
         }
         if ($Proxy.InternetProxy.UseInternetProxy)
         {
             $Proxy.IntProxyHost     = $Proxy.InternetProxy.UseInternetProxy.Host
             $Proxy.IntProxyPort     = $Proxy.InternetProxy.UseInternetProxy.Port
             $Proxy.IntProxyAccount  = $Proxy.InternetProxy.UseInternetProxy.User
         }
     }
 }

 <#
 .SYNOPSIS
    Get configuration about repository configuration
 .DESCRIPTION
    Get repository name, proxy associated, path, retention type and value, repository object name and encryption
 .EXAMPLE 
    Get-DCVB365Repository
 #>
 function Get-DCVB365Repository
 {
 
     Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Repository"
 
     foreach ($Repository in Get-VBORepository)
     {
        $Proxy        =  (Get-VBOProxy -id (Get-VBORepository -name $Repository.Name).Proxy.Id -ExtendedView:$False).Hostname
        $Retention    = [string]$Repository.RetentionPeriod + " " + $Repository.RetentionType
         $ObjectName   = "<N/A>"
         if ($Repository.ObjectStorageRepository)
         {
             $ObjectName = $Repository.ObjectStorageRepository.Name
         }
         [int]$UsedStorage = ($Repository.Capacity - $Repository.FreeSpace) / 1GB
         [int]$TotalStorage = $Repository.Capacity / 1GB
         [PScustomObject]@{
             Name                = $Repository.Name
             Proxy               = $Proxy
             Path                = $Repository.Path
             ObjectRepository    = $ObjectName
             Retention           = $Retention
             Encryption          = $Repository.EnableObjectStorageEncryption
             'Storage(GB)'             = [String]$UsedStorage + "/" +  $TotalStorage
         }
     }
 }
 

 <#
 .SYNOPSIS
    Get configuration about object repository configuration
 .DESCRIPTION
    Get repository name, folder, type, UsedSpace, size limit and if it's long term achive
 .EXAMPLE 
    Get-DCVB365ObjectRepository
 #>
 function Get-DCVB365ObjectRepository
 {
     Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Object Repository"
 
     foreach ($ObjectStorage in Get-VBOObjectStorageRepository)
     {
         $SizeLimit = "<N/A>"
         if ($ObjectStorage.EnableSizeLimit)
         {
             $SizeLimit = $ObjectStorage.SizeLimit
         }
         $UsedSpace = $ObjectStorage.UsedSpace / 1GB -as [INT]
         [PScustomObject]@{
             Name            = $ObjectStorage.name
             Folder          = $ObjectStorage.Folder
             Type            = $ObjectStorage.Type
             'UsedSpace(GB)' = $UsedSpace
             SizeLimit       = $SizeLimit
             LongTerm        = $ObjectStorage.IsLongTerm
         }
     }
 }

 <#
 .SYNOPSIS
    Get configuration about license
 .DESCRIPTION
    Get license type, expiration date, customer, contact, usage
 .EXAMPLE 
    Get-DCVB365License
 #>
 function Get-DCVB365License
 {
 
     Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 License"
     $License         = (Get-VBOLicense)
     $Usage    = [string]$License.usedNumber + "/" + (Get-VBOLicense).TotalNumber
 
     [PScustomObject]@{
         Type        = $License.Type
         Expiration  = $License.ExpirationDate.ToUniversalTime().ToString("yyyy/MM/dd")
         To          = $License.LicensedTo
         Contact     = $License.ContactPerson
         Number      = $Usage
     }
 }

 <#
 .SYNOPSIS
    Get configuration about restore operator configuration
 .DESCRIPTION
    Get role name, organization, operator, associated object, excluded object
 .EXAMPLE 
    Get-DCVB365RestoreOperator
 #>
function Get-DCVB365RestoreOperator
{
    Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Restore Operator"

    $Roles = Get-VBORbacRole
    if ($role)
    {
        foreach ($Role in $Roles)
        {

                $IncludedObject = "Organization"
                $ExcludedObject = "<N/A>"
                if ($Role.RoleType -ne "EntireOrganization")
                {
                    $IncludedObject = $Role.SelectedItems.DisplayName -join ", "
                }
                if ($Role.ExcludedItems)
                {
                $ExcludedObject = $Role.ExcludedItems.DisplayName -join ", "
                }
                [PScustomObject]@{
                    Role            = $Role.Name
                    Organization    = (Get-VBOOrganization -Id ($Role.OrganizationId)).Name
                    Operator        = $Role.Operators.DisplayName -join ", "
                    IncludedObject  = $IncludedObject
                    ExcludedObject  = $ExcludedObject
                }
            }

        }
    else
    {
        [PScustomObject]@{
            Role            = "<N/A>"
            Organization    = "<N/A>"
            Operator        = "<N/A>"
            IncludedObject  = "<N/A>"
            ExcludedObject  = "<N/A>"
        }
    }
}

 <#
 .SYNOPSIS
    Get configuration about RestAPI configuration
 .DESCRIPTION
    Get state, token life time, port, certificate thumbprint friendly name and expiration date
 .EXAMPLE 
    Get-DCVB365RestAPI
 #>
function Get-DCVB365RestAPI
{
    Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 REST API"
        
    $RestAPI = Get-VBORestAPISettings

    [PScustomObject]@{
        Enabled             = $RestAPI.IsServiceEnabled
        CertThumbprint      = $RestAPI.CertificateThumbprint
        CertFriendlyName    = $RestAPI.CertificateFriendlyName
        CertExpiration      = $RestAPI.CertificateExpirationDate.ToUniversalTime().ToString("yyyy/MM/dd")
        TokenTime           = $RestAPI.AuthTokenLifeTime
        Port                = $RestAPI.HTTPSPort
    }
}


 <#
 .SYNOPSIS
    Get configuration about Restore portal configuration
 .DESCRIPTION
    Get state, application ID, certificate thumbprint friendly name and expiration date
 .EXAMPLE 
    Get-DCVB365RestorePortal
 #>
 function Get-DCVB365RestorePortal
 {
 
     Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Restore portal"
 
     $RestorePortal = Get-VBORestorePortalSettings
 
     [PScustomObject]@{
         Enabled             = $RestorePortal.IsServiceEnabled
         CertThumbprint      = $RestorePortal.CertificateThumbprint
         CertFriendlyName    = $RestorePortal.CertificateFriendlyName
         CertExpiration      = $RestorePortal.CertificateExpirationDate.ToUniversalTime().ToString("yyyy/MM/dd")
         AzureApplicationID  = $RestorePortal.ApplicationId.Guid
     }
 }

 <#
 .SYNOPSIS
    Get configuration about operator Authentication portal configuration
 .DESCRIPTION
    Get state, certificate thumbprint friendly name and expiration date
 .EXAMPLE 
    Get-DCVB365OperatorAuthentication
 #>
 function Get-DCVB365OperatorAuthentication
 {
     Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Authentication"
 
     $OperatorAuthentication = Get-VBOOperatorAuthenticationSettings
 
     [PScustomObject]@{
         Enabled             = $OperatorAuthentication.AuthenticationEnabled
         CertThumbprint      = "InFutureVersion"
         CertFriendlyName    = $OperatorAuthentication.CertificateFriendlyName
         CertExpiration      = $OperatorAuthentication.CertificateExpirationDate.ToUniversalTime().ToString("yyyy/MM/dd")
     }
 }

 <#
 .SYNOPSIS
    Get configuration about internet proxy
 .DESCRIPTION
    Get state, host, port and account
 .EXAMPLE 
    Get-DCVB365InternetProxy
 #>
function Get-DCVB365InternetProxy
{
    Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Internet Proxy"
    $InternetProxySetting = Get-VBOInternetProxySettings

    $InternetProxy = [PScustomObject]@{
        Enabled   = $InternetProxySetting.UseInternetProxy
        Host      = "<N/A>"
        Port      = "<N/A>"
        Account   = "<N/A>"
    }
    if ($InternetProxySetting.UseInternetProxy)
    {
        $InternetProxy.Host    = $InternetProxySetting.Host
        $InternetProxy.Port    = $InternetProxySetting.Port
        $InternetProxy.Account = $InternetProxySetting.User
    }
    $InternetProxy
}

 <#
 .SYNOPSIS
    Get configuration about SMTP
 .DESCRIPTION
    Get state, server, port, ssl, account, type
 .EXAMPLE 
    Get-DCVB365SMTP
 #>
 function Get-DCVB365SMTP
 {
     Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 SMTP configuration"
 
     $SMTPSetting = Get-VBOEmailSettings
     $Type = if ($SMTPSetting.AuthenticationType -eq "CustomSmtp")
             {
                 "SMTP authentication"
             }
             else
             {
                 $SMTPSetting.AuthenticationType
             }
     $SMTP = [PScustomObject]@{
         Enabled = $SMTPSetting.EnableNotification
         Type    = "<N/A>"
         Server  = "<N/A>"
         Port    = "<N/A>"
         SSL     = "<N/A>"
         Account = "<N/A>"
     }
     if ($SMTPSetting.EnableNotification)
     {
         $SMTP.Type   = $Type
 
 
         if ($Type -eq "SMTP authentication") 
         {
             $SMTP.Port   = $SMTPSetting.Port
             $SMTP.Server = $SMTPSetting.SMTPServer
             $SMTP.SSL    = $SMTPSetting.UseSSL
 
             if ($SMTPSetting.UseAuthentication)
             {
                 $SMTP.Account = $SMTPSetting.Username
             }
         }
         else
         {
             $SMTP.Server = $SMTPSetting.MailApiUrl
             $SMTP.Account = $SMTPSetting.UserId
         }
     }
     $SMTP
 }


 <#
 .SYNOPSIS
    Get configuration about Notifications
 .DESCRIPTION
    Get state, sender, receiver, notification on success, warning and failure, send only last retry notification
 .EXAMPLE 
    Get-DCVB365Notification
 #>
function Get-DCVB365Notification
{

    Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Notifications"
    $NotificationSetting = (Get-VBOEmailSettings)

    $Notification = [PScustomObject]@{
        Enabled     = $NotificationSetting.EnableNotification
        Sender      = "<N/A>"
        Receiver    = "<N/A>"
        Success     = "<N/A>"
        Warning     = "<N/A>"
        Failure     = "<N/A>"
        LastRetry   = "<N/A>"
    }
    if ($NotificationSetting.EnableNotification)
    {
        $Notification.Sender     = $NotificationSetting.From -join ", "
        $Notification.Receiver   = $NotificationSetting.To -join ", "
        $Notification.Success    = $NotificationSetting.NotifyOnSuccess
        $Notification.Warning    = $NotificationSetting.NotifyOnWarning
        $Notification.Failure    = $NotificationSetting.NotifyOnFailure
        $Notification.LastRetry  = $NotificationSetting.SupressUntilLastRetry
    }
    $Notification
}

 <#
 .SYNOPSIS
    Get configuration about cloud storage account
 .DESCRIPTION
    Get account, type and description
 .EXAMPLE 
    Get-DCVB365StorageAccount
 #>
function Get-DCVB365StorageAccount
{
    Write-host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Cloud storage account"


    #Azure storage account
    $AzureAccount = Get-VBOAzureBlobAccount
    foreach ($account in $AzureAccount)
    {
        [PSCustomObject]@{
            Account = $Account.Name
            Type = "Azure Blob"
            Description = $Account.Description
        }
    }

    #Amazon storage account
    $AmazonAccount = Get-VBOAmazonS3Account
    foreach ($account in $AmazonAccount)
    {
        [PSCustomObject]@{
            Account = $Account.AccessKey
            Type = "Amazon S3"
            Description = $Account.Description
        }
    }
    #S3 compatible storage account
    $S3Compatible = Get-VBOAmazonS3CompatibleAccount
    foreach ($account in $S3Compatible)
    {
        [PSCustomObject]@{
            Account = $Account.AccessKey
            Type = "Amazon S3"
            Description = $Account.Description
        }
    }
}


 <#
 .SYNOPSIS
    Get configuration about cloud storage account
 .DESCRIPTION
    Get account, type and description
 .EXAMPLE 
    Get-DCVB365StorageAccount
 #>
function Get-DCVB365EncryptionKey
{
    Write-host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Encryption key"

    $EncryptionKey = Get-VBOEncryptionKey

    foreach ($obj in $EncryptionKey)
    {
        $repository = Get-VBORepository | Where-Object {$_.ObjectStorageEncryptionKey.ID.Guid -eq $obj.Id.Guid}
        [PSCustomObject]@{
            Repository = $repository.Name
            Description = $obj.Description
        }
    }
}

 <#
 .SYNOPSIS
    Get configuration about Teams Graph API state on VBM365 and proxy
 .DESCRIPTION
    Get Teams graph API state enabled or disabled on all proxies and Veeam 365 server
 .EXAMPLE 
    Get-DCVB365StorageAccount
 #>
 function Get-DCVB365TeamsGraphAPIState
 {
     Write-host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Teams graph api state"
 
     #VBM365 server
     [PSCustomObject]@{
         Server        = $env:COMPUTERNAME 
         TeamsGraphApi = (Get-VBOServer).IsTeamsGraphAPIBackupEnabled
     }
     $Proxy = Get-VBOProxy 
     foreach ($obj in $Proxy)
     {
         If ($obj.Hostname -ne $env:COMPUTERNAME)
         {
             [PSCustomObject]@{
                 Server = $obj.Hostname
                 TeamsGraphApi = $obj.IsTeamsGraphAPIBackupEnabled
             }
         }
     }
 }




##########################################################################


<#
.SYNOPSIS
   Generate HTML report
.DESCRIPTION
   Use all variable to build html report with CSS style 
.EXAMPLE
   Get-HTMLReport -Path "C:\temp\report.html"
#>

Function Get-HTMLReport
{
    [CmdletBinding()]

    Param
    (
        #HTML file path
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$Path

    )
    Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm") - VBM365 Building HTML"
    #region HTML
    # chrisdent: STYLE: In the code below `CreateArray` is something of a misleading function name.
    # chrisdent: ENHANCEMENT: Perhaps consider using a string builder.
 @"
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
    <title>$HTMLTitle</title>
    $HTMLCSS
    </head>
    <body>
    <br><br><br><br>

    <h1>VEEAM Backup for Microsoft 365 Report</h1>

    <h3> Summary </h3>
    $($DCVB365Summary)

    <h3> License </h3>
    $DCVB365License

    <h3> SMTP </h3>
    $DCVB365SMTP

    <h3> Notification </h3>
    $DCVB365Notification

    <h3> Web Proxy </h3>
    $DCVB365InternetProxy

    <h3> REST API </h3>
    $DCVB365RestAPI

    <h3> Restore portal </h3>
    $DCVB365RestorePortal

    <h3> Restore operator authentication </h3>
    $DCVB365OperatorAuthentication

    <h3> Repository </h3>
    $DCVB365Repository

    <h3> Object Repository </h3>
    $DCVB365ObjectRepository

    <h3> Organisation </h3>
    $DCVB365Organization

    <h3> Proxy </h3>
    $DCVB365Proxy

    <h3> Backup job </h3>
    $DCVB365BackupJob

    <h3> Backup copy job </h3>
    $DCVB365BackupCopyJob

    <h3> Restore operators </h3>
    $DCVB365RestoreOperator

    <h3> Cloud storage account </h3>
    $DCVB365StorageAccount

    <h3> Encryption key </h3>
    $DCVB365EncryptionKey

    <h3> Teams graph API state </h3>
    $DCVB365TeamsGraphAPIState

    
    </body>
    </html>
"@ | Out-File -FilePath $HTMLReportPath

    Invoke-Item $HTMLReportPath

   
}
#endregion

#Write here all function that need to be displayed in all reports types

$DCVB365Summary                   = Get-DCVB365Summary | ConvertTo-Html -Fragment
$DCVB365Organization              = Get-DCVB365Organization | Sort-object Name | ConvertTo-Html -Fragment
$DCVB365BackupJob                 = Get-DCVB365BackupJob | Sort-object Name | ConvertTo-Html -Fragment
$DCVB365Proxy                     = Get-DCVB365Proxy | Sort-object Name | ConvertTo-Html -Fragment
$DCVB365Repository                = Get-DCVB365Repository | Sort-object Name | ConvertTo-Html -Fragment
$DCVB365License                   = Get-DCVB365License | ConvertTo-Html -Fragment
$DCVB365RestoreOperator           = Get-DCVB365RestoreOperator | ConvertTo-Html -Fragment
$DCVB365RestAPI                   = Get-DCVB365RestAPI  | ConvertTo-Html -Fragment
$DCVB365RestorePortal             = Get-DCVB365RestorePortal | ConvertTo-Html -Fragment
$DCVB365OperatorAuthentication    = Get-DCVB365OperatorAuthentication | ConvertTo-Html -Fragment
$DCVB365InternetProxy             = Get-DCVB365InternetProxy | ConvertTo-Html -Fragment
$DCVB365SMTP                      = Get-DCVB365SMTP | ConvertTo-Html -Fragment
$DCVB365Notification              = Get-DCVB365Notification | ConvertTo-Html -Fragment
$DCVB365ObjectRepository          = Get-DCVB365ObjectRepository | Sort-object Name | ConvertTo-Html -Fragment
$DCVB365BackupCopyJob             = Get-DCVB365BackupCopyJob | Sort-object Name | ConvertTo-Html -Fragment
$DCVB365StorageAccount            = Get-DCVB365StorageAccount | Sort-object Type | ConvertTo-Html -Fragment
$DCVB365EncryptionKey             = Get-DCVB365EncryptionKey | ConvertTo-Html -Fragment
$DCVB365TeamsGraphAPIState        = Get-DCVB365TeamsGraphAPIState | ConvertTo-Html -Fragment


#Create HTML Report.
Get-HTMLReport -Path $HTMLReportPath

Disconnect-VBOServer




