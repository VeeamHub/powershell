<# 
   .SYNOPSIS
   Creating a snapshot in a DellEMC Isilon system for use with Veeam Backup & Replication NAS backup althernative path option.

   .DESCRIPTION
   This script creates a snapshot in a DellEMC Isilon system for the path of a defined SMB share. The snapshot is presented in the \ifs\.snapshot folder of the filesystem root.
   Hugh kodos go to Christopher Banck who created the PowerShell Module for Isilon which is used by this script: https://github.com/vchrisb/Isilon-POSH
   IsilonPlatform and SSLValidation are required to run this here successfully!
    
   .PARAMETER IsilonName
   With this parameter you specify the Isilon DNS name or IP

   .PARAMETER IsilonCluster
   With this parameter you specify the clustername of the Isilon system
   
   .PARAMETER IsilonAccessZone
   With this parameter you specify the Access Zone for the share. If no value is provided the defaule "System" zone will be used.

   .PARAMETER IsilonShare
   With this parameter you secify the source SMB share

   .PARAMETER IsilonCredentialFile
   This parameter is a filename of a saved credentials file for authentification
   
   .PARAMETER SnapshotName
   With this parameter you can change the default snapshotname "VeeamNASBackup" to your own name

   .PARAMETER IsilonSnapExpireDays
   Set the days when the snapshot should be expired. The default value is 2 days.
   
   .PARAMETER LogFile
   You can set your own path for log files from this script. Default path is the same VBR uses by default "C:\ProgramData\Veeam\Backup\IsilonNASBackup.log"
   
   .INPUTS
   None. You cannot pipe objects to this script

   .Example
   You can add this file and parameter to a Veeam NAS Backup Job
   .\Invoke-IsilonNASBackup_v1.4.ps1 -IsilonName "192.168.60.218" -IsilonCluster "isiloncl01" -IsilonAccessZone "demo01" -IsilonShare "az01share01" -IsilonCredentialFile 'C:\Scripts\isilon-system-credentials.xml' -IsilonSnapExpireDays "2"


   .Notes 
   Version:        1.4
   Author:         David Bewernick (david.bewernick@veeam.com)
   Creation Date:  05.09.2019
   Purpose/Change: 05.09.2019 - 1.3 - Initial script development
                   11.04.2022 - 1.4 - Added support for Access Zones
                                    - Added enforcement TLS1.2

   Based on:       https://github.com/marcohorstmann/psscripts/tree/master/NASBackup by Marco Horstmann (marco.horstmann@veeam.com)
 #> 

[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

   [Parameter(Mandatory=$True)]
   [string]$IsilonName,

   [Parameter(Mandatory=$True)]
   [string]$IsilonCluster,
   
   [Parameter(Mandatory=$False)]
   [string]$IsilonAccessZone="System",

   [Parameter(Mandatory=$True)]
   [string]$IsilonShare,
   
   [Parameter(Mandatory=$True)]
   [string]$IsilonCredentialFile,   

   [Parameter(Mandatory=$False)]
   [string]$SnapshotName="VeeamNASBackup",

   [Parameter(Mandatory=$False)]
   [int]$IsilonSnapExpireDays=2,

   [Parameter(Mandatory=$False)]
   [string]$LogFile="C:\ProgramData\Veeam\Backup\IsilonNASBackup.log"

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

    function Set-IsilonSnapExpireDate($IsilonSnapExpireDays) {
        #$IsilonSnapExpireDate = ((get-date -date (get-date).AddDays($IsilonSnapExpireDays) -UFormat %s)).split(',')[0]
        $IsilonSnapExpireDate = ((get-date -date ((get-date).ToUniversalTime()).AddDays(2) -UFormat %s)).split(',')[0]
        
        Write-Log -Info "Calculated the snapshot expiry date to $IsilonSnapExpireDate" -Status Info
        return($IsilonSnapExpireDate)
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

    function Get-IsilonSharePath($IsilonShare, $IsilonAccessZone){
        Write-Log -Info "Getting the path value from $IsilonShare in $IsilonAccessZone" -Status Info
        #Write-Host $IsilonAccessZone
        try {
            $objIsilonShare = Get-isiSmbShares -access_zone $IsilonAccessZone | where {$_.Name -eq $IsilonShare}
            #Write-Host $objIsilonShare
            $IsilonSharePath = $objIsilonShare.path
            #Write-Host $IsilonSharePath
            if ($IsilonSharePath -ne $null) {
                Write-Log -Info "Path for $IsilonShare is $IsilonSharePath" -Status Info
                return($IsilonSharePath)
            }
            else {
                Write-Log -Info "Path for $IsilonShare not found" -Status Warning
                exit 1
            }
        }
        catch {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Getting path for $IsilonShare failed" -Status Error
            exit 1
        }
    }

    function Create-IsilonSnapShot($SnapshotName, $IsilonSharePath, $IsilonSnapExpireDate) {
        Write-Log -Info "Trying to create a new snapshot mount for $IsilonSharePath" -Status Info
        #check if there is a snapshot with the same name
        try {
            if($ExistingSnap = Get-isiSnapshot -name $SnapshotName) {
                Write-Log -Info "Existing snapshot found, trying to rename it" -Status Info
                #get the current time
                $dateAppendix = get-date -Format yyyy-mm-dd_HH-mm-ss
                #need to change this to the snap creation date
                #$dateAppendix = get-date($ExistingSnap.creationTime) -Format yyyy-mm-dd_HH-mm-ss
                try {
                    #rename the current snapshot with the date appended
                    $OldSnapshotName = $SnapshotName + "_" + $dateAppendix
                    Set-isiSnapshot -name $SnapshotName -new_name $OldSnapshotName -Force
                    Write-Log -Info "Snapshot renamed to $OldSnapshotName" -Status Info
                }
                catch {
                    Write-Log -Info "$_" -Status Error
                    Write-Log -Info "Renaming the old snapshot failed" -Status Error
                    exit 1
                }
            }
        }
        catch {
            Write-Log -Info "No existing snapshot found" -Status Info
        }

        #create a new snapshot for the share
        try {
            New-isiSnapshots -name $SnapshotName -path $IsilonSharePath -expires $IsilonSnapExpireDate
            Write-Log -Info "New snapshot named $SnapshotName created" -Status Info
        }
        catch {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Snapshot creation failed" -Status Error
            exit 1
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
    #write-host $IsilonAccessZone

    #Get the desired snapshot expiration date
    $IsilonSnapExpireDate = Set-IsilonSnapExpireDate($IsilonSnapExpireDays)

    #Connect to the Isilon system
    Connect-IsilonSystem -IsilonName $IsilonName -IsilonCluster $IsilonCluster -IsilonCredentialFile $IsilonCredentialFile

    #retrieve the path of the SMB share
    $IsilonSharePath = Get-IsilonSharePath -IsilonShare $IsilonShare -IsilonAccessZone $IsilonAccessZone

    #Create the new snapshot
    Create-IsilonSnapShot -SnapshotName $SnapshotName -IsilonSharePath $IsilonSharePath -IsilonSnapExpireDate $IsilonSnapExpireDate
    
    #Kill this Isilion session
    #Remove-IsilonSession

} # END Process