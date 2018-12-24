param([string]$PlanSummary)

Import-Module PSSlack
$Uri = "https://hooks.slack.com/services/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"
$Channel = "vao-test"

[string]$Message = $PlanSummary
$Message += "+----------------------------------------------------------------------------+"

Send-SlackMessage -Uri $Uri `
                  -Channel $Channel `
                  -Parse full `
                  -Text $Message