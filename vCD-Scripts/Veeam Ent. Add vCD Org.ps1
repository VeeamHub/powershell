[String] $Server = "<Veeam ent. Manager IP / name>"
[Boolean] $HTTPS = $True
[String] $Port = "9398"
[PSCredential] $Credential = Get-Credential
[String] $Org = "<Your vCloud Director Org>"
[String] $JobTemplateName = "<Your Job name>" 
[String] $RepoName = "<Your Repository name>" 
[Long] $Quota = 500

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
"`nGet All Registered Veeam Server..."
[String] $URL = $Proto + "://" + $Server + ":" + $Port + "/api/backupServers?format=Entity"
Write-Verbose "Get BR Server Url: $URL"
$BRServer = @{uri = $URL;
                   Method = 'GET';
				   Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId']}
           } 
	
$BRServerXML = Invoke-RestMethod @BRServer -ErrorAction Stop

$BRServerXML.BackupServers.BackupServer | select Name, UID, Port, Version

$BRServerUID = $BRServerXML.BackupServers.BackupServer.UID
#endregion



#region: GET - Get BR Template Job
"`nGet all Backup Jobs to filter Template..."
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
"`nGet all Backup Repositories to filter Selected..."
[String] $URL = $Proto + "://" + $Server + ":" + $Port + "/api/repositories?format=Entity"
$BRRepos = @{uri = $URL;
                   Method = 'GET';
				   Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId']}
           } 
	
$BRReposXML = Invoke-RestMethod @BRRepos -ErrorAction Stop

$BRReposXML.Repositories.Repository | select Name, UID, Kind

foreach ($Repo in $BRReposXML.Repositories.Repository) {
    if ($Repo.name -eq $RepoName) {$RepoXML = $Repo} 
}

$BRRepoUID = $RepoXML.uid
#endregion

#region: POST - Add vCloud Org
"`nCreate vCloud Org..."
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

	$VCloudOrganizationConfigCreateXML = Invoke-RestMethod @VCloudOrganizationConfigCreate -ErrorAction Stop
#endregion

#region: GET - Get vCloud Org
"`nGet all vCloud Org`s..."
[String] $URL = $Proto + "://" + $Server + ":" + $Port + "/api/vCloud/orgConfigs?format=Entity"
$VCloudOrganizationConfig = @{uri = $URL;
                   Method = 'GET';
				   Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId']}
           } 
	
$VCloudOrganizationConfigXML = Invoke-RestMethod @VCloudOrganizationConfig -ErrorAction Stop

$VCloudOrganizationConfigXML.VCloudOrganizationConfigs.VCloudOrganizationConfig | select Name, UID, QuotaGb | ft -AutoSize
#endregion