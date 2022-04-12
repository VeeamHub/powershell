#API_Start_Backup_Job
Add-Type @"
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

$server = 'vemserver'
$username = 'username'
$job_name = 'jobname'

#get the api
$r_api = Invoke-WebRequest -Method Get -Uri "https://$($server):9398/api/"
$r_api_xml = [xml]$r_api.Content
$r_api_links = @($r_api_xml.EnterpriseManager.SupportedVersions.SupportedVersion | Where-Object { $_.Name -eq "v1_4" })[0].Links

#login
$r_login = Invoke-WebRequest -Method Post -Uri $r_api_links.Link.Href -Credential (Get-Credential -Message "Basic Auth" -UserName "$username")

$sessionheadername = "X-RestSvcSessionId"
$sessionid = $r_login.Headers[$sessionheadername]

#content
$r_login_xml = [xml]$r_login.Content
$r_login_links = $r_login_xml.LogonSession.Links.Link
$r_login_links_base = $r_login_links | Where-Object { $_.Type -eq 'EnterpriseManager' }

#get list of all backup jobs
$r_jobs_query = $r_login_links_base.Href + 'query?type=Job&filter=JobType==Backup'
$r_jobs = Invoke-WebRequest -Method Get -Headers @{$sessionheadername = $sessionid } -Uri $r_jobs_query
$r_jobs_xml = [xml]$r_jobs.Content
$r_jobs_list = $r_jobs_xml.QueryResult.Refs.Ref
$r_sql_job = $r_jobs_list | Where-Object Name -EQ $job_name
$r_sql_job_start_link = $(($r_sql_job.Href) + "?action=start")

Invoke-WebRequest -Method Post -Headers @{$sessionheadername = $sessionid } -Uri $r_sql_job_start_link
