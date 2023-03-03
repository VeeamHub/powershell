<#
.SYNOPSIS
----------------------------------------------------------------------
Project "VeeamPorter" - Import/Export jobs across Veeam Backup Servers
----------------------------------------------------------------------
Version : 0.81 (September 11th, 2019)
Requires: Veeam Backup & Replication v9.5 Update 4 or later
Author  : Danilo Chiavari (@danilochiavari)
Blog    : https://www.danilochiavari.com
GitHub  : https://www.github.com/dchiavari

.DESCRIPTION

*** Please note this script is unofficial and is not created nor supported by Veeam Software. ***
This script copies backup jobs across different backup servers, allowing you to "transfer" them without doing a full Configuration Restore.
Before use, please make sure source and target Veeam Backup Server have the same virtual infrastructure(s) configured and the same proxies/repositories.
For help or comments, contact the author on Twitter (@danilochiavari) or via e-mail (danilo.chiavari -at- gmail (.) com)

This script has been tested only with the following versions of Veeam Backup & Replication:
   - v9.5 Update 4   (build 9.5.4.2615)
   - v9.5 Update 4a  (build 9.5.4.2753)
   - v9.5 Update 4b  (build 9.5.4.2866)

Known Issues / Limitations:
   - Only primary Backup Jobs are currently supported (no Backup Copy Jobs, no Replication Jobs, no SureBackup Jobs, etc.)
   - Only VMware vSphere platform is currently supported (no Hyper-V jobs, no Windows/Linux Agents Jobs, etc.)

.PARAMETER target_srv
(mandatory) The target Veeam Backup Server where jobs will be created/imported. Either host name or IP address can be used.

.PARAMETER source_srv
(optional) The source Veeam Backup Server from where jobs will be exported. If it is not specified, local machine (localhost) is assumed.

.PARAMETER job_suffix
(optional) Suffix to be appended to job names created in the target Veeam Backup Server. If it is not specified, "_imported" is used.

.EXAMPLE
PS> .\veeamporter.ps1 -source_srv SOURCESERVER -target_srv TARGETSERVER

.EXAMPLE
PS> .\veeamporter.ps1 -source_srv OLDSERVER -target_srv NEWSERVER -job_suffix "_new"

.EXAMPLE
PS> .\veeamporter.ps1 -target_srv NEWSERVER -job_suffix $null
#>


Param (
   [Parameter(Mandatory=$true)][string]$target_srv,
   [string]$source_srv = $env:computerName,
   [string]$job_suffix = "_imported"
)

#Logging to File Initialization
$ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-Not (Test-Path $ScriptFolder\Logs) ) {New-Item -Path $ScriptFolder\Logs -ItemType Directory >$null 2>&1}
Start-Transcript -Path $ScriptFolder\Logs\VeeamPorter-$(Get-Date -format yyyyMMdd_HHmm).txt -Append

asnp VeeamPSSnapin

Write-Host -ForegroundColor Magenta "Connecting to TARGET backup server" $target_srv `n

#Try to connect to TARGET backup server. If attempt fails due to current credentials not being valid, Automatically ask for credentials and use them from now onwards.
#If attempt fails for any other reason, script will abort reporting the error code / reason
Try {Connect-VBRServer -Server $target_srv}
Catch {
    If ($_.Exception.ToString() -like "*logon attempt failed*") {
        Write-Host -ForegroundColor Yellow "Current credentials not valid for TARGET server" $target_srv "- please enter credentials"
        $target_cred = Get-Credential
        Try {Connect-VBRServer -Server $target_srv -Credential $target_cred -ErrorAction Stop}
        Catch {
            Write-Host -ForegroundColor Red "ERROR: $_"
            Disconnect-VBRServer
            Stop-Transcript
            Throw $_
        }

    }      
}

Disconnect-VBRServer

Write-Host -ForegroundColor Magenta "Connecting to SOURCE backup server" $source_srv `n

#Try to connect to SOURCE backup server. If attempt fails due to current credentials not being valid, Automatically ask for credentials and use them from now onwards.
#If attempt fails for any other reason, script will abort reporting the error code / reason
Try {Connect-VBRServer -Server $source_srv}
Catch {
    If ($_.Exception.ToString() -like "*logon attempt failed*") {
        Write-Host -ForegroundColor Yellow "Current credentials not valid for SOURCE server" $source_srv "- please enter credentials"
        $source_cred = Get-Credential
        Try {Connect-VBRServer -Server $source_srv -Credential $source_cred -ErrorAction Stop}
        Catch {
            Write-Host -ForegroundColor Red "ERROR: $_"
            Disconnect-VBRServer
            Stop-Transcript
            Throw $_
        }
        
    }      
}

#Get all the existing Backup Jobs in an array
$jobs = @()
$jobs = Get-VBRJob | ? {$_.JobType -eq "Backup"} | Select-Object -Property Name,TypeToString,Description | Sort-Object -Property Name | Out-GridView -PassThru -Title "*** SELECT JOBS TO IMPORT/EXPORT ***"
if ($jobs -eq $null) {Write-Host -ForegroundColor Yellow "No jobs selected - Exiting..."; Disconnect-VBRServer; Exit}

$jobs_number = $jobs.Count
if ($jobs_number -eq $null) {$jobs_number = 1}

$jobs_counter = 1

#Cycle through selected backup jobs to gather information and options
ForEach ($job in $jobs) {
    
    Write-Host -ForegroundColor Green "`n-------------------------------------------------------------------------"
    Write-Host -ForegroundColor Green "Processing job: '$($job.Name)' [$jobs_counter of $jobs_number]"
    Write-Host -ForegroundColor Green "-------------------------------------------------------------------------`n"
          
    $source_job = Get-VBRJob -Name $job.Name
    $source_job_repo = $source_job.FindTargetRepository()
    $source_job_schedule_status = $source_job.CanRunByScheduler()
    $source_job_options = Get-VBRJobOptions -Job $source_job
    $source_job_vss_options = Get-VBRJobVSSOptions -Job $source_job

    #If job schedule chaining is enabled, parse the previous job's name
    if ($source_job.PreviousJobIdInScheduleChain -ne $null) {
        $source_job_previous_job_name = $(Get-VBRJob | ? {$_.Id -eq $source_job.PreviousJobIdInScheduleChain}).Name
        Write-Host -ForegroundColor Yellow "Job chaining is active for this job. Previous job in schedule chain: " $source_job_previous_job_name "`n"
    }

    if ($source_job_options.JobOptions.SourceProxyAutoDetect -eq $False) {
        $source_job_source_proxies = Get-VBRJobProxy -Job $source_job
        Write-Host "Source Proxy automatic selection is disabled. Selected proxies:"
        $source_job_source_proxies | ft -Property Name, Type, ChassisType -AutoSize
    }

    $source_job_guest_proxies = $source_job.GetGuestProcessingProxyHosts()
    
    #Gather credentials specified at the job level (if any)
    if ($source_job_vss_options.AreLinCredsSet) {$source_job_vss_credentials_name = $(Get-VBRCredentials | ? {$_.Id -eq $source_job_vss_options.LinCredsId})[0].Name}
    elseif ($source_job_vss_options.AreWinCredsSet) {$source_job_vss_credentials_name = $(Get-VBRCredentials | ? {$_.Id -eq $source_job_vss_options.WinCredsId})[0].Name}
    else {$source_job_vss_credentials_name = ""}
    
    #Check if Backup File Encryption is enabled. If so, report the description of the key being used
    if ($source_job.BackupStorageOptions.StorageEncryptionEnabled -eq $True) {
        Write-Host -ForegroundColor Yellow "Source backup job has Encryption enabled, using key with the following description:" $(Get-VBREncryptionKey | ? {$_.Id -eq $source_job.Info.PwdKeyId}).Description `n
    } 
    
    #Cycle through all objects added to the backup job that's being processed, to gather information and options
    $source_job_objects = @()
    ForEach ($object in Get-VBRJobObject -Job $source_job) {
        $entry = "" | Select Name, Type, IsExcluded, IncludedDisks, VssOptions, ObjectCredentialsName, OracleCreds
        $entry.Name = $object.Name
        $entry.Type = $object.TypeDisplayName
        $entry.IsExcluded = $object.IsExcluded
        $entry.IncludedDisks = $object.DiskFilterInfo
        $entry.VssOptions = $object.VssOptions
        if ($object.VssOptions.AreLinCredsSet) {$entry.ObjectCredentialsName = $(Get-VBRCredentials | ? {$_.Id -eq $object.VssOptions.LinCredsId})[0].Name}
        elseif ($object.VssOptions.AreWinCredsSet) {$entry.ObjectCredentialsName = $(Get-VBRCredentials | ? {$_.Id -eq $object.VssOptions.WinCredsId})[0].Name}
        else {$entry.ObjectCredentialsName = ""}
        
        #Specific Oracle SYSDBA credentials handling for single VM/object. Default credentials id (= same as the object or job) is an all-zeroes GUID.
        #If that is detected, we just set the custom value "OracleCreds" to $null. Otherwise, we set it to the username of the credential matching the GUID.
        if ($object.VssOptions.OracleBackupOptions.SysdbaCredsId -eq "00000000-0000-0000-0000-000000000000") {$entry.OracleCreds = $null}
        else {$entry.OracleCreds = $(Get-VBRCredentials | ? {$_.Id -eq $object.VssOptions.OracleBackupOptions.SysdbaCredsId}).Name}
        
        $source_job_objects += $entry
    }

    Write-Host -ForegroundColor Cyan "Source objects found in job:" $source_job_objects.Count
    $source_job_objects | ft -AutoSize -Property Name, Type, IsExcluded, ObjectCredentialsName

    Disconnect-VBRServer
     
    if ($target_cred) {Connect-VBRServer -Server $target_srv -Credential $target_cred} else {Connect-VBRServer -Server $target_srv}
    
    #Create arrays for entities to be looked up / added to the job on the target server and for exclusions to be defined
    $target_job_entities = @()
    $target_job_exclusions = @()
    ForEach ($entity in $source_job_objects) {

        #Select the type of lookup based on the source object type (VM/Host, Datacenter, Cluster, Host, Folder, Tag, etc.)
        Switch ($entity.Type) {
            {'Virtual Machine', 'Host', 'Datacenter', 'Cluster' -contains $_} {
                if ($entity.IsExcluded -eq $True) {$target_job_exclusions += Find-VBRViEntity -Name $entity.Name}
                $target_job_entities += Find-VBRViEntity -Name $entity.Name
                }

            {'Folder', 'Template' -contains $_} {
                if ($entity.IsExcluded -eq $True) {$target_job_exclusions += Find-VBRViEntity -VMsAndTemplates -Name $entity.Name | ? {($_.IsTemplate -eq $True) -or ($_.Type -eq "Folder")} }
                $target_job_entities += Find-VBRViEntity -VMsAndTemplates -Name $entity.Name | ? {($_.IsTemplate -eq $True) -or ($_.Type -eq "Folder")}
                }
            
            {'Datastore', 'Datastore Cluster' -contains $_} {
                if ($entity.IsExcluded -eq $True) {$target_job_exclusions += Find-VBRViEntity -DatastoresAndVMs -Name $entity.Name | ? {($_.Type -eq "Datastore") -or ($_.Type -eq "StoragePod")} }
                $target_job_entities += Find-VBRViEntity -DatastoresAndVMs -Name $entity.Name | ? {($_.Type -eq "Datastore") -or ($_.Type -eq "StoragePod")}
                }

            {'Tag', 'Tag Category' -contains $_} {
                if ($entity.IsExcluded -eq $True) {$target_job_exclusions += Find-VBRViEntity -Tags -Name $entity.Name}
                $target_job_entities += Find-VBRViEntity -Tags -Name $entity.Name
                }
        }
    }

    Write-Host -ForegroundColor Cyan "Entities found in target backup server:" $target_job_entities.Count

    $target_job_entities | Select Name, Type | ft -AutoSize

    Write-Host -ForegroundColor Cyan "Exclusions found:" $target_job_exclusions.Count

    $target_job_exclusions | Select Name, Type | ft -AutoSize

    #Simple check to warn the user if source and target objects count don't match (most probably due to some objects not being found by the target backup server)
    if ($target_job_entities.count -ne $source_job_objects.count) {Write-Host -ForegroundColor Red "!! WARNING !! Number of source and target entities do not match. Check imported jobs, items may be missing!"`n}

    Write-Host -ForegroundColor Green "`nCreating target job:" $($job.Name + $job_suffix)`n

    #Look for Target job repository object based on type (simple, SOBR) and name on the source
    if ($source_job_repo.TypeDisplay -eq "Scale-out") {$target_job_repo = Get-VBRBackupRepository -Name $source_job_repo.Name -ScaleOut}
    else {$target_job_repo = Get-VBRBackupRepository -Name $source_job_repo.Name}
    
    #If Target repository is not found, prompt the user to choose a repository among the ones defined on the target backup server (both simple and SOBR)
    if ($target_job_repo -eq $null) {
        Write-Host -ForegroundColor Yellow "Original repository was NOT found on target server - Please select target repository: `n"
        $repo_list = @()
        $repo_list += Get-VBRBackupRepository -ScaleOut
        $repo_list += Get-VBRBackupRepository
        $selected_repo = $repo_list | Select-Object -Property Name, Description, FriendlyPath, TypeDisplay, Extent | Sort-Object -Property Name | Out-GridView -OutputMode Single -Title "*** SELECT TARGET REPOSITORY FOR JOB: $($job.Name + $job_suffix) ***"
        
        #If no repository is selected ("Cancel" was clicked) skip current job and proceed to the next
        if ($selected_repo -eq $null) {
            Write-Host -ForegroundColor Yellow "No repository selected - Import cancelled! Proceeding with next job..."
            Disconnect-VBRServer
            if ($source_cred) {Connect-VBRServer -Server $source_srv -Credential $source_cred}
            else {Connect-VBRServer -Server $source_srv}
            $jobs_counter++
            Continue
        }

        if ($selected_repo.Extent -ne $null) {$target_job_repo = Get-VBRBackupRepository -Name $selected_repo.Name -ScaleOut}
        else {$target_job_repo = Get-VBRBackupRepository -Name $selected_repo.Name}
    }

    #If source job has a description, copy it to the target job. If not, add an automatic "Created by VeeamPorter at [date/time]" description
    if (-Not $source_job.Description) {$target_job_description = "Created by VeeamPorter at $(Get-Date -format g)"} else {$target_job_description = $source_job.Description}

    if ( $(Get-VBRJob -Name $($job.Name + $job_suffix)) -ne $null) {
        Write-Host -ForegroundColor Red "Target job already exists - Import cancelled! Proceeding with next job..."
        Disconnect-VBRServer
        if ($source_cred) {Connect-VBRServer -Server $source_srv -Credential $source_cred}
        else {Connect-VBRServer -Server $source_srv}
        $jobs_counter++
        Continue
        }

    #Create the target backup job. The "-force" parameter is used to make sure the job is created even if there are location mismatches (potential Data Sovereignty violations)
    Add-VBRViBackupJob -Name $($job.Name + $job_suffix) -Entity $target_job_entities -BackupRepository $target_job_repo -Description $target_job_description -Force >$null 2>&1
    
    $target_job = Get-VBRJob -Name $($job.Name + $job_suffix)

    $target_job_vssoptions = $target_job.GetVssOptions()

    #if exclusions were defined in the source job, apply those exclusions to the target job (making sure both name and path of the objects match)
    if ($target_job_exclusions) {
        ForEach ($exclusion in $target_job_exclusions) {
            $target_job | Get-VBRJobObject | ? {($_.Name -eq $exclusion.Name) -and ($_.Location -eq $exclusion.Path)} | Remove-VBRJobObject
        }
    }

    $entity_counter = 0

    #Cycle through objects in target backup job
    ForEach ($entity in $($target_job | Get-VBRJobObject)) {

        #Reset object-specific credentials (fail-safe if custom credentials specified at source do not exist at the target)
        $source_job_objects[$entity_counter].vssoptions.ResetWinCreds()
        $source_job_objects[$entity_counter].vssoptions.ResetLinCreds()

        #Apply custom credentials (if any) and exclusions (if any) to the target object
        $entity.Update($source_job_objects[$entity_counter].vssoptions,$source_job_objects[$entity_counter].IncludedDisks,$true,$entity.info.Type) >$null 2>&1

        if ($source_job_objects[$entity_counter].ObjectCredentialsName) {
            if ($(Get-VBRCredentials | ? {$_.Name -eq $source_job_objects[$entity_counter].ObjectCredentialsName})) {
                Set-VBRJobObjectVssOptions -Object $entity -Credentials $(Get-VBRCredentials | ? {$_.Name -eq $source_job_objects[$entity_counter].ObjectCredentialsName})[0] >$null 2>&1
                }
        }
        
        #Set specific Oracle SYSDBA credentials for application-aware processing (if different than object-level or job-level guest credentials)
        #If Oracle SYSDBA credentials specified at source are not found at target, we just skip this part and set the SYSDBA credentials to be the same as the object/job ones (with a warning)
        if ($source_job_objects[$entity_counter].OracleCreds -ne $null) {
            if ($(Get-VBRCredentials -Name $source_job_objects[$entity_counter].OracleCreds).Count -eq 0) {
                Write-Host -ForegroundColor Yellow "`nWARNING: Oracle SYSDBA credentials specified at source for object [" $source_job_objects[$entity_counter].Name "] could not be found at target! `n Resetting SYSDBA credentials to be the same as object (or job) guest credentials...`n"
            }
            else {
                $target_object_vssoptions = $source_job_objects[$entity_counter].vssoptions
                $target_object_vssoptions.OracleBackupOptions.SysdbaCredsId = $(Get-VBRCredentials -Name $source_job_objects[$entity_counter].OracleCreds)[0].Id
                $entity.SetVssOptions($target_object_vssoptions)
            }
        }

        $entity_counter++
    }        
    
    $source_job_vss_options.ResetWinCreds()
    $source_job_vss_options.ResetLinCreds()
    
    #Apply job-level Guest Credentials (for App-Aware and/or indexing) (if any)
    if ($source_job_vss_credentials_name) {
        if ($(Get-VBRCredentials | ? {$_.Name -eq $source_job_vss_credentials_name})) {
            Set-VBRJobVssOptions -Job $($job.Name + $job_suffix) -Credentials $(Get-VBRCredentials | ? {$_.Name -eq $source_job_vss_credentials_name})[0] >$null 2>&1
            }
        else {Write-Host -ForegroundColor Red "`nWARNING: Job-level Guest OS Credentials were set at source, but were not found at target! `nDisabling App-Aware Processing and Indexing...`n"}
    }
    
    #Apply source job options to the target job
    Set-VBRJobOptions -Job $target_job -Options $source_job_options >$null 2>&1
    
    #If specific Guest Interaction Proxies were selected in the source job (Automatic selection = Disabled), copy those settings to the target job
    if (-Not $source_job_vss_options.GuestProxyAutoDetect) {
        $guestproxylist = @()
        ForEach ($guestproxy in $($source_job_guest_proxies)) {$guestproxylist += Get-VBRServer -Name $guestproxy.Name}

        if ($guestproxylist) {
            #Unsupported / unofficial "workaround" to add Guest Interaction Proxies via Powershell (see https://forums.veeam.com/powershell-f26/set-guest-interaction-proxy-server-t35234.html#p272191)
            ForEach ($gip in $guestproxylist) {[Veeam.Backup.Core.CJobProxy]::Create($target_job.Id, $gip.Id, "EGuest") >$null 2>&1}
            
            $target_job_vssoptions.GuestProxyAutoDetect = $False
            $target_job.SetVssOptions($target_job_vssoptions)  

            #Commented out since this does not appear to work ¯\_(ツ)_/¯ Resorted to using methods instead
            #Set-VBRJobVSSOptions -Job $($job.Name + $job_suffix) -Options $target_job_vssoptions >$null 2>&1
        }
        else {
            Write-Host -ForegroundColor Yellow "WARNING: Specific Guest Interaction Proxies were selected for the source job, but none of them are available at the target server. Automatic Selection will be activated."
            $target_job_vssoptions.GuestProxyAutoDetect = $True
            $target_job.SetVssOptions($target_job_vssoptions)
        }
    }

    #Enable App-Aware Processing and/or Indexing if enabled in the source job (and if specified job-level guest credentials are found at target!) (line #313)
    if ($target_job_vssoptions.AreWinCredsSet -eq $True -or $target_job_vssoptions.AreLinCredsSet -eq $True) {
        if ($source_job_vss_options.Enabled -eq $True) {Enable-VBRJobVSSIntegration -Job $target_job >$null 2>&1}
        if ($source_job_vss_options.GuestFSIndexingType -ne "None") {Enable-VBRJobGuestFSIndexing -Job $target_job >$null 2>&1}
    }

    #If specific Backup Proxies were selected in the source job (Automatic selection = Disabled), copy those settings to the target job
    if (-Not $source_job_options.JobOptions.SourceProxyAutoDetect) {
        $proxylist = @()
        ForEach ($proxy in $($source_job_source_proxies)) {$proxylist += Get-VBRViProxy -Name $proxy.Name}
        Write-Host "`nProxies selected for Target job: "
        $proxylist | ft -Property Name, Type, ChassisType -AutoSize
        if ($proxylist) {Set-VBRJobProxy -Job $target_job -Proxy $proxylist >$null 2>&1}
        else {
            Write-Host -ForegroundColor Yellow "`nWARNING: Specific VMware Proxies were selected for the source job, but none of them are available at the target server. `n Automatic Proxy Selection will be activated..."
            Set-VBRJobProxy -Job $target_job -AutoDetect >$null 2>&1
        }
    }
    
    #If encryption is used in the source job, ask user to select the encryption key to use among the ones present in the target server.
    #If no encryption key exists, prompt the user to create one.
    if ($source_job.BackupStorageOptions.StorageEncryptionEnabled -eq $True) {
        $target_encryption_keys = Get-VBREncryptionKey
        
        if ($target_encryption_keys -eq $null) {
            Write-Host "`nSource backup job has encryption enabled, but there are no encryption keys in the target backup server ($target_srv)."
            $encryption_prompt = $null
            While ("Y","N" -notcontains $encryption_prompt) {$encryption_prompt = Read-Host "Do you want to create a key now (Y)? If not (N), job will be imported with encryption disabled"}

            if ($encryption_prompt -eq "Y") {
                $password = $null
                while ($password -eq $null) {$password = Read-Host "`nEnter encryption password" -AsSecureString}
                $description = Read-Host "Enter a description (optional)"
                $encryption_key = Add-VBREncryptionKey -Password $password -Description $description
                Set-VBRJobAdvancedStorageOptions -Job $target_job -EncryptionKey $encryption_key >$null 2>&1
            }

            else {Set-VBRJobAdvancedStorageOptions -Job $target_job -EnableEncryption $false >$null 2>&1}
        }
        
        else {
            Write-Host -ForegroundColor Yellow "`nPlease select the encryption key to use (click Cancel to disable encryption for this job):"
            $encryption_key = Get-VBREncryptionKey | Out-GridView -OutputMode Single -Title "*** SELECT ENCRYPTION KEY FOR JOB: $($job.Name + $job_suffix) ***"
            if ($encryption_key -eq $null) {
                Write-Host -ForegroundColor Yellow "Encryption key selection was cancelled - Encryption will be disabled."
                Set-VBRJobAdvancedStorageOptions -Job $target_job -EnableEncryption $false >$null 2>&1
            }
            else {Set-VBRJobAdvancedStorageOptions -Job $target_job -EncryptionKey $encryption_key >$null 2>&1}
        }
    }

    Set-VBRJobScheduleOptions -Job $target_job -Options $source_job.ScheduleOptions >$null 2>&1

    #If the job has an enabled schedule at source, enable the schedule also at target
    #(this is a different operation than actually enabling/disabling the job itself)
    if ($source_job_schedule_status -eq $True) {Enable-VBRJobSchedule -Job $target_job >$null 2>&1}

    #The script sets the newly created job as disabled (just like cloned jobs), only if the job has its schedule enabled
    #This is to avoid the user having the option to enable it grayed out in the GUI (cannot enable/disable jobs from the GUI when they have a disabled schedule)
    if ($source_job_schedule_status -eq $True) {Disable-VBRJob -Job $target_job >$null 2>&1}

    #The following handles job chaining, if it is enabled in the source job
    if ($source_job.PreviousJobIdInScheduleChain -ne $null) {
        $target_job_previous_job = Get-VBRJob -Name $($source_job_previous_job_name + $job_suffix)
        if ($target_job_previous_job -eq $null) {
            Write-Host -ForegroundColor Yellow "`nWARNING! Job chaining was enabled in source job, but previous job [" $($source_job_previous_job_name + $job_suffix) "] was not found in the target server. Job schedule will be disabled.`n"
            Disable-VBRJobSchedule -Job $target_job >$null 2>&1
            #Enabling the job, since it has a disabled schedule (see 9 lines above this one for details)
            Enable-VBRJob -Job $target_job >$null 2>&1
        }
        else {
            Write-Host -ForegroundColor Yellow "`nJob chaining was enabled in source job. Scheduling imported job to be run after [" $($source_job_previous_job_name + $job_suffix) "] ...`n"
            Set-VBRJobSchedule -Job $target_job -After -AfterJob $($source_job_previous_job_name + $job_suffix) >$null 2>&1
        }
    }
    
    #Disconnect from target backup server and connect back to the source server before processing next job
    Disconnect-VBRServer

    if ($source_cred) {Connect-VBRServer -Server $source_srv -Credential $source_cred}
    else {Connect-VBRServer -Server $source_srv}

    $jobs_counter++
    
    }

Write-Host -ForegroundColor Green "`n***** EXECUTION COMPLETE *****`n"

Disconnect-VBRServer

Stop-Transcript
