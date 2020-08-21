<#
.Synopsis
  Generates report of all repositories known to a given Veeam Service Provider Console Server. Uses the new v3 API so your milage may vary.
.Notes
   Version: 1.0
   Author: Jim Jones
   Modified Date: 8/21/2020

   If running for the first time a new computer You will need to run to store the credentials
    $credpath='c:\creds\myadmincred.xml'
    GET-CREDENTIAL –Credential (Get-Credential) | EXPORT-CLIXML $credpath
.EXAMPLE
  .\VACStorageReport.ps1 -vacServer 'vac.mydomain.com' -authPath 'c:\creds\myadmincred.xml'
#>

[CmdletBinding()]
Param (
    [string]$vacserver = "vac.mydomain.com",
    [string]$authpath = "c:\creds\myadmincred.xml"
)

#Email Variables
$date = Get-Date
$sgToken        = "SendGridToken"
$fromAddress    = "myvac@mydomain.com"
$fromName       = "US VAC"
$toName         = "NetOps"
$toAddress      = "me@me.com"
$emailBody      = "See attached VSPC Repository Usage Report for $date"
$emailSubject   = "VSPC Repository Usage Report for $date"

$Credentials = IMPORT-CLIXML -path $authpath
$RESTAPIUser = $Credentials.UserName
$RESTAPIPassword = $Credentials.GetNetworkCredential().Password

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/x-www-form-urlencoded")

$body = "grant_type=password&username=$RestAPIUser&password=$RestAPIPassword"

$response = Invoke-RestMethod "https://$vacserver/api/v3/token" -Method 'POST' -Headers $headers -Body $body
$token = $response.access_token

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer $token")


#Let's grab some repos
$repos = Invoke-RestMethod "https://$vacserver/api/v3/infrastructure/backupServers/repositories?limit=500" -Method 'GET' -Headers $headers -Body $body

$repos.data | select-object name,hostname, path, `
    @{Name="CapacityGB";Expression={[math]::round($_.capacity / 1Gb, 2)}}, `
    @{Name="FreeSpaceGB";Expression={[math]::round($_.freeSpace / 1Gb, 2)}}, `
    @{Name="UsedSpaceGB";Expression={[math]::round($_.usedSpace / 1Gb, 2)}}, `
    @{Name="PercentUsed";Expression={($_.usedSpace/$_.capacity).toString("P")}} `
    | Sort-Object -Property PercentUsed -Descending `
    | Export-CSV -Path ".\VACRepositoryInfo.CSV" -NoTypeInformation

#Send Mail
Import-Module PSSendGrid

$Parameters = @{
    FromAddress = $FromAddress
    ToAddress   = $ToAddress 
    Subject     = $emailSubject
    Body        = $emailBody
    Token       = $sgToken
    FromName    = $fromName
    ToName      = $toName 
    AttachmentPath        = ".\VACRepositoryInfo.CSV"
}
Send-PSSendGridMail @Parameters
