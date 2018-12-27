param([string]$VMName, [string]$VMIP, [string]$VMIPReplica)

Import-Module PSSlack
$Uri = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
$Channel = "CHANNELNAME"

$Message = '' + $VMName + ' with IP ' + $VMIP + ' and Replica IP ' + $VMIPReplica + ' has started a DR'

Send-SlackMessage -Uri $Uri `
                  -Channel $Channel `
                  -Parse full `
                  -Text $Message
