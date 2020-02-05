<# 
   .SYNOPSIS
   Creating a snapshot in a DellEMC Unity system for use with Veeam Backup & Replication NAS backup althernative path option.

   .DESCRIPTION
   This script creates a snapshot in a DellEMC Unity system for the storage resource of a SMB share. The snapshot will be presented as a cifs share in the given path.
   Hugh kodos go to Erwan Quélin who created the PowerShell Module for Unity which is used by this script: https://github.com/equelin/Unity-Powershell
   Please visit: https://unity-powershell.readthedocs.io/en/latest/ for further information and install instructions of the PowerShell module
    
   .PARAMETER UnityName
   With this parameter you specify the Unity DNS name or IP

   .PARAMETER UnityShare
   With this parameter you secify the source SMB share

   .PARAMETER UnityCredentialFile
   This parameter is a filename of a saved credentials file for authentification
   
   .PARAMETER SnapshotName
   With this parameter you can change the default snapshotname "VeeamNASBackup" to your own name

   .PARAMETER SnapExpireSeconds
   Set the seconds when the snapshot should be expired. The default value is 172800, which is 2 days.
   
   .PARAMETER LogFile
   You can set your own path for log files from this script. Default path is the same VBR uses by default "C:\ProgramData\Veeam\Backup\UnityNASBackup.log"
   
   .INPUTS
   None. You cannot pipe objects to this script

   .Example
   c:\scripts\latest\Invoke-UnityNASBackup.ps1 -Name unity01 -Share share01 -CredentialFile C:\Scripts\unity-system-credentials.xml 

   .Notes 
   Version:        1.3
   Author:         David Bewernick (david.bewernick@veeam.com)
   Creation Date:  24.10.2019
   Purpose/Change: Initial script development
   Based on:       https://github.com/marcohorstmann/psscripts/tree/master/NASBackup by Marco Horstmann (marco.horstmann@veeam.com)
 #> 

[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

   [Parameter(Mandatory=$True)]
   [alias("Name")]
   [string]$Script:UnityName,

   [Parameter(Mandatory=$True)]
   [alias("Share")]
   [string]$Script:UnityShare,
   
   [Parameter(Mandatory=$True)]
   [alias("CredentialFile")]
   [string]$Script:UnityCredentialFile,   

   [Parameter(Mandatory=$False)]
   [alias("SnapshotName")]
   [string]$Script:SnapshotName="VeeamNASBackup",

   [Parameter(Mandatory=$False)]
   [alias("SnapExpireSeconds")]
   [int]$Script:SnapExpireSeconds=172800,

   [Parameter(Mandatory=$False)]
   [alias("LogFile")]
   [string]$Script:LogFile="C:\ProgramData\Veeam\Backup\UnityNASBackup.log"

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
    }

    function Load-UnityModule{
        Write-Log -Info "Trying to load Unity Powershell module" -Status Info
        try {
            Import-Module Unity-powershell
            Write-Log -Info "Loaded requied Unity Powershell module sucessfully" -Status Info
        } 
        catch  {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Loading Unity Powershell module failed" -Status Error
            exit 99
        }
    }

    function Connect-System() {
        Write-Log -Info "Trying to connect to Unity $UnityName" -Status Info
        try {
            $Credentials = Import-CliXml -Path $UnityCredentialFile -ErrorAction Stop  
            $Script:UnityConnection = Connect-Unity -Server $UnityName -Credentials $credentials -ErrorAction Stop
            $Script:UnitySession = Get-UnitySession | where {$_.SessionID -eq $UnityConnection.SessionId}
            #Return the new session
            Write-Output $UnitySession
            Write-Log -Info "Connection established to $UnityName" -Status Info
        } catch {
            # Error handling if connection fails  
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Connection to $UnityName could not be established" -Status Error
            exit 1
        }
    }
    
    function DisConnect-System($UnitySession) {
        Write-Log -Info "Trying to disconnect from $UnitySession.SessionId" -Status Info
        try {
            Disconnect-Unity -session $UnitySession -Confirm:$false
            #Return the new session
            Write-Log -Info "Disconnected from $UnityName" -Status Info
        } catch {
            # Error handling if connection fails  
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Could not disconnect from $UnityName" -Status Error
            exit 1
        }
    }

    function Get-FilesystemID (){
        Write-Log -Info "Getting the filesystem ID for the share" -Status Info
        try {
            $objShare = Get-UnityCIFSShare -Name $UnityShare -session $UnitySession
            $filesystemID = $objShare.filesystem.id
            Write-Log -Info "Filesystem ID for $UnityShare is $filesystemID" -Status Info
            return($filesystemID)
            }
        catch {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Getting filesystem ID for $UnityShare failed" -Status Error
            exit 1
        }
    }

    function Get-StorageResource($filesystemID){
        Write-Log -Info "Getting the StorageResource for the filesystem " -Status Info
        try {
            $objFilesystem = Get-UnityFilesystem -ID $filesystemID -session $UnitySession
            $StorageResource = $objFilesystem.storageResource.id
            write-Log -Info "StorageResource for $filesystemID is $StorageResource" -Status Info
            return($StorageResource)
            }
        catch {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Getting filesystem ID for $UnityShare failed" -Status Error
            exit 1
        }
    }

    function Create-NewSnapShot($StorageResource) {
        Write-Log -Info "Trying to create a new snapshot for $StorageResource" -Status Info
        #check if there is a snapshot with the same name
        try {
            if($ExistingSnap = Get-UnitySnap -session $UnitySession -name $SnapshotName) {
                #save the snapshot ID
                $ExistingSnapID = $ExistingSnap.id

                #get the creation time of the snapshot
                $SnapCreationTime = get-date($ExistingSnap.creationTime) -Format yyyy-mm-dd_HH-mm-ss
                Write-Log -Info "Existing snapshot $ExistingSnapID with date $SnapCreationTime found, trying to remove it." -Status Info
                try {
                    #remove the existing snapshot
                    Remove-UnitySnap -session $UnitySession -ID $ExistingSnapID -Confirm:$false
                    Write-Log -Info "Snapshot $ExistingSnapID removed" -Status Info
                }
                catch {
                    Write-Log -Info "$_" -Status Error
                    Write-Log -Info "Removing the old snapshot failed" -Status Error
                    exit 1
                }
            }
        }
        catch {
            Write-Log -Info "No existing snapshot found" -Status Info
        }

        #create a new snapshot for the share
        try {
            $objSnapshot = New-UnitySnap -storageResource $StorageResource -session $UnitySession -name $SnapshotName -Description "Veeam Backup Snapshot" -retentionDuration $SnapExpireSeconds -filesystemAccessType Protocol -Confirm:$false
            $SnapShotID = $objSnapshot.ID
            Write-Log -Info "New snapshot named $SnapshotName created, ID: $SnapShotID" -Status Info
            return($SnapShotID)
        }
        catch {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Snapshot creation failed" -Status Error
            exit 1
        }
    }

    function create-NewBackupShare($SnapShotID){
        #creat a new share for the newly created snapshot. This has to be done with a direct RestAPI call since the needed option is missing in the Unity powershell module.
        try {
            #Build the json body
            $json = @{
	                name=$SnapShotName
	                path='/'
	                snap=@{
			            id=$SnapShotID
		            }
            } | ConvertTo-Json

        #Build the RestAPI URL string
        $resourceurl = "/api/types/cifsShare/instances"
        $uri = "https://" + $UnitySession.Server + $resourceurl

        # Invoke the RestAPI call

        $objSnapShare = Invoke-WebRequest -Uri $URI -ContentType "application/json" -Body $json -Websession $UnitySession.Websession -Headers $UnitySession.headers -Method POST -TimeoutSec 6000 -UseBasicParsing

        $objSnapShareContent = $objSnapShare.Content | convertfrom-json
        $SnapID = $objSnapShareContent.content.id
        Write-Log -Info "New cifs share named $SnapShotName created, ID: $SnapID" -Status Info
        }
        catch {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "CIFS share creation failed" -Status Error
            exit 1
        }
    }


    Write-Log -Info " " -Status Info
    Write-Log -Info "-------------- NEW SESSION --------------" -Status Info
    Write-Log -Info " " -Status Info

    #Load the required PS modules
    Load-UnityModule


    #Connect to the Unity system
    Connect-System 

    #retrieve the filesystem ID of the SMB share
    $filesystemID = Get-FilesystemID

    #retrieve the storage Resource of the filesystem
    $StorageResource = Get-StorageResource($filesystemID)

    #Create the new snapshot
    $SnapShotID = Create-NewSnapShot($StorageResource)

    #Create new CIFS share mounted to the snapshot
    create-NewBackupShare($SnapShotID)
    
    #Disconnect from the current session
    DisConnect-System($UnitySession)   
  

} # END Process
