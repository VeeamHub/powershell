#API_Backup_Session_Report
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

$server = 'ausveeambem'
$username = 'jhoughes'
$report_filepath = 'D:\temp\api_backup_session_report.csv'

#get the api
$r_api = Invoke-WebRequest -Method Get -Uri "https://$($server):9398/api/" 
$r_api_xml = [xml]$r_api.Content
$r_api_links = @($r_api_xml.EnterpriseManager.SupportedVersions.SupportedVersion | Where-Object { $_.Name -eq "v1_4" })[0].Links

#login
$r_login = Invoke-WebRequest -method Post -Uri $r_api_links.Link.Href -Credential (Get-Credential -Message "Basic Auth" -UserName "$username")

$sessionheadername = "X-RestSvcSessionId"
$sessionid = $r_login.Headers[$sessionheadername]

#content
$r_login_xml = [xml]$r_login.Content
$r_login_links = $r_login_xml.LogonSession.Links.Link
$r_login_links_base = $r_login_links | Where-Object {$_.Type -eq 'EnterpriseManager'}

#get list of all backup jobs
$r_jobs_query = $r_login_links_base.Href + 'query?type=Job&filter=JobType==Backup'
$r_jobs = Invoke-WebRequest -Method Get -Headers @{$sessionheadername = $sessionid} -Uri $r_jobs_query
$r_jobs_xml = [xml]$r_jobs.Content
$r_jobs_list = $r_jobs_xml.QueryResult.Refs.Ref.Href

#parse job list to get backup sessions
foreach ($r_jobs_link in $r_jobs_list) {

    #gather included tags detail
    $r_job_detail_link = Invoke-WebRequest -Method Get -Headers @{$sessionheadername = $sessionid} -Uri $(($r_jobs_link) + "?format=Entity")
    $r_job_detail_link_xml = [xml]$r_job_detail_link.Content
    $r_job_detail_included_tags = $r_job_detail_link_xml.Job.JobInfo.BackupJobInfo.Includes.ObjectInJob | Where-Object HierarchyObjRef -like "*InventoryServiceTag*"

    #gather backup session entities
    $r_backup_session_entity_list = @()
    $r_backup_session_link = Invoke-WebRequest -Method Get -Headers @{$sessionheadername = $sessionid} -Uri $(($r_jobs_link) + "/backupSessions")
    $r_backup_session_link_xml = [xml]$r_backup_session_link.Content
    $r_backup_session_entity_list = $r_backup_session_link_xml.EntityReferences.Ref.Links.Link | Where-Object Type -eq 'BackupJobSession' | Select-Object -ExpandProperty Href

    #gather task sessions
    foreach ($r_backup_session_entity in $r_backup_session_entity_list) {
        $r_backup_session_entity_link = Invoke-WebRequest -Method Get -Headers @{$sessionheadername = $sessionid} -Uri $r_backup_session_entity
        $r_backup_session_entity_link_xml = [xml]$r_backup_session_entity_link
        $r_task_session_ref = $r_backup_session_entity_link_xml.BackupJobSession.Links.Link | Where-Object Type -eq BackupTaskSessionReferenceList | Select-Object -ExpandProperty Href
        $r_task_session_link = Invoke-WebRequest -Method Get -Headers @{$sessionheadername = $sessionid} -Uri $r_task_session_ref
        $r_task_session_link_xml = [xml]$r_task_session_link
        $r_task_session_list = $r_task_session_link_xml.EntityReferences.Ref.Href
      
        #gather task session details
        foreach ($r_task_session in $r_task_session_list) {
            $r_task_session_entity = $($r_task_session + "?format=Entity")
            $r_task_session_entity_link = Invoke-WebRequest -Method Get -Headers @{$sessionheadername = $sessionid} -Uri $r_task_session_entity
            $r_task_session_entity_link_xml = [xml]$r_task_session_entity_link
            $r_task_session_detail = $r_task_session_entity_link_xml.BackupTaskSession

            #gather VM restore points
            $r_vm_restore_point_link = ($r_task_session_entity_link_xml.BackupTaskSession.Links.Link | Where-Object Type -eq VmRestorePoint)

            #gather VM restore point entities & details
            if ([bool]$r_vm_restore_point_link) {
                $r_vm_restore_point_entity_link = $r_vm_restore_point_link | Select-Object -ExpandProperty Href
                $r_vm_restore_point_entity = Invoke-WebRequest -Method Get -Headers @{$sessionheadername = $sessionid} -Uri $r_vm_restore_point_entity_link
                $r_vm_restore_point_entity_xml = [xml]$r_vm_restore_point_entity
                $r_vm_restore_point_entity_detail = $r_vm_restore_point_entity_xml.VmRestorePoint

                $r_vm_backup_file_link = $(($r_vm_restore_point_entity_xml.VmRestorePoint.Links.Link | Where-Object Href -like "*backupFiles*" | Select-Object -ExpandProperty Href) + "?format=Entity")
                $r_vm_backup_file_entity = Invoke-WebRequest -Method Get -Headers @{$sessionheadername = $sessionid} -Uri $r_vm_backup_file_link
                $r_vm_backup_file_entity_xml = [xml]$r_vm_backup_file_entity
                $r_vm_backup_file_entity_detail = $r_vm_backup_file_entity_xml.BackupFile

                #VM restore point, task session, & job details
                $backup_session_detail = New-Object PSObject -Property @{
                    'VMName'                  = $r_vm_restore_point_entity_detail.VMName
                    'BackupCreationTime(UTC)' = $r_task_session_detail.CreationTimeUTC
                    'BackupEndTime(UTC)'      = $r_task_session_detail.EndTimeUTC
                    'State'                   = $r_task_session_detail.State
                    'Result'                  = $r_task_session_detail.Result
                    'Reason'                  = $r_task_session_detail.Reason
                    'TotalSize'               = $r_vm_backup_file_entity_detail.BackupSize
                    'JobAlgorithm'            = $r_vm_restore_point_entity_detail.Algorithm
                    'RestorePointType'        = $r_vm_restore_point_entity_detail.PointType
                    'JobName'                 = $r_job_detail_link_xml.Job.Name
                    'IncludedTags'            = $r_job_detail_included_tags.Name
                }
                $backup_session_detail | Export-Csv -Path $report_filepath -NoTypeInformation -Append
            }
    
        }

    }

}
