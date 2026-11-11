#API_Backup_Size_Report
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

$server = 'localhost'
$username = 'username'
$report_details = @()

#get the api
$r_api = Invoke-WebRequest -Method Get -Uri "https://$($server):9398/api/"
$r_api_xml = [xml]$r_api.Content
$r_api_links = @($r_api_xml.EnterpriseManager.SupportedVersions.SupportedVersion | Where-Object { $_.Name -eq "v1_3" })[0].Links

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

#parse job list to get backup sessions
$r_backup_session_entities = @()
foreach ($r_jobs_link in $r_jobs_list) {
  $r_job_session_link = Invoke-WebRequest -Method Get -Headers @{$sessionheadername = $sessionid } -Uri $(($r_jobs_link.Href) + "/backupSessions")
  $r_job_session_link_xml = [xml]$r_job_session_link.Content
  $r_job_session_list = $r_job_session_link_xml.EntityReferences.Ref

  #parse backup sessions to retrieve entities
  foreach ($r_job_session in $r_job_session_list) {
    $r_job_session_entity = $($r_job_session.Href + "?format=Entity")
    $r_backup_session_entities += $r_job_session_entity
  }


  #parse backup sessions to retrieve restore point entities, get associated VM restore point objects
  $r_backup_file_ref_list = @()
  foreach ($r_backup_session in $r_backup_session_entities) {
    $r_backup_session = Invoke-WebRequest -Method Get -Headers @{$sessionheadername = $sessionid } -Uri $r_backup_session
    $r_backup_session_xml = [xml]$r_backup_session.Content
    $r_restore_point_entity_all = ($r_backup_session_xml.BackupJobSession.Links.Link | Where-Object Type -EQ RestorePointReference)
    if ([bool]$r_restore_point_entity_all) {
      $r_restore_point_entity_parsed = $r_restore_point_entity_all | Select-Object -ExpandProperty Href
      $r_restore_point_entity = $($r_restore_point_entity_parsed + '/backupFiles')
      $r_backup_file_ref_list += $r_restore_point_entity
    }
  }

  #get backup file details
  $r_backup_file_entity_list = @()
  foreach ($r_backup_file_ref in $r_backup_file_ref_list) {

    $r_backup_file_entity = Invoke-WebRequest -Method Get -Headers @{$sessionheadername = $sessionid } -Uri $r_backup_file_ref
    $r_backup_file_entity_xml = [xml]$r_backup_file_entity.Content
    $r_backup_file_entity_all = $r_backup_file_entity_xml.EntityReferences.Ref.Links.Link | Where-Object Type -EQ 'BackupFile'  | Select-Object -ExpandProperty Href
    $r_backup_file_entity_list += $r_backup_file_entity_all
  }


  $r_backup_file_details = @()
  foreach ($r_backup_file in $r_backup_file_entity_list) {

    $r_backup_file_obj = Invoke-WebRequest -Method Get -Headers @{$sessionheadername = $sessionid } -Uri $r_backup_file
    $r_backup_file_obj_xml = [xml]$r_backup_file_obj.Content
    $r_backup_file_obj_detail = $r_backup_file_obj_xml.BackupFile
    $r_backup_file_details += $r_backup_file_obj_detail

    foreach ($r_backup_file_detail in $r_backup_file_details) {
      #Capturing details for final results
      $backup_file_detail = New-Object PSObject -Property @{
        'JobName'            = $r_jobs_link.Name
        'FileName'           = $r_backup_file_detail.Name
        'BackupSize'         = $r_backup_file_detail.BackupSize
        'DataSize'           = $r_backup_file_detail.DataSize
        'DeduplicationRatio' = $r_backup_file_detail.DeduplicationRatio
        'CompressRatio'      = $r_backup_file_detail.CompressRatio
        'FileType'           = $r_backup_file_detail.FileType
        'CreationTimeUtc'    = $r_backup_file_detail.CreationTimeUtc
      }

      $report_details += $backup_file_detail
    }
  }
}

Write-Output $report_details | Select-Object 'JobName', 'FileName', 'BackupSize', 'DataSize', 'DeduplicationRatio', 'CompressRatio', 'FileType', 'CreationTimeUTC'