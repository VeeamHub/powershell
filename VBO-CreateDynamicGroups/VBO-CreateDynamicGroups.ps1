<# 
   .SYNOPSIS
   Creating AzureAD dynamic groups with user membership based on regex 

   .DESCRIPTION
   !!! You need to use the AzureADPreview module since the parameter "MembershipRule" is only available in the beta of GraphAPI.
   -> Install-Module AzureADPreview -Scope CurrentUser -AllowClobber !!!

   This script creates AzureAD dynamic groups to split up the users of a whole tenant based on the first two characters of their ObjectID. The number of groups beeing created is depending on the array of first and second character.
   In the default verion of this script you will end up with 64 groups since the first charakter will be from "0" to "f" and the second character will be part of 4 grouping expressions.
    
   .NOTES 
   Version:        0.2
   Author:         David Bewernick (david.bewernick@veeam.com)
   Creation Date:  15.06.2021
   Purpose/Change: Initial script development

   .CHANGELOG
   v0.1   14.06.2021   Script created
   v0.2   15.06.2021   Added out-file for groupnames

 #> 

$timestampFileName = get-date -Format "yyyy-mm-dd_HH-mm-ss"

[string]$Script:LogFile = "VBO-CreateDynamicGroups.log" #logfile name
[string]$Script:GroupNameFile = "DynamicGroupsList_$timestampFileName.log" #file to export group names
[string]$Script:strGroupNameStart = "VBO-UserBackup_"
[string[]]$script:arrFirstChar = @("0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f") #array of characters for the regex
[string[]]$Script:arrScndChar = @('0-3','4-7','8-9a-b','c-f')


    function Write-Log($Info, $Status){
        $timestamp = get-date -Format "yyyy-mm-dd HH:mm:ss"
        switch($Status){
            Info    {Write-Host "$timestamp $Info" -ForegroundColor Green  ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
            Status  {Write-Host "$timestamp $Info" -ForegroundColor Yellow ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
            Warning {Write-Host "$timestamp $Info" -ForegroundColor Yellow ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
            Error   {Write-Host "$timestamp $Info" -ForegroundColor Red -BackgroundColor White; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
            default {Write-Host "$timestamp $Info" -ForegroundColor white "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
        }
    }


    function Create-Groups(){ #Function to greate the groups
        $i=0
        while($i -lt $arrFirstChar.length){ #go through the array for the first character
            $j=0            
            while($j -lt $arrScndChar.length){ #go through the array for the second character
                $strRegex = '^' + $arrFirstChar[$i] + '[' + $arrScndChar[$j] + ']' #building the regex based on the array strings
                $strGroupName = $strGroupNameStart + $arrFirstChar[$i] + $arrScndChar[$j] #create the group name
                $strMembershipRule = '(user.objectID -match "' + $strRegex + '") and (user.mail -ne $null) and (user.accountEnabled -eq true)' #define the Membership rule based on the regex and "(user.mail -ne $null) and (user.accountEnabled -eq true)"
                #Write-Output $strGroupName
                #Write-Output $strRegex
                #Write-Output $strMembershipRule

                if((Get-AzureADMSGroup | where{$_.DisplayName -eq $strGroupName}) -eq $null) {
                    try {
                        New-AzureADMSGroup -DisplayName "$strGroupName" -MailNickname "$strGroupName" -Description "Group for VBO backup with rule $strRegex" -MailEnabled $false -GroupTypes {DynamicMembership} -SecurityEnabled $true -MembershipRule "$strMembershipRule" -MembershipRuleProcessingState 'on' #this is finally creating the dynamic group in AzureAD
                        Write-Log -Info "Group $strGroupName created with MembershipRule $strMembershipRule" -Status Info
                        $strGroupName | Out-File -FilePath $GroupNameFile -Append # write groupname to CSV file
                    }
                    catch{
                        Write-Log -Info "$_" -Status Error
                        Write-Log -Info "Group $strGroupName could not be created" -Status Error
                        exit 99
                    }
                }
                else { 
                    Write-Log -Info "Group $strGroupName is already existing" -Status Status
                    $strGroupName | Out-File -FilePath $GroupNameFile -Append # write groupname to CSV file
                }

                $j++
            }
        $i++
        }
   
    }

#Install-Module AzureADPreview -Scope CurrentUser -AllowClobber #uncomment this to install the AureADPreview module

#Connecting to AzureAD
Write-Log -Info "Trying to connect to AzureAD..." -Status Info
    try {
        Connect-AzureAD
        $ConnectionAccountName = Get-AzureADCurrentSessionInfo | select Account
        Write-Log -Info "Connection successful with $ConnectionAccountName" -Status Info
        } 
    catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Could not connect with $ConnectionAccountName" -Status Error
        exit 99
    }


Write-Log -Info "Creating the groups..." -Status Info
Create-Groups



#Disconnecting from AzureAD
Write-Log -Info "Trying to disconnect from AzureAD..." -Status Info
    try {
        Disconnect-AzureAD
        Write-Log -Info "Successfully disconnected" -Status Info
        } 
    catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Could not disconnect from AzureAD" -Status Error
        exit 99
    }