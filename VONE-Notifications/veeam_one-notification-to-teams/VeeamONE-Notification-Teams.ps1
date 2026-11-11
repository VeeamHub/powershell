param([string]$AlarmName,[string]$NodeName,[string]$Summary,[string]$Time,[string]$Status,[string]$OldStatus,[string]$ID)
<#
        .SYNOPSIS
        Veeam ONE Notification to Microsoft Teams
  
        .DESCRIPTION
        Simple Script which will send Veeam ONE Notifications to a Microsoft Teams Channel
	
        .Notes
        NAME:  VeeamONE-Notification.ps1
        LASTEDIT: 19/11/2019
        VERSION: 0.1
        KEYWORDS: Veeam, Teams
   
        .Link
        https://www.jorgedelacruz.es
    
 #>

$uri = "YOUR-MICROSOFT-TEAMS-WEBHOOK"

$body = ConvertTo-JSON @{
    text = "[$($ID)] Alarm - $($AlarmName) for $($NodeName) has been changed to $($Status) (previous state: $($OldStatus))"
}

Invoke-RestMethod -uri $uri -Method Post -body $body -ContentType 'application/json'