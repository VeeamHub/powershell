param([string]$PlanName, [string]$PlanState)

Import-Module PSSlack
$Uri = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
$Channel = "YOURCHANNEL"

[string]$Message = "+----------------------------------------------------------------------------+"
$Message += "" | Out-String
$Message += $PlanName + ' has been changed the status to ' + $PlanState


Send-SlackMessage -Uri $Uri `
                  -Channel $Channel `
                  -Parse full `
                  -Text  $Message
