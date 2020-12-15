<# 
   .SYNOPSIS
   Getting SMB shares from NetApp system and create it in VBR
   .DESCRIPTION
   If you have many SMB shares on a NetApp system you maybe
   want to add them in a bulk operation to VBR. This can be
   done by this script
   
   .PARAMETER SVM
   This is the name of the SVM where it shares are.
   .PARAMETER ShareCredential
   Enter the Credentials which should be used to access the SMB shares. They must be from VBR credentials manager.
   .PARAMETER CacheRepository
   Enter the Repository which should be used for Cache.
   .PARAMETER VolumeProcessingMode
   Select if you want to use Direct, StorageSnapshot or VSS Snapshot
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\Import-NetAppSharesToVBR.log"

   .INPUTS
   None. You cannot pipe any objects to this script.

   .Example
   .\Import-NetAppSharesToVBR.ps1 -SVM lab-nacifs01 -VolumeProcessingMode StorageSnapshot -CacheRepository "Default Backup Repository" -ShareCredential "HOMELAB\Administrator"

   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  31 July 2020
   Purpose/Change: New script
   
   .LINK https://github.com/veeamhub/powershell
   .LINK https://horstmann.in
 #> 
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

   [Parameter(Mandatory=$True)]
   [string]$SVM,

   [ValidateSet(“Direct”,”StorageSnapshot”,”VSSSnapshot”)]
   [Parameter(Mandatory=$False)]
   [string]$VolumeProcessingMode="Direct",

   [Parameter(Mandatory=$False)]
   [string]$ShareCredential, 

   [Parameter(Mandatory=$True)]
   [string]$CacheRepository,  

   [Parameter(Mandatory=$False)]
   [string]$LogFile="C:\ProgramData\Import-NetAppSharesToVBR.log"
)


PROCESS {
 
  # Get timestamp for log
  function Get-TimeStamp
  {    
    return "[{0:dd.MM.yyyy} {0:HH:mm:ss}]" -f (Get-Date)
  }

  # This function is used to log status to console and also the given logfilename.
  # Usage: Write-Log -Status [Info, Status, Warning, Error] -Info "This is the text which will be logged"
  function Write-Log($Info, $Status)
  {
    $Info = "$(Get-TimeStamp) $Info"
    switch($Status)
    {
        NewLog {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $LogFile}
        Info    {Write-Host $Info -ForegroundColor Green  ; $Info | Out-File -FilePath $LogFile -Append}
        Status  {Write-Host $Info -ForegroundColor Yellow ; $Info | Out-File -FilePath $LogFile -Append}
        Warning {Write-Host $Info -ForegroundColor Yellow ; $Info | Out-File -FilePath $LogFile -Append}
        Error   {Write-Host $Info -ForegroundColor Red -BackgroundColor White; $Info | Out-File -FilePath $LogFile -Append}
        default {Write-Host $Info -ForegroundColor white $Info | Out-File -FilePath $LogFile -Append}
    }
  } #end function
 

  # This function will load the NetApp Powershell Module.
  function Load-NetAppModule
  {
        Write-Log -Status Info -Info "Trying to load Veeam PS Snapins ..."
    try {
        import-module Veeam.Backup.PowerShell -ErrorAction Stop
        Write-Log -Info "Loading Veeam Backup Powershell Module (V11+) ... SUCCESSFUL" -Status Info
    } catch  {
        Write-Log -Info "$_" -Status Warning
        Write-Log -Info "Loading Veeam Backup Powershell Module (V11+) ... FAILED" -Status Warning
        Write-Log -Info "This can happen if you are using an Veeam Backup & Replication earlier than V11." -Status Warning
        Write-Log -Info "You can savely ignore this warning." -Status Warning
        try {
            Write-Log -Info "Loading Veeam Backup Powershell Snapin (V10) ..." -Status Info
            Add-PSSnapin VeeamPSSnapin -ErrorAction Stop
            Write-Log -Info "Loading Veeam Backup Powershell Snapin (V10) ... SUCCESSFUL" -Status Info
        } catch  {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Loading Veeam Backup Powershell Snapin (V10) ... FAILED" -Status Error
            Write-Log -Info "Was not able to load Veeam Backup Powershell Snapin (V10) or Module (V11)" -Status Error
            exit
        }
    }
  } #end function

  # This function is used to connect to a specfix NetApp SVM
  function Connect-NetAppSVM($svmName)
  {
    Write-Log -Info "Trying to connect to SVM $svmName" -Status Info
    try {
        # Read Credentials from credentials file
        Write-Log -Info "Please enter credentials for SVM $svmName" -Status Info
        $SavedCredential = Get-Credential
        # Save the controller session into a variable to return this into the main script 
        $svmSession = Connect-NcController -name $svmName -Credential $SavedCredential -HTTPS -ErrorAction Stop
        Write-Log -Info "Connection established to $svmName" -Status Info
    } catch {
        # Error handling if connection fails  
        Write-Log -Info "$_" -Status Error
        exit 1
    }
    return $controllersession
  }

  function Get-NetAppSvmShares($svmName, $svmSession)
  {
    try {
        $sharesObject = get-nccifsshare -Controller $svmSession | Where-Object {$_.Path.Length -gt "1"}
        if (!$sharesObject) {
            Write-Log -Info "SVM $svmName has no shares" -Status Error
            exit 40
        }
        Write-Log -Info "Shares was found on $svmName" -Status Info
        return $sharesObject
    } catch {
        Write-Log -Info "$_" -Status Error
        exit 40
    }
  }


  #
  # Main Code starts
  #
  Write-Log -Status NewLog -Info "Starting new log file"

  # Check if Veeam Module can be loaded
  Write-Log -Status Info -Info "Trying to load Veeam PS Snapins ..."
  try {
      Add-PSSnapin VeeamPSSnapin
      Write-Log -Info "Veeam PS Snapin loaded" -Status Info
  } catch  {
      Write-Log -Info "$_" -Status Error
      Write-Log -Info "Failed to load Veeam PS Snapin" -Status Error
      exit 99
  }


  # Load the NetApp Modules
  Load-NetAppModule
  
    # Validate parameters: ShareCrendential (only if provided)
    Write-Log -Status Info -Info "Checking Share Credentials"
    try {
        if($ShareCredential) {
            if($ShareCredential = Get-VBRCredentials -Name $ShareCredential | Select -Last 1) {
                Write-Log -Info "Share Credentials ... FOUND" -Status Info
                } else  {
                    Write-Log -Info "Failed to find share credentials" -Status Error
                    exit 99
                }
        }
        
    } catch {
            Write-Log -Info "Failed to find share credentials" -Status Error
            exit 99
    }
 

    # Validate parameters: Cache Repository
    Write-Log -Status Info -Info "Checking Share Credentials"
    if(Get-VBRBackupRepository -name $CacheRepository)  {
        Write-Log -Info "Cache Repository ... EXISTS" -Status Info
        $repository=Get-VBRBackupRepository -name $CacheRepository
    } else {
        Write-Log -Info "Cache Repository ... NOT FOUND" -Status Error
        exit 50
    }

  
  # Connect to the source NetApp system
  $svmSession = Connect-NetAppSVM -svmName $SVM
  $svmShares = Get-NetAppSvmShares -svmName $SVM -svmSession $svmSession
  Write-Log -Info "Diese Shares wurden gefunden:" -Status Info
  #ToDo: Add here a option to send this output to log
  $svmShares
  
  ForEach($svmShare in $svmShares) {
    $uncPath = "\\" + $svmShare.CifsServer + "\" + $svmShare.ShareName
    if(!(Get-VBRNASServer -Name $uncPath)) {
        try {
            # IF we use Storage Snapshot Mode
            if($VolumeProcessingMode -like "StorageSnapshot") {
                $sharesnapshot = $uncPath + "\~snapshot\VeeamNASBackup"
                Add-VBRNASSMBServer -Path $uncPath -CacheRepository $repository -ProcessingMode StorageSnapshot -StorageSnapshotPath $sharesnapshot -AccessCredentials $ShareCredential
                # IF we use VSS Snapshot Mode
            } elseif($VolumeProcessingMode -like "VSSSnapshot") {
                Add-VBRNASSMBServer -Path $uncPath -CacheRepository $repository -ProcessingMode VSSSnapshot -AccessCredentials $ShareCredential
                # Otherwise we use Direct Mode
            } else {
                Add-VBRNASSMBServer -Path $share -CacheRepository $repository -ProcessingMode Direct -AccessCredentials $ShareCredential
            }
            Write-Log -Info "Adding $uncPath to VBR... DONE" -Status Info
        } catch {
            Write-Log -Info "$_" -Status Error
            Write-Log -Info "Adding $uncPath to VBR... FAILED" -Status Error
            exit 1000
        }
    } else  {
           Write-Log -Info "Share $uncPath is already added... SKIPPING" -Status Info
        }
  }

  Write-Log -Status Info -Info "Script execution finished"
} # END Process
