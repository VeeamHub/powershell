<#
.SYNOPSIS
	Prepares, completes, and configures the AuditEmailSettings funcionality of Veeam Backup for Microsoft 365

.DESCRIPTION
    This script will help you to prepare the OAuth parameters to configure the
    Veeam Backup for Microsoft 365 Audit Email Settings.
    The process to do manually it is very painful, and takes a lot of time, more
    than 10/15 minutes as involves copying/pasting values, tokens, etc.
    This script have been designed to keep the security, as it asks you for 
    proper auth, MFA, etc. But simplifies all the copy pasting, ready in seconds.

.OUTPUTS
	vb365-AuditEmailSettings-OAuth.ps1 returns the configuration once finished

.EXAMPLE
	vb365-AuditEmailSettings-OAuth.ps1


.NOTES
	NAME:  vb365-AuditEmailSettings-OAuth.ps1
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

# Variables to login and Auth in GoogleMail, or Microsoft 365
$ServerType = "Microsoft365"
$redirectUrl = "http://localhost"

# Not needed if you want to use the Official Veeam App to send emails (recommended)
#$clientId = "YOURCLIENTID" 
#$clientSecret = "YOURSECRET"
#$tenantId = "YOURTENANTID"


# Variables to login and Auth in GoogleMail, or Microsoft 365
$mailFrom = "YOURMAILFROM"
$mailTo = "YOURMAILTOBETTERTOBEADL"
$subject = "VBO Audit - %StartTime% — %OrganizationName% - %DisplayName% - %Action% - %InitiatedByUserName%"


# Ignore SSL errors
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
# Define the total number of steps
$totalSteps = 6

# 1.- Get Auth Token on Veeam Backup for Microsoft 365 Server
Write-Progress -Activity "Processing Items" -Status "Step 1 of $totalSteps : Getting Auth Token" -PercentComplete (1/$totalSteps*100)
Write-Host "Step 1 of $totalSteps : Getting Auth Token" -PercentComplete (1/$totalSteps*100)
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

# 2.- Prepare OAuthSignIn which involves querying our AzureAD
Write-Progress -Activity "Processing Items" -Status "Step 2 of $totalSteps : Preparing OAuthSignIn" -PercentComplete (2/$totalSteps*100)
Write-Host "Step 2 of $totalSteps : Preparing OAuthSignIn" -PercentComplete (2/$totalSteps*100)
# Prepare OAuthSignIn
$veeamRestEndPoint = "$veeamRestServer`:$veeamRestPort/$veeamAPIversion/AuditEmailSettings/PrepareOAuthSignIn"
$headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
    "Authorization" = "Bearer $veeamBearer"
}
$body = @{
    "authenticationServiceKind" = $ServerType
    "redirectUrl" = $redirectUrl
    
    # Not needed if you want to use the Official Veeam App to send emails (recommended)
    # "clientId" = $clientId
    #"clientSecret" = $clientSecret
    #"tenantId" = $tenantId
    
}
$response = Invoke-RestMethod -Method Post -Uri $veeamRestEndPoint -Body ($body | ConvertTo-Json) -Headers $headers 
$signInUrl = $response.signInUrl

# 3.- Spin up a localhost server to get the redirect parameters
Write-Progress -Activity "Processing Items" -Status "Step 3 of $totalSteps : Starting localhost server for redirect" -PercentComplete (3/$totalSteps*100)
Write-Host "Step 3 of $totalSteps : Starting localhost server for redirect" -PercentComplete (3/$totalSteps*100)
$prefix = 'http://localhost/'
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Start-Process $signInUrl
Start-Sleep -Seconds 30
$context = $listener.GetContext()
$requestUrl = $context.Request.Url
$listener.Stop()
$params = [System.Web.HttpUtility]::ParseQueryString($requestUrl.Query)
$code = $null
$state = $null
$params.AllKeys | ForEach-Object { 
    if($_ -eq 'code') {
        $code = $params[$_]
    }
    if($_ -eq 'state') {
        $state = $params[$_]
    }
}

# 4.- Let's complete the OAuthSignIn now
Write-Progress -Activity "Processing Items" -Status "Step 4 of $totalSteps : Completing OAuthSignIn" -PercentComplete (4/$totalSteps*100)
Write-Host "Step 4 of $totalSteps : Completing OAuthSignIn" -PercentComplete (4/$totalSteps*100)
$veeamRestEndPoint = "$veeamRestServer`:$veeamRestPort/$veeamAPIversion/AuditEmailSettings/CompleteOAuthSignIn"
$headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
    "Authorization" = "Bearer $veeamBearer"
}
$body = @{
    "code" = $code
    "state" = $state
}
$response = Invoke-RestMethod -Method Post -Uri $veeamRestEndPoint -Body ($body | ConvertTo-Json) -Headers $headers 
$requestId = $response.requestId
$userId = $response.userId

# 5.- Let's now put the email settings with the OAuth values
Write-Progress -Activity "Processing Items" -Status "Step 5 of $totalSteps : Setting Email settings" -PercentComplete (5/$totalSteps*100)
Write-Host "Step 5 of $totalSteps : Setting Email settings" -PercentComplete (5/$totalSteps*100)
$veeamRestEndPoint = "$veeamRestServer`:$veeamRestPort/$veeamAPIversion/AuditEmailSettings"
$headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
    "Authorization" = "Bearer $veeamBearer"
}
$body = @{
    "enableNotification" = $true
    "from" = $mailFrom
    "to" = $mailTo
    "subject" = $subject
    "authenticationType" = $ServerType
    "userId" = $userId
    "requestId" = $requestId
}
$response = Invoke-RestMethod -Method Put -Uri $veeamRestEndPoint -Body ($body | ConvertTo-Json) -Headers $headers 

# 6.- Final step, let's check if all is good
Write-Progress -Activity "Processing Items" -Status "Step 6 of $totalSteps : Checking Email settings" -PercentComplete (6/$totalSteps*100)
Write-Host "Step 6 of $totalSteps : Checking Email settings" -PercentComplete (6/$totalSteps*100)

$veeamRestEndPoint = "$veeamRestServer`:$veeamRestPort/$veeamAPIversion/AuditEmailSettings"
$headers = @{
    "Accept" = "application/json"
    "Authorization" = "Bearer $veeamBearer"
}
$response = Invoke-RestMethod -Method Get -Uri $veeamRestEndPoint -Headers $headers

Write-Host "This is the configuration that we have pushed to VB365"
$response

Write-Host "Sending test email..."

$veeamRestEndPoint = "$veeamRestServer`:$veeamRestPort/$veeamAPIversion/AuditEmailSettings/SendTest"
$headers = @{
    "Accept" = "application/json"
    "Authorization" = "Bearer $veeamBearer"
}
$response = Invoke-RestMethod -Method Post -Uri $veeamRestEndPoint -Headers $headers

Write-Host "Test email has been sent!"

