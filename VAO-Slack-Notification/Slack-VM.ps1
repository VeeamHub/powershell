param([string]$VMName, [string]$VMIP, [string]$VMIPReplica)

Import-Module PSSlack
$Uri = "https://hooks.slack.com/services/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"
$Channel = "vao-test"

$Message = '' + $VMName + ' with IP ' + $VMIP + ' and Replica IP ' + $VMIPReplica + ' has started a DR'

Send-SlackMessage -Uri $Uri `
                  -Channel $Channel `
                  -Parse full `
                  -Text $Message