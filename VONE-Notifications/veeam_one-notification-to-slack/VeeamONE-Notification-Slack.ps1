param([string]$AlarmName,[string]$NodeName,[string]$Summary,[string]$Time,[string]$Status,[string]$OldStatus,[string]$ID)

Import-Module PSSlack
$Uri = "YOUR-SLACK-WEB-HOOK-URL"
$Channel = "vone-alerts"

$Message = "[$($ID)] Alarm - $($AlarmName) for $($NodeName) has been changed to $($Status) (previous state: $($OldStatus))"

Send-SlackMessage -Uri $Uri `
                  -Channel $Channel `
                  -IconUrl "https://www.jorgedelacruz.es/wp-content/uploads/2019/12/veeamone-slack-004.png" `
                  -Parse full `
                  -Text $Message