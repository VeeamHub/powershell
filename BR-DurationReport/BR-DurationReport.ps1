<#
    .SYNOPSIS
        Generates a timeline with the last backups and send it by email
    .SYNTAX
        .
    .PARAMETERS
        (see below)
#>

#region VARIABLES
$GLOBAL:log           = "C:\...\BR-DurationReport\BR-DurationReport.$(Get-Date -Format 'yyyy-MM').log"
$mail_Template_path   = "C:\...\BR-DurationReport\mail template.html"
$veeamLogo_path       = "C:\...\BR-DurationReport\veeam-logo.png"
$period_start = [System.DateTime]::Parse("18:00").AddDays(-1) # yesterday, 6pm
$period_end   = [System.DateTime]::Parse("9:00") # today, 9am

$mail_From       = "$($env:COMPUTERNAME)@company.com"
$mail_To         = @('me@company.com','team@company.com')
$mail_Subject    = 'Duration Report' 
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

    param($between, $and)
    
    # Sessions are subjobs. They contains informations on client backups
    # There's no command to get all jobs. We must get jobs from each type
    $sessions = @()

    # get sessions from VM jobs
    $backupsJobs_VM = Get-VBRBackupSession -ea Stop | where{$_.CreationTime -ge $between -and $_.CreationTime -le $and }
    $sessions += $backupsJobs_VM | foreach{ $_.GetTaskSessions() }
    
    # get session from agent jobs
    $backupsJobs_Agent = Get-VBRComputerBackupJobSession  -ea Stop
    $backupsJobs_Agent = $backupsJobs_Agent | where{$_.CreationTime -ge $between -and $_.CreationTime -le $and }
    $sessions += $backupsJobs_Agent | Get-VBRTaskSession | where{$_.Name -notlike "*-CL*"}
    
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
            $duration = "$([math]::Round($session.Progress.Duration.TotalDays,0)) jours"
        }
           
        # endtime shapping
        if($session.Progress.StopTimeLocal -eq [datetime]::Parse('01/01/1900')){
            $endTime = (Get-Date).AddDays(1)
        }else{
            $endTime = $session.Progress.StopTimeLocal
        }

        # Progress shapping
        if($session.Status.ToString() -like "InProgress") {
            $progress = [math]::Floor($session.Progress.ProcessedUsedSize * 100 / $session.Progress.TotalUsedSize)
        }else{
            $progress = 100
        }

        $lastBackupJobs += [PSCustomObject]@{'BackupJob' = $session.JobName.split(' ')[0]
                                             'Server'    = $session.Name.split(' ')[0].split('.')[0]                                             'StartTime' = $session.Progress.StartTimeLocal                                             'EndTime'   = $endTime
                                             'Duration'  = $duration
                                             'Status'    = $session.Status.ToString()
                                             'Progress'  = $progress }
    }
    
    # If a session gone fail then retry and succeed, those lines remove the failed sessions to keep only the succeed one
    $doublons = $lastBackupJobs | Group-Object -Property Server,BackupJob | where{$_.Group.Count -gt 1 -and $_.group.status -contains "Success"}
    foreach($doublon in $doublons) {
        $doublon.Group | where{$_.status -notlike "Success"} | foreach{$lastBackupJobs.Remove($_)}
    }

    return $lastBackupJobs | sort StartTime,BackupJob,Server
}

#endregion

#region CODE
try {
    log -level HIGH -entry "Script started"

    Add-PSSnapin VeeamPSSnapin -ea SilentlyContinue

    # Get jobs infos
    $jobinfos      = @(get-lastbackupjobs -between $period_start -and $period_end )
    log -level INFO -entry "$($jobinfos.count) jobs detected"

    # Mail shapping
    $mailTemplate = Get-Content $mail_Template_path

    # Detection of jobs table
    $tableStart = ($mailTemplate | Select-String -pattern 'id="table-details"'). LineNumber
    $tableEnd   = ($mailTemplate | Select-String -pattern "/tbody" | where{$_.LineNumber -gt $tableStart} | select -First 1).LineNumber

    # Here begin the mail construction, $mail_Body
    $mail_Body = $mailTemplate | Select -First $tableStart

    foreach($backupjob in $jobinfos | Group-Object backupjob) {
        
        $mail_Body += "<tr>"
	    $mail_Body += "  <td class='first-row'>$($backupjob.Name)</td>"

        $time = $period_start
        while($time -le $period_end) {

            if($time.ToString("HHmm") -in @("0000","0300","0600","0900","1200","1500","1800","2100")) {
	            $style = 'style="width: 20px; border-left: 2px solid #777;"'
            } else {
	            $style = 'style="width: 20px;"'
            }

            $time = $time.AddMinutes(30)

            if(($backupjob.Group.StartTime | sort | select -f 1) -lt $time -and ($backupjob.Group.EndTime.AddMinutes(30) | sort -Descending | select -f 1) -gt $time) {
	            $mail_Body += "  <td class='bg-blue'  $style></td>"
            } else {
	            $mail_Body += "  <td class='bg-white' $style></td>"
            }
        }

	    $mail_Body += "</tr>"
    }

    # finnishing mail construction with the end of template
    $mail_Body += $mailTemplate | Select -Skip ($tableEnd-1)

    # Resume table
    $mail_string = $mail_Body -join "`n"
    $mail_string = $mail_string.replace('$Title', "Duration report")
    
    # email sending
    log -level INFO  -entry "Sending email"

    Send-MailMessage -From $mail_From `                     -To $mail_To `                     -Subject $mail_Subject `                     -SmtpServer $mail_SmtpServer `                     -Body $mail_string `                     -BodyAsHtml `                     -Encoding 'UTF8' `                     -Attachments $veeamLogo_path `                     -ea Stop
    
}catch{
    log -level ERROR -entry ($_ | Out-String)
}finally {
    log -level HIGH  -entry "Fin du script"
}

#endregion
