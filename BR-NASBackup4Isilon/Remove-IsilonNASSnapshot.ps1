<# 
   .SYNOPSIS
   Deleting a snapshot in a DellEMC Isilon system.

   .DESCRIPTION
   This script deletes a snapshot in a DellEMC Isilon system. The name of the snapshot needs to be provided.
   Hugh kodos go to Christopher Banck who created the PowerShell Module for Isilon which is used by this script: https://github.com/vchrisb/Isilon-POSH
   PowerShell modules IsilonPlatform and SSLValidation are required to run successfully!
    
   .PARAMETER IsilonName
   With this parameter you specify the Isilon DNS name or IP

   .PARAMETER IsilonCluster
   With this parameter you specify the clustername of the Isilon system

   .PARAMETER IsilonCredentialFile
   This parameter is a filename of a saved credentials file for authentification
   
   .PARAMETER SnapshotName
   With this parameter you provide the snapshot name
   
   .PARAMETER LogFile
   You can set your own path for log files from this script. Default path is the same VBR uses by default "C:\ProgramData\Veeam\Backup\IsilonSnapshotDeletion.log"
   
   .INPUTS
   None. You cannot pipe objects to this script

   .Example
   You can add this file and parameter to a Veeam NAS Backup Job
   .\Remove-IsilonNASSnapshot.ps1 -IsilonName '192.168.60.218' -IsilonCluster 'isiloncl01' -SnapshotName 'Veeam-system-hidden$' -IsilonCredentialFile 'C:\Scripts\isilon-system-credentials.xml'


   .Notes 
   Version:        1.0
   Author:         David Bewernick (david.bewernick@veeam.com)
   Creation Date:  2022-04-25
   Purpose/Change: 2022-04-25 - 1.0 - Initial development

 #> 

[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

   [Parameter(Mandatory=$True)]
   [string]$IsilonName,

   [Parameter(Mandatory=$True)]
   [string]$IsilonCluster,
   
   [Parameter(Mandatory=$True)]
   [string]$IsilonCredentialFile,   

   [Parameter(Mandatory=$True)]
   [string]$SnapshotName,

   [Parameter(Mandatory=$False)]
   [string]$LogFile="C:\ProgramData\Veeam\Backup\IsilonSnapshotDeletion.log"

)

PROCESS {

    function Write-Log($Info, $Status){
        $timestamp = get-date -Format "yyyy-mm-dd HH:mm:ss"
        switch($Status){
            Info    {Write-Host "$timestamp $Info" -ForegroundColor Green  ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
            Status  {Write-Host "$timestamp $Info" -ForegroundColor Yellow ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
            Warning {Write-Host "$timestamp $Info" -ForegroundColor Yellow ; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
            Error   {Write-Host "$timestamp $Info" -ForegroundColor Red -BackgroundColor White; "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
            default {Write-Host "$timestamp $Info" -ForegroundColor white "$timestamp $Info" | Out-File -FilePath $LogFile -Append}
        }
    } #end function

    function Load-IsilonModule{
        Write-Log -Info "Trying to load Isilon Powershell module" -Status Info
        try {
            Import-Module IsilonPlatform
            Import-Module SSLValidation
            Write-Log -Info "Loaded requied Isilon Powershell modules sucessfully" -Status Info
        } 
        catch  {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Loading Isilon Powershell module failed" -Status Error
            exit 99
        }
    }

    function Connect-IsilonSystem($IsilonName, $IsilonCluster, $IsilonCredentialFile) {
        # Disable SSl validation
        # $IsilonCredentialFile
        Disable-SSLValidation
        # Set TLS to 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Write-Log -Info "Trying to connect to Isilon $IsilonName on cluster $IsilonCluster " -Status Info
        try {
            $Credential = Import-CliXml -Path $IsilonCredentialFile -ErrorAction Stop  
            New-isiSession -ComputerName $IsilonName -Cluster $IsilonCluster -Credential $Credential -ErrorAction Stop
            Write-Log -Info "Connection established to $IsilonName on cluster $IsilonCluster" -Status Info
        } catch {
            # Error handling if connection fails  
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Connection to $IsilonName could not be established" -Status Error
            exit 1
        }
    }

    function Remove-IsilonSnapShot($SnapshotName) {
        Write-Log -Info "Trying to remove snapshot $SnapshotName" -Status Info
        #check if there is a snapshot with the given name
        try {
            if($ExistingSnap = Get-isiSnapshot -name $SnapshotName) {
                Write-Log -Info "Existing snapshot found, trying to delete it" -Status Info
                try {
                    #rename the current snapshot with the date appended
                    Remove-isiSnapshot -name $SnapshotName -Force
                    Write-Log -Info "Snapshot $SnapshotName has been deleted" -Status Info
                }
                catch {
                    Write-Log -Info "$_" -Status Error
                    Write-Log -Info "Deleting snapshot failed" -Status Error
                    exit 1
                }
            }
        }
        catch {
            Write-Log -Info "No existing snapshot found" -Status Info
        }
    }

    function Remove-IsilonSession() {
        #Disconnect this Isilon session
        Write-Log -Info "Try to disconnect this Isilon session" -Status Info
        try {
            Remove-isiSession
            Write-Log -Info "Isilon session disconnected" -Status Info
        }
        catch {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Disconnecting failes" -Status Error
            exit 1
        }
    }
    
    Write-Log -Info " " -Status Info
    Write-Log -Info "-------------- NEW SESSION --------------" -Status Info
    Write-Log -Info " " -Status Info

    #$IsilonSnapExpireDays
    #$IsilonName
    #$IsilonCluster
    #$IsilonCredentialFile


    #Load the required PS modules
    Load-IsilonModule

    #Connect to the Isilon system
    Connect-IsilonSystem -IsilonName $IsilonName -IsilonCluster $IsilonCluster -IsilonCredentialFile $IsilonCredentialFile

    #Create the new snapshot
    Remove-IsilonSnapShot -SnapshotName $SnapshotName
    
    #Kill this Isilion session
    Remove-IsilonSession

} # END Process