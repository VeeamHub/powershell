param([string]$PlanSummary)

Import-Module PSSlack
$Uri = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
$Channel = "CHANNELNAME"

[string]$Message = $PlanSummary
$Message += "+----------------------------------------------------------------------------+"

Send-SlackMessage -Uri $Uri `
                  -Channel $Channel `
                  -Parse full `
                  -Text $Message
