############################################################################################
# Start of the script - Description, Requirements & Legal Disclaimer
############################################################################################
# originally written by: Joshua Stenhouse joshuastenhouse@gmail.com
##################################
# Adapted by Carlos Talbot to work with Veeam One carlos.talbot@veeam.com
# Description:
# This script shows you how to authenticate with Service Now using your username and password on each API call.
################################## 
# Requirements:
# - A URL specified on $SNOWURL with your Service Now URL
# - A valid username and password which can login to SNOW
# IMPORTANT:
# The sript needs to be run for the first time interactively from a PowerShell command line. The script will prompt
# you for the username and password of your SNOW instnace which is then stored in an encrypted file in the
# same directory as the script. You need to run this as the same account as the VeeamOne service is
# running as (e.g. LOCAL Administrator). Below is an example you can use to run the script:
# c:\scripts\createticket.ps1 "VM power status" "EXCH2K16" "virtual machine is not Running" "1/29/2020 9:56:38 PM" "Error" "Reset/Resolved" "21117"
#
##################################
# Legal Disclaimer:
# This script is written by Joshua Stenhouse is not supported under any support program or service. 
# All scripts are provided AS IS without warranty of any kind. 
# The author further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. 
# The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. 
# In no event shall its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever 
# (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation, 
# even if the author has been advised of the possibility of such damages.

###############################################
#The paramaters passed to the script by Veeam One are comprised of the values below. Note: when refering to command line parameters from a PowerShell
#script, the first parameter is referenced as $Args[0]
# %1 - Alarm 
# %2 - Fired node name
# %3 - triggering summary
# %4 - Time
# %5 - status
# %6 - old status
# %7 - Incident ID
# Here's an example running the script from a PowerShell command prompt:
# c:\scripts\createticket.ps1 "VM power status" "EXCH2K16" "state of virtual machine is not equal to Running" "1/29/2020 9:56:38 PM" "Error" "Reset/Resolved" "21117"

###############################################
# Configure the variables below, you will be prompted for SNOW login during the first run which is then saved securely
$SNOWURL = "https://dev50610.service-now.com/"
$ScriptDir = "c:\scripts\"
$Debug = $true     #enables writing to SNOWDebug.log file
########################################################################################################################
# Nothing to configure below this line - Starting the main function of the script
########################################################################################################################
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

Function WriteIT ($P1)
{
    Write-Output $p1
    if ($DEBUG) {
        $b = Get-Date
        Write-Output $b" CREATE "$p1 | Out-File -FilePath $ScriptDir"SNOWdebug.log" -Append
    }
}

If ($args.Count -lt 7) {
    WriteIT "Not enought paramaters"
    WriteIT "Syntax:"
    WriteIT "createtick.ps1 'alarm' 'node name' 'summary' 'time' 'status' 'old status' 'incident ID'"
    exit 1
}
WriteIT "Arugments passed: $args "

###############################################
# Prompting & saving SNOW credentials, delete the XML file created to reset your password
###############################################
# Setting credential file
$SNOWCredentialsFile = $ScriptDir+"SNOWCredentials.xml"
# Testing if file exists
$SNOWCredentialsFileTest =  Test-Path $SNOWCredentialsFile
# IF doesn't exist, prompting and saving credentials
IF ($SNOWCredentialsFileTest -eq $False)
{
    $SNOWCredentials = Get-Credential -Message "Enter SNOW login credentials"
    $SNOWCredentials | EXPORT-CLIXML $SNOWCredentialsFile -Force
}
# Importing credentials
#$SNOWCredentials = IMPORT-CLIXML $SNOWCredentialsFile

try{            
    $SNOWCredentials = Import-Clixml $SNOWCredentialsFile
#    WriteIT "SnowCred is $SNOWCredentials"       
}            
catch{            
    $e = $_            
}            
If($e -ne $null) { WriteIT $e.FullyQualifiedErrorId }

# Setting the username and password from the credential file (run at the start of each script)
$SNOWUsername = $SNOWCredentials.UserName
$SNOWPassword = $SNOWCredentials.GetNetworkCredential().Password
#WriteIT "Username is $SNOWUSERNAME"
#WriteIT "Password is $SNOWPassword"

##################################
# Building Authentication Header & setting content type
##################################
$HeaderAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $SNOWUsername, $SNOWPassword)))
$SNOWSessionHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$SNOWSessionHeader.Add('Authorization',('Basic {0}' -f $HeaderAuth))
$SNOWSessionHeader.Add('Accept','application/json')
$Type = "application/json"

###############################################
# Getting list of Incidents
###############################################
$IncidentListURL = $SNOWURL+"api/now/table/incident"
Try 
{
    $IncidentListJSON = Invoke-RestMethod -Method GET -Uri $IncidentListURL -TimeoutSec 100 -Headers $SNOWSessionHeader -ContentType $Type
    $IncidentList = $IncidentListJSON.result
}
Catch 
{
    WriteIT $_.Exception.ToString()
#    Write-Host $_.Exception.ToString()

    $error[0] | Format-List -Force
}
###############################################
# Search for existing incident
###############################################

$SearchIncd = "ID: " + $Args[6]

$Incident = $IncidentList | Where-Object {$_.short_description.Contains($SearchIncd)} 
If ($Incident) {
    WriteIT "Found existing incident ( $SearchIncd ) - updating record"

    # Creating JSON body to update incdent with resolved code
    $HASH = @{ 
                state = "1";
                short_description = "Veeam ONE - " + $Args[1] + " - " + $Args[0] + " - Status: " + $Args[4] + " ID: " + $Args[6]
                close_notes = "Reopened by Veeam One Monitor. " + $Args[2] + " at " + $Args[3] + " Status: " + $Args[4] + " ID: " + $Args[6]}

    $JSON = $hash | convertto-json
#    $JSON

    $IncidentURL = $SNOWURL+"api/now/table/incident/" + $Incident.sys_id
    $METHOD = "PATCH"
} else {
    WriteIT "Incident not found. Creating new one. $IncidentID"

    $IncidentURL = $SNOWURL+"api/now/table/incident"
    # Creating JSON body
    $HASH = @{  impact    = "1"; 
                notify = "1"
#                short_description = $Args[1] + " - " + $Args[0] + " - " + $Args[2] + " ID: " + $Args[6]
                short_description = "Veeam ONE - " + $Args[1] + " - " + $Args[0] + " - Status: " + $Args[4] + " ID: " + $Args[6]
                contact_type  = "email"
                comments = $Args[2] + " at " + $Args[3] + " Status: " + $Args[4] + " ID: " + $Args[6]}

    $JSON = $hash | convertto-json 
    $METHOD = "POST"
}


# POST/PATCH to API
Try 
{
    $IncidentPOSTResponse = Invoke-RestMethod -Method $METHOD -Uri $IncidentURL -Body $JSON -TimeoutSec 100 -Headers $SNOWSessionHeader -ContentType $Type
}
Catch 
{
#    Write-Host $_.Exception.ToString()
    WriteIT $_.Exception.ToString()
    $error[0] | Format-List -Force
}
# Pulling ticket ID from response
$IncidentID = $IncidentPOSTResponse.result.number
###############################################
# Verifying Incident created and show ID
###############################################
IF ($IncidentID -ne $null)
{
    WriteIt "Created/Updated Incident With ID:$IncidentID"
}
ELSE
{
    WriteIt "Incident Not Created"
}
##############################################
# End of script
##############################################
