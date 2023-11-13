<#
    .SYNOPSIS
        Generates a timeline with the last backups and send it by email
    .SYNTAX
        .\BR-DurationReport.ps1
    .PARAMETERS
        see below
#>

#region PARAMETERS
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

function get-LastSessions {

    param($between, $and)
    
    # Sessions are subjobs. They contains informations on client backups
    # There's no command to get all Sessions. We must get them from each backup type
    $lastSessions = @()
    
    # get VM backup sessions
    $backupSessions = Get-VBRBackupSession -ea Stop | where{($_.CreationTime -ge $between -and $_.CreationTime -le $and) -or $_.IsWorking }
    foreach($session in $backupSessions) {
        $lastSessions += [PSCustomObject]@{'Name' = $session.OrigJobName
                                            'StartTime' = $session.CreationTime
                                            'EndTime'   = $session.EndTime
                                            'State'     = $session.State
                                            'Result'    = $session.Result }
    }
    
    # get agent backup sessions (a bit complicated)
    $computerBackupSessions = (Get-VBRComputerBackupJobSession -ea Stop) | where{($_.CreationTime -ge $between -and $_.CreationTime -le $and) -or $_.State -like 'Working' }
    $computerBackupJobs = Get-VBRComputerBackupJob -ea Stop

    foreach($job in $computerBackupJobs) {
        $sessions = $computerBackupSessions | where{$_.JobId -like $job.id}

        foreach($session in $sessions) {
            $lastSessions += [PSCustomObject]@{'Name' = $job.Name
                                                'StartTime' = $session.CreationTime
                                                'EndTime'   = $session.EndTime
                                                'State'     = $session.State
                                                'Result'    = $session.Result }
        }
    }

    return $lastSessions | sort StartTime, EndTime
}

#endregion

#region CODE
try {
    log -level HIGH -entry "Script started"

    Add-PSSnapin VeeamPSSnapin -ea SilentlyContinue

    # Get jobs infos
    $sessions = @(get-LastSessions -between $period_start -and $period_end)
    log -level INFO -entry "$($sessions.count) sessions found"

    # Mail shapping
    $mailTemplate = Get-Content $mail_Template_path

    # Detection of jobs table
    $tableStart = ($mailTemplate | Select-String -pattern 'id="table-details"'). LineNumber
    $tableEnd   = ($mailTemplate | Select-String -pattern "/tbody" | where{$_.LineNumber -gt $tableStart} | select -First 1).LineNumber

    # Here begin the mail construction, $mail_Body
    $mail_Body = $mailTemplate | Select -First $tableStart

    foreach($session in $sessions) {
        
        $mail_Body += "<tr>"
	    $mail_Body += "  <td class='first-row'>$($session.Name)</td>"

        # Colors are always nice
        switch($session.result) {
            'Success' { $result = 'blue';   break }
            'Warning' { $result = 'yellow'; break }
            'Failed'  { $result = 'red';    break }
            default   { $result = 'blue';   break }
        }
        
        $cursor = $period_start
        while($cursor -le $period_end) {

            if($cursor.ToString("HHmm") -in @("1800","2100","0000","0300","0600","0900")) {
	            $fatBorder = 'border-left: 2px solid #777;'
            } else {
	            $fatBorder = ''
            }

            $cursor = $cursor.AddMinutes(30)

            if($session.StartTime -lt $cursor -and ($session.EndTime.AddMinutes(30) -gt $cursor -or $session.EndTime -eq [datetime]::Parse('01/01/1900'))) {
	            $barColor = $result
            } else {
	            $barColor = 'white'
            }
            
            $mail_Body += "  <td class='bg-$barColor' style='width: 20px; $fatBorder'></td>"
        }

	    $mail_Body += "</tr>"
    }

    # finnishing mail construction with the end of template
    $mail_Body += $mailTemplate | Select -Skip ($tableEnd-1)

    # last touch
    $mail_string = $mail_Body -join "`n"
    $mail_string = $mail_string.replace('$Title', "Duration report")
    $mail_string = $mail_string.replace('$width', (($sessions | select Name).Name | sort length | select -Last 1).length*10)
    
    # email sending
    log -level INFO  -entry "Sending email"

    Send-MailMessage -From $mail_From `
                     -To $mail_To `
                     -Subject $mail_Subject `
                     -SmtpServer $mail_SmtpServer `
                     -Body $mail_string `
                     -BodyAsHtml `
                     -Encoding 'UTF8' `
                     -Attachments $veeamLogo_path `
                     -ea Stop
    
}catch{
    log -level ERROR -entry ($_ | Out-String)
}finally {
    log -level HIGH  -entry "Fin du script"
}

#endregion
