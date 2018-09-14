<#
.SYNOPSIS  
    PowerShell script that creates a new Self Service Tenant and Default Policy Jobs in the Veeam Self Service Portal
.DESCRIPTION
    Creates a new tenant via the Veeam Enterprise Manager API in the vCD Self Service Portal. 
    Then created a number of vCD Backup and/or Backup Copy Jobs for that tenant at the Virtual Datacenter level. 
    Final step is to import Backup Jobs into Self Service Portal

    To generate the service-veeam.xml file needed to authenticate against the API you need to do the following to generate the file:

    $Credential = Get-Credential
    cmdlet Get-Credential at command pipeline position 1
    Supply values for the following parameters:
    User: service.veeam
    Password for user service.veeam: ***********
    $Credential | Export-CliXml -Path service-veeam.xml

    Note: If Tenant and Jobs are already created new jobs will be added with the same names
    Note: To be run on a Server installed with the Veeam Backup & Replicaton Console

    Set desired Veeam variables and vCloud Director, Repository and Quota tenant Variables in config.json 

.NOTES
    Version:        1.0
    Author:         Anthony Spiteri
    Twitter:        @anthonyspiteri
    Github:         anthonyspiteri
    Credits:        Markus Kraus @vMarkus_K (Self Service Portal Tenant Add)
                    Hal Yaman
.LINK
    https://mycloudrevolution.com/2017/08/08/veeam-self-service-backup-portal-fuer-vcloud-director/
    https://gist.github.com/mycloudrevolution/ac7b992d005d78fc196afc76a9491918
    https://cloudoasis.com.au/2018/09/01/create-veeam-vcd-job-powershell/

.EXAMPLE
    .\new_vcd_self_service_client.ps1
#>

if (!(get-pssnapin -name VeeamPSSnapIn -erroraction silentlycontinue)) 
        {
         add-pssnapin VeeamPSSnapIn
        }

$StartTime = Get-Date
$config = Get-Content config.json | ConvertFrom-Json

function AddvCDSelfServiceTenant
{
    [Boolean] $HTTPS = $True
    [String] $Server = $config.VBRDetails.VBRServer
    [String] $Port = $config.VBRDetails.VBREMPort
    [PSCredential] $Credential = Import-CliXml service-veeam.xml
    [String] $Org = $config.TenantDetails.vCDOrg
    [String] $JobTemplateName = $config.VBRDetails.JobTemplate 
    [String] $RepoName = $config.VBRDetails.Repository 
    [Long] $Quota = $config.TenantDetails.Quota
 
    #region: Workaround for SelfSigned Cert
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
#endregion
 
#region: Switch Http/s
if ($HTTPS -eq $True) {$Proto = "https"} else {$Proto = "http"}
#endregion
 
#region: POST - Authorization
[String] $URL = $Proto + "://" + $Server + ":" + $Port + "/api/sessionMngr/?v=latest"
Write-Verbose "Authorization Url: $URL"
$Auth = @{uri = $URL;
            Method = 'POST';
            }
$AuthXML = Invoke-WebRequest @Auth -ErrorAction Stop -Credential $Credential
#endregion
 
 
#region: GET - Get BR Server
"Get All Registered Veeam Server..."
[String] $URL = $Proto + "://" + $Server + ":" + $Port + "/api/backupServers?format=Entity"
Write-Verbose "Get BR Server Url: $URL"
$BRServer = @{uri = $URL;
                   Method = 'GET';
    Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId']}
           } 
 
$BRServerXML = Invoke-RestMethod @BRServer -ErrorAction Stop
 
#$BRServerXML.BackupServers.BackupServer | select Name, UID, Port, Version
 
$BRServerUID = $BRServerXML.BackupServers.BackupServer.UID
#endregion

#region: GET - Get BR Template Job
"Get all Backup Jobs to filter Template..."
[String] $URL = $Proto + "://" + $Server + ":" + $Port + "/api/jobs?format=Entity"
$BRJobs = @{uri = $URL;
                   Method = 'GET';
    Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId']}
           } 
 
$BRJobsXML = Invoke-RestMethod @BRJobs -ErrorAction Stop
 
$BRJobsXML.Jobs.Job | select Name, UID, Platform | ft -AutoSize
 
foreach ($Job in $BRJobsXML.Jobs.job) {
    if ($job.name -eq $JobTemplateName) {$JobTemplateXML = $Job} 
}
 
$BRJobUID = $JobTemplateXML.uid
#endregion
 
#region: GET - Get BR Repo
"Get all Backup Repositories to filter Selected..."
[String] $URL = $Proto + "://" + $Server + ":" + $Port + "/api/repositories?format=Entity"
$BRRepos = @{uri = $URL;
                   Method = 'GET';
    Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId']}
           } 
 
$BRReposXML = Invoke-RestMethod @BRRepos -ErrorAction Stop
 
foreach ($Repo in $BRReposXML.Repositories.Repository) {
    if ($Repo.name -eq $RepoName) {$RepoXML = $Repo} 
}
 
$BRRepoUID = $RepoXML.uid
#endregion
 
#region: POST - Add vCloud Org
"Create vCloud Org..."
[String] $URL = $Proto + "://" + $Server + ":" + $Port + "/api/vCloud/orgConfigs"
$VCloudOrganizationConfigCreate = @{uri = $URL;
                   Method = 'POST';
    Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId'];
                                'Content-Type' = 'application/xml'}
Body = @"
<VCloudOrganizationConfigCreateSpec xmlns="http://www.veeam.com/ent/v1.0" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <OrganizationName>$org</OrganizationName>
    <BackupServerUid>$BRServerUID</BackupServerUid>
    <RepositoryUid>$BRRepoUID</RepositoryUid>
    <QuotaGb>$Quota</QuotaGb>
    <TemplateJobUid>$BRJobUID</TemplateJobUid>
    <JobSchedulerType>Full</JobSchedulerType>
</VCloudOrganizationConfigCreateSpec>
"@
           } 
 
 $VCloudOrganizationConfigCreateXML = Invoke-RestMethod @VCloudOrganizationConfigCreate
#endregion
 
#region: GET - Get vCloud Org
"Get all vCloud Org`s..."
[String] $URL = $Proto + "://" + $Server + ":" + $Port + "/api/vCloud/orgConfigs?format=Entity"
$VCloudOrganizationConfig = @{uri = $URL;
                   Method = 'GET';
    Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId']}
           } 
 
$VCloudOrganizationConfigXML = Invoke-RestMethod @VCloudOrganizationConfig
 
Write-Host $config.TenantDetails.vCDOrg "Enabled in vCD Self Service Portal" -ForegroundColor Green -BackgroundColor Black
#endregion
}

function Connect-VBR-Server
    {
        #Connect to the Backup & Replication Server
        Disconnect-VBRServer
        Connect-VBRServer -Server $config.VBRDetails.VBRServer -user $config.VBRDetails.Username -password $config.VBRDetails.Password -EA SilentlyContinue
    }

function CreatevCDBackupPolicyJobs
    {
        #Set environment variables
        $vcloudServerName = $config.TenantDetails.vCDServer
        $backupRepoName = $config.VBRDetails.Repository
        $orgVdcName = $config.TenantDetails.vCDOrgvDC
        
        #Set Veeam Backup Infrastructure items
        $vcdServer = get-vbrserver -name $vcloudServerName
        $vCDServer = Get-VBRServer -Type vcdSystem
        $vCDORG = Find-VBRvCloudEntity -Server $vCDServer -OrganizationVdc | where {$_.name -eq $config.TenantDetails.vCDOrgvDC}

        function CreatePolicyJob1
        {
            $JobName = $config.vCDJobDetails.Job1+"-"+$config.TenantDetails.vCDOrg
            $JobDescription = 'Default '+$config.vCDJobDetails.Job1
            
            #Set Retention Policy
            $retention = New-VBRJobOptions -ForBackupJob
            $retention.BackupStorageOptions.RetainCycles = $config.vCDJobDetails.RestorePoints1
            
            #Create Job
            $vbrJob = Add-VBRvCloudJob -Entity $vCDORG -Name $JobName -BackupRepository $config.VBRDetails.Repository -Description $JobDescription
            
            #Set Retention
            $vbrJob | % { Set-VBRJobOptions -Job $_ -Options $retention }

            Write-Host $JobName "Created" -ForegroundColor Green -BackgroundColor Black
        }

        function CreatePolicyJob2
        {
            $JobName = $config.vCDJobDetails.Job2+"-"+$config.TenantDetails.vCDOrg
            $CopyJobName = $config.vCDJobDetails.CopyJob2+"-"+$config.TenantDetails.vCDOrg+"-BCJ"
            $JobDescription = 'Default '+$config.vCDJobDetails.Job2
            
            #Set Retention Policy
            $retention = New-VBRJobOptions -ForBackupJob
            $retention.BackupStorageOptions.RetainCycles = $config.vCDJobDetails.RestorePoints2

            $vbrJob = Add-VBRvCloudJob -Entity $vCDORG -Name $JobName -BackupRepository $config.VBRDetails.Repository -Description $JobDescription

            #Set Retention
            $vbrJob | % { Set-VBRJobOptions -Job $_ -Options $retention }

            Write-Host $JobName "Created" -ForegroundColor Green -BackgroundColor Black
            $JobName2 = $JobName

            Add-VBRvCloudBackupCopyJob -DirectOperation -Name $CopyJobName -BackupJob $JobName -Repository $config.VBRDetails.CopyJobRepository 

            $Job = Get-VBRJob -Name $CopyJobName
            $Options = $Job.GetOptions()
            $Options.GenerationPolicy.RetentionPolicyType = 'GFS'
            $Options.GenerationPolicy.GFSWeeklyBackups = $vCDJobDetails.GFSWeeklyBackups
            $Options.GenerationPolicy.GFSMonthlyBackups = $vCDJobDetails.GFSMonthlyBackups
            $Options.GenerationPolicy.GFSQuarterlyBackups = $vCDJobDetails.GFSQuarterlyBackups
            $Options.GenerationPolicy.GFSYearlyBackups = $vCDJobDetails.GFSYearlyBackups
            $Options.GenerationPolicy.EnableRechek = $True
            $Options.GenerationPolicy.RecheckDays = [System.DayOfWeek] 'Friday', 'Monday'
            $Options.GenerationPolicy.RecheckScheduleKind = 'Monthly'
            $Options.GenerationPolicy.SyncIntervalStartTime = '14:30:00'
            $Options.GenerationPolicy.SimpleRetentionRestorePoints = $vCDJobDetails.SimpleRetentionRestorePoints
            $Options.GenerationPolicy.WeeklyBackupDayOfWeek = 'Thursday'
            $Options.GenerationPolicy.RecoveryPointObjectiveUnit = 'Day'
            $Options.GenerationPolicy.RecoveryPointObjectiveValue = $vCDJobDetails.RecoveryPointObjectiveValue
            $Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.DayNumberInMonth = 'Third'
            $Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.DayOfWeek = 'Wednesday'
            $Options.GenerationPolicy.RecheckBackupMonthlyScheduleOptions.Months = [Veeam.Backup.Common.Emonth] 'January', 'February'
            Set-VBRJobOptions $Job $Options | Out-Null

            Get-VBRJob -Name $CopyJobName | Enable-VBRJob

            Write-Host $CopyJobName "Created" -ForegroundColor Green -BackgroundColor Black
        }

    CreatePolicyJob1
    CreatePolicyJob2
    }

function ImportvCDBackupPolicyJobs
    {    
        $Job1 = $config.vCDJobDetails.Job1+"-"+$config.TenantDetails.vCDOrg
        $Job2 = $config.vCDJobDetails.Job2+"-"+$config.TenantDetails.vCDOrg

        $JobArray =@($Job1,$Job2)

        for ($i=0; $i -lt $JobArray.length; $i++) 
            {
                $JobEntity = Get-VBRJob -Name $JobArray[$i]
                Set-VBRvCloudOrganizationJobMapping -Action Map -Job $JobEntity | Out-Null
                Write-Host $JobArray[$i] "Imported" -ForegroundColor Green -BackgroundColor Black
            }
    }

AddvCDSelfServiceTenant
Connect-VBR-Server
CreatevCDBackupPolicyJobs
ImportvCDBackupPolicyJobs

clear

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)
Write-Host "-:: Complete ::-" -ForegroundColor Green -BackgroundColor Black
Write-Host "-:: Total Execution Time ::-" $duration -ForegroundColor Green -BackgroundColor Black
Write-Host