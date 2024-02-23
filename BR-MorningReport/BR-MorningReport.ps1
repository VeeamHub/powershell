<#
    .SYNOPSIS
        Generates html report on last backups jobs and send it by email
    .SYNTAX
        .
    .PARAMETERS
        (see below)
#>

#region VARIABLES
$GLOBAL:log         = "C:\...\BR-MorningReport\BR-MorningReport.$(Get-Date -Format 'yyyy-MM').log"
$mail_Template_path = "C:\...\BR-MorningReport\mail template.html"
$veeamLogo_path     = "C:\...\BR-MorningReport\veeam-logo.png"
$LastPeriodInHours  = 15

$mail_From       = "$($env:COMPUTERNAME)@company.com"
$mail_To         = @('me@company.com','team@company.com')
$mail_Subject    = 'Backup Report' 
$mail_SmtpServer = 'smtp.company.com' 

#endregion

#region FONCTIONS

function log {

    param(
        [Parameter(Mandatory)]
        [ValidateSet('INFO','HIGH','WARNING','ERROR')]
        [string]$level, 
        [Parameter(Mandatory)]
        [string]$entry
    )

    switch($level) {
        "INFO"    { $color = "White"  }
        "HIGH"    { $color = "Cyan"   }
        "WARNING" { $color = "Yellow" }
        "ERROR"   { $color = "Red   " }
        default   { $color = "White"  }
    }

    "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') - [$level] $entry" | Out-File $GLOBAL:log -Append

    Write-Host "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') - " -NoNewline
    Write-Host "[$level] $entry" -ForegroundColor $color
}

function get-lastbackupjobs {

    param([int]$lastHours)

    # Sessions are subjobs. They contains informations on client backups
    # There's no command to get all jobs. We must get jobs from each type
    $sessions = @()

    # get sessions from VM jobs
    $backupsJobs_VM = Get-VBRBackupSession -ea Stop | where{$_.EndTime -ge (get-date).AddHours(-$lastHours) -or $_.State -like 'Working'}
    $sessions += $backupsJobs_VM | foreach{ $_.GetTaskSessions() }
    
    # get session from agent jobs
    $backupsJobs_Agent = Get-VBRComputerBackupJobSession  -ea Stop
    $backupsJobs_Agent = $backupsJobs_Agent | where{$_.EndTime -ge (get-date).AddHours(-$lastHours) -or $_.State -like 'Working'}
    $sessions += $backupsJobs_Agent | Get-VBRTaskSession | where{$_.Name -notlike "*-CL*"}
    
    # get session from tape jobs
    $backupJobs_Tape = Get-VBRTapeJob | %{Get-VBRSession -Job $_} | where{$_.EndTime -ge (get-date).AddHours(-$lastHours) -or $_.State -like 'Working'}
    $sessions += $backupJobs_Tape | Get-VBRTaskSession
    
    # Array returned at the end. The type specified permit modifications
    [System.Collections.ArrayList]$lastBackupJobs = @()

    foreach($session in $sessions) {
        
        # duration shapping
        if($session.Progress.Duration -eq $null) {
            $duration = '-'
        } elseif($session.Progress.Duration -lt (New-TimeSpan -hours 1)) {
            $duration = "$([math]::Ceiling($session.Progress.Duration.TotalMinutes))mn"
        } elseif($session.Progress.Duration -lt (New-TimeSpan -Days 2)) {
            $duration = "$([math]::Round($session.Progress.Duration.TotalHours,0))h"
        } else {
            $duration = "$([math]::Round($session.Progress.Duration.TotalDays,0)) days"
        }
            
        # endtime shapping
        if($session.Progress.StopTimeLocal -eq [datetime]::Parse('01/01/1900')){
            $endTime = ''
        }else{
            $endTime = $session.Progress.StopTimeLocal.ToString('dd/MM/yyyy HH\hmm')
        }

        # Progress shapping
        if($session.Status.ToString() -like "InProgress") {
            $progress = [math]::Floor($session.Progress.ProcessedUsedSize * 100 / $session.Progress.TotalUsedSize)
        }else{
            $progress = 100
        }

        # Error info
        $commentLengthLimit=80
        switch($session.Status.ToString()) {
            'Warning' {
                        if($session.Info.Reason.length -gt $commentLengthLimit){
                            $Info = $session.Info.Reason.substring(0, $commentLengthLimit)+'...'
                        }else{
                            $Info = $session.Info.Reason
                        }
                        break
                      }
            'Failed'  {
                        $records = $session.JobSess.Logger.GetLog().updatedrecords 
                        $errorRecords = $records | where{$_.status -ne "ESucceeded" -and $_.status -ne "ENone" -and $_.title -notlike "Job finished *"}
                        $Info = $errorRecords | select -f 1 | %{if($_.Title.length -gt $commentLengthLimit){$_.Title.substring(0, $commentLengthLimit)+'...'}else{$_.Title} }
                        break
                      }
            default   { $Info = ""; break }
        }

        $lastBackupJobs += [PSCustomObject]@{'BackupJob' = $session.JobName
                                             'Server'    = $session.Name.split(' ')[0]
                                             'StartTime' = $session.Progress.StartTimeLocal.ToString('dd/MM/yyyy HH\hmm')
                                             'EndTime'   = $endTime
                                             'Duration'  = $duration
                                             'Status'    = $session.Status.ToString()
                                             'Progress'  = $progress
                                             'Info'      = $Info
                                             'Encrypted' = $session.JobSess.IsEncryptionEnabled}
    }

    # If a session gone fail then retry and succeed, those lines remove the failed sessions to keep only the succeed one
    $doublons = $lastBackupJobs | Group-Object -Property Server,BackupJob | where{$_.Group.Count -gt 1 -and $_.group.status -contains "Success"}
    foreach($doublon in $doublons) {
        $doublon.Group | where{$_.status -notlike "Success"} | foreach{$lastBackupJobs.Remove($_)}
    }

    # Those lines remove the multiple retries in failure to keep the last one
    # Comment them if you want to show all tries sessions
    $doublons = $lastBackupJobs | Group-Object -Property Server,BackupJob | where{$_.Group.Count -gt 1 -and $_.group.status -contains "Failed"}
    foreach($doublon in $doublons) {
        $doublon.Group| sort StartTime | select -SkipLast 1 | foreach{$lastBackupJobs.Remove($_)}
    }

    return $lastBackupJobs | sort BackupJob,Server,StartTime
}

#endregion

#region CODE
try {
    log -level HIGH -entry "Script started"

    Add-PSSnapin VeeamPSSnapin -ea SilentlyContinue

    # Get jobs infos
    $jobinfos = @(get-lastbackupjobs -lastHours $LastPeriodInHours)
    log -level INFO -entry "$($jobinfos.count) jobs detected in the last $LastPeriodInHours hours"
    log -level INFO -entry "$(@($jobinfos | where{$_.status -like 'Success'}).count) success"
    log -level INFO -entry "$(@($jobinfos | where{$_.status -like 'Failed'}).count) failed"

    # Mail shapping
    $mailTemplate = Get-Content $mail_Template_path -ea Stop

    # Detection of details table
    $tableDetailsStart = ($mailTemplate | Select-String -pattern 'id="table-details"').LineNumber
    $tableDetailsEnd   = ($mailTemplate | Select-String -pattern "/tbody" | where{$_.LineNumber -gt $tableDetailsStart} | select -First 1).LineNumber

    # Here begin the mail construction, $mail_Body
    $mail_Body = $mailTemplate | Select -First $tableDetailsStart

    # Adding jobs infos ordered by status
    $statusOrder = @('Failed','Warning','InProgress','Pending','Success')
    foreach($jobinfo in $jobinfos | sort {$statusOrder.IndexOf($_.Status)},BackupJob,Server,StartTime) {

        $mail_Body += "<tr>"
        if($jobinfo.Encrypted){
            $mail_Body += "  <td class='crypted'>$($jobinfo.BackupJob)</td>"
        }else{
	        $mail_Body += "  <td>$($jobinfo.BackupJob)</td>"
        }
	    $mail_Body += "  <th class='text-left'>$($jobinfo.Server)</th>"
	    $mail_Body += "  <td class='text-center'>$($jobinfo.StartTime)</td>"
	    $mail_Body += "  <td class='text-center'>$($jobinfo.EndTime)</td>"
	    $mail_Body += "  <td class='text-center'>$($jobinfo.Duration)</td>"
        if($jobinfo.Status -like "InProgress") {
	        $mail_Body += "  <td class='status-$($jobinfo.Status)'>$($jobinfo.progress)%</td>"
        }else{
            $mail_Body += "  <td class='status-$($jobinfo.Status)'>$($jobinfo.Status)</td>"
        }
        $mail_Body += "  <td class='text-left'>$($jobinfo.Info)</td>"
	    $mail_Body += "</tr>"
    }
    
    # finnishing mail construction with the end of template
    $mail_Body += $mailTemplate | Select -Skip ($tableDetailsEnd-1)

    # adding stripes
    $lignes = $mail_Body | Select-String -pattern "<tr>"
    for([int]$i=0;$i -lt $lignes.count;$i++) {
        if($i % 2 -eq 1) {
            $mail_Body[$lignes[$i].LineNumber-1] = "<tr class='stripped'>"
        }
    }

    # Resume table
    $mail_string = $mail_Body -join "`n"
    $mail_string = $mail_string.replace('$Title', "Backup report on $(get-date -Format 'dd/MM/yyyy')")
    $mail_string = $mail_string.replace('$LastPeriodInHours', $LastPeriodInHours.ToString())
    $mail_string = $mail_string.replace('$TotalFailedJobs',   @($jobinfos | where{$_.status -like 'Failed' }).count)
    $mail_string = $mail_string.replace('$TotalWarningJobs',  @($jobinfos | where{$_.status -like 'Warning'}).count)
    $mail_string = $mail_string.replace('$TotalProgressJobs', @($jobinfos | where{$_.status -like 'InProgress'}).count)
    $mail_string = $mail_string.replace('$TotalPendingJobs',  @($jobinfos | where{$_.status -like 'Pending'}).count)
    $mail_string = $mail_string.replace('$TotalSuccessJobs',  @($jobinfos | where{$_.status -like 'Success'}).count)
    
    $EncryptedBackupJobs = @($jobinfos | where{$_.Encrypted}).count
    if($EncryptedBackupJobs -eq 0) {
        $mail_string = $mail_string.replace('$TotalEncryptedBackupJobs', $EncryptedBackupJobs)
    }else{
        $mail_string = $mail_string.replace('$TotalEncryptedBackupJobs', "<span class='status-Failed'>$EncryptedBackupJobs</span>")
    }

    # email sending
    log -level INFO  -entry "Sending email"

    Send-MailMessage -From $mail_From `
                     -To $mail_To `
                     -Subject $mail_Subject `
                     -SmtpServer $mail_SmtpServer `
                     -Body $mail_string `
                     -BodyAsHtml `
                     -Attachments $veeamLogo_path `
                     -Encoding 'UTF8' `
                     -ea Stop

}catch{
    log -level ERROR -entry ($_ | Out-String)
}finally {
    log -level HIGH  -entry "end of script"
}

#endregion
