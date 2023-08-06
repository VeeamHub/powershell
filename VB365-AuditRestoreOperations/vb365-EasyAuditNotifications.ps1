<#
.SYNOPSIS
	Makes your life a bit easier, helping you visually on adding Users to the Audit in Microsoft 365

.DESCRIPTION
    This script will help you adding Users from different Organizations to the 
    Audit Notifications per that Organization.
    At the moment doesn't control maximum number of users.
    
    A lot more to do to handle this right, but hopefully it can help you.

.OUTPUTS
	vb365-EasyAuditNotifications.ps1 returns the configuration once finished

.EXAMPLE
	vb365-EasyAuditNotifications.ps1


.NOTES
	NAME:  vb365-EasyAuditNotifications.ps1
	VERSION: 1.0
	AUTHOR: Jorge de la Cruz
	TWITTER: @jorgedlcruz
	GITHUB: https://github.com/jorgedlcruz

.LINK
	https://jorgedelacruz.uk/

#>

# Variables to login on Veeam Backup for Microsoft 365
$veeamUsername = "YOURVB365USERNAME"
$veeamPassword = "YOURVB365PASSWORD"
$veeamRestServer = "https://YOURVB365IPORHOSTNAME"
$veeamAPIversion = "v7"
$veeamRestPort = "4443" #Default Port

# Ignore SSL errors
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# Define the headers and body for your request
$headers = @{
    "Content-Type" = "application/x-www-form-urlencoded"
    "Accept" = "application/json"

}
$body = @{
    "grant_type" = "password"
    "username" = $veeamUsername
    "password" = $veeamPassword
    "refresh_token" = "''"
} 
# Send the POST request and store the response
$response = Invoke-RestMethod -Method Post -Uri "$veeamRestServer`:$veeamRestPort/$veeamAPIversion/token" -Body $body -Headers $headers 

# Get the access_token from the response
$veeamBearer = $response.access_token

# Initial greeting
Write-Host "`nHello, welcome to the VB365 Easy Audit Notifications script!" -ForegroundColor Green
Write-Host "==========================================================="

# Define base URL and header with the bearer token
$baseUrl = "$veeamRestServer`:$veeamRestPort/$veeamAPIversion"
$headers = @{
    "Accept" = "application/json"
    "Authorization" = "Bearer $veeamBearer"
}

# Fetch organizations
$organizations = Invoke-RestMethod -Method Get -Uri "$baseUrl/Organizations?extendedView=false" -Headers $headers

# Display organizations for selection
Write-Host "`nPlease select the Organization you want to enable Audit:"
for ($i=0; $i -lt $organizations.Count; $i++) {
    Write-Host ("{0}.- {1}" -f ($i + 1), $organizations[$i].officeName)
}
Write-Host "-----------------------------------------------------------"

# Get organization choice from the user
$orgChoice = Read-Host "Enter your choice"
$selectedOrg = $organizations[$orgChoice - 1]
$selectedOrgId = $selectedOrg.id

# Ask the user for the next choice - Users or Groups
Write-Host "`nGreat choice! You have selected $($selectedOrg.officeName)."
Write-Host "-----------------------------------------------------------"
Write-Host "`nDo you want to enable notification on Users (Exchange Mailboxes), or Groups (SharePoint Sites, Teams)?"
Write-Host "1.- Users" -ForegroundColor Yellow
Write-Host "2.- Groups" -ForegroundColor Yellow
Write-Host "-----------------------------------------------------------"

# Get type choice from user
$typeChoice = Read-Host "Enter your choice"

# Depending on the choice, fetch Users or Groups
if ($typeChoice -eq 1) {
    $entities = Invoke-RestMethod -Method Get -Uri "$baseUrl/Organizations/$($selectedOrgId)/Users" -Headers $headers
} else {
    Write-Host "`nGroups support is not yet implemented." -ForegroundColor Red
    exit
}

# Display entities for selection
Write-Host "`nPlease select one or more users, separated with comma:"
for ($i=0; $i -lt $entities.results.Count; $i++) {
    Write-Host ("{0}.- {1}" -f ($i + 1), $entities.results[$i].displayName) -ForegroundColor Cyan
}
Write-Host "-----------------------------------------------------------"

# Get user choices
$userChoices = Read-Host "Enter your choices (e.g. 1,2,3)"
$selectedEntities = $userChoices -split ',' | ForEach-Object { $entities.results[$_ - 1] }

# Process the selected entities
$processedEntities = $selectedEntities | ForEach-Object {
    @{
        id          = $_.id
        displayName = $_.displayName
        name        = $_.name
    }
}

$headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
    "Authorization" = "Bearer $veeamBearer"
}

$processedEntities | ForEach-Object {
    $bodyData = @{
        type = "user"
        user = @{
            id          = $_.id
            displayName = $_.displayName
            name        = $_.name
        }
    }

    $bodyJson = ConvertTo-Json @($bodyData)

    try {
        $response = Invoke-RestMethod -Method Post -Uri "$baseUrl/Organizations/$($selectedOrgId)/AuditItems" -Headers $headers -Body $bodyJson
        Write-Host "Successfully added user $($_.name) to the Audit." -ForegroundColor Green
    } catch {
        Write-Host "Failed to add user $($_.name). Details: $($_.Exception.Message)" -ForegroundColor Red
    }
}
