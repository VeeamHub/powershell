param([string]$PlanName, [string]$PlanState)

Import-Module PSSlack
$Uri = "https://hooks.slack.com/services/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"
$Channel = "vao-test"

[string]$Message = "+----------------------------------------------------------------------------+"
$Message += "" | Out-String
$Message += $PlanName + ' has been changed the status to ' + $PlanState


Send-SlackMessage -Uri $Uri `
                  -Channel $Channel `
                  -Parse full `
                  -Text  $Message