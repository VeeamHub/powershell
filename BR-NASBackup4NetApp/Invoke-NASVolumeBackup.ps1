<# 
   .SYNOPSIS
   Create NetApp Snapshot and optional Transfer to secondary destination for NAS Backup 
   .DESCRIPTION
   This script create an snapshot on the given primary volume(s). After creating this snapshot
   this snapshot will optional transfered to a secondary destination.
   .PARAMETER PrimaryCluster
   With this parameter you specify the source NetApp cluster, where the volume is located.
   .PARAMETER PrimarySVM
   With this parameter you specify the source NetApp SVM, where the volume is located.
   .PARAMETER PrimaryVolume
   With this parameter you specify the source volume(s) from primary SVM. You can add
   here more than one volume with "vol1","vol2","etc" but this only works if you are not
   use a secondary destination.
   .PARAMETER PrimaryClusterCredentials
   This parameter is a filename of a saved credentials file for source cluster.
   .PARAMETER SecondaryCluster
   With this parameter you specify the destination NetApp cluster, where the destination volume is located.
   .PARAMETER SecondarySVM
   With this parameter you specify the secondary NetApp SVM, where the destination volume is located.
   .PARAMETER SecondaryVolume
   With this parameter you specify the secondary volume from secondary SVM.
   .PARAMETER SecondaryClusterCredentials
   This parameter is a filename of a saved credentials file for secondary cluster.
   .PARAMETER SnapshotName
   With this parameter you can change the default snapshotname "VeeamNASBackup" to your own snapshotname.
   .PARAMETER LogFile
   You can set your own path for log file from this script. Default filename is "C:\ProgramData\NASBackup.log"
   .PARAMETER RetainLastDestinationSnapshots
   If you want to keep the last X snapshots which was transfered to snapvault destination. Default: 2
   .PARAMETER UseSecondaryDestination
   With UseSecondaryDestinatination the script will require details to a secondary system. Without this Parameter you can just backup from primary share.

   .INPUTS
   None. You cannot pipe any objects to this script.

   .Example
   If you want to use this script with only one NetApp system you can use this parameters.
   You can add this file and parameter to a Veeam NAS Backup Job
   .\Invoke-NASBackup.ps1 -PrimaryCluster 192.168.1.220 -PrimarySVM "lab-netapp94-svm1" -PrimaryVolume "vol_cifs" -PrimaryClusterCredentials "C:\scripts\saved_credentials_Administrator.xml"

   .Example
   if you are only running this script against a primary NetApp system you can specify multiple volumes.
   You can add this file and parameter to a Veeam NAS Backup Job
   .\Invoke-NASBackup.ps1 -PrimaryCluster 192.168.1.220 -PrimarySVM "lab-netapp94-svm1" -PrimaryVolume "volume1","volume2","volume3" -PrimaryClusterCredentials "C:\scripts\saved_credentials_Administrator.xml"

   .Example
   If you want to use a secondary destination as source for NAS Backup you can use this parameter set.
   You can add this file and parameter to a Veeam NAS Backup Job
   .\Invoke-NASBackup.ps1 -PrimaryCluster 192.168.1.220 -PrimarySVM "lab-netapp94-svm1" -PrimaryVolume "vol_cifs" -PrimaryClusterCredentials "C:\scripts\saved_credentials_Administrator.xml" -UseSecondaryDestination -SecondaryCluster 192.168.1.225 -SecondarySVM "lab-netapp94-svm2" -SecondaryVolume "vol_cifs_vault" -SecondaryCredentials "C:\scripts\saved_credentials_Administrator.xml" 

   .Notes 
   Version:        4.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  30 July 2020
   Purpose/Change: Forked script to allow adding volume name instead of share name
                   Also improved logging
   
   .LINK https://github.com/veeamhub/powershell
   .LINK https://horstmann.in
 #> 
[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
Param(

   [Parameter(Mandatory=$True)]
   [string]$PrimaryCluster,

   [Parameter(Mandatory=$True)]
   [string]$PrimarySVM,
   
   [Parameter(Mandatory=$True)]
   [string[]]$PrimaryVolume,
   
   [Parameter(Mandatory=$True)]
   [string]$PrimaryClusterCredentials,   

   [Parameter(Mandatory=$False)]
   [string]$SnapshotName="VeeamNASBackup",

   [Parameter(Mandatory=$False)]
   [string]$LogFile="C:\ProgramData\NASBackup.log",

   [Parameter(Mandatory=$False)]
   [int]$RetainLastDestinationSnapshots=2,

   [Parameter(Mandatory=$False)]
   [switch]$UseSecondaryDestination
)

DynamicParam {
  # If Parameter -UseSecondaryDestination was set, the script needs additional parameters to work.
  # With this codesection I was able to create dynamic parameters.
  if ($UseSecondaryDestination)
  { 
    #create paramater dictenory
    $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

    #create general settings for all attributes which will be assigend to the parameters
    $attributes = New-Object System.Management.Automation.ParameterAttribute
    $attributes.ParameterSetName = "__AllParameterSets"
    $attributes.Mandatory = $true
    $attributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
    $attributeCollection.Add($attributes)

    #Creating the diffentent dynamic parameters
    $SecondaryClusterAttribute = New-Object System.Management.Automation.ParameterAttribute
    $SecondaryClusterAttribute.Mandatory = $true
    $SecondaryClusterAttribute.HelpMessage = "This is the secondary system in a mirror and/or vault relationship"
    $SecondaryClusterParam = New-Object System.Management.Automation.RuntimeDefinedParameter('SecondaryCluster', [String], $attributeCollection)

    $SecondarySVMAttribute = New-Object System.Management.Automation.ParameterAttribute
    $SecondarySVMAttribute.Mandatory = $true
    $SecondarySVMAttribute.HelpMessage = "This is the secondary SVM in a mirror and/or vault relationship"
    $SecondarySVMParam = New-Object System.Management.Automation.RuntimeDefinedParameter('SecondarySVM', [String], $attributeCollection)

    $SecondaryVolumeAttribute = New-Object System.Management.Automation.ParameterAttribute
    $SecondaryVolumeAttribute.Mandatory = $true
    $SecondaryVolumeAttribute.HelpMessage = "This is the secondary volume in a mirror and/or vault relationship"
    $SecondaryVolumeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('SecondaryVolume', [String], $attributeCollection)
    
    $SecondaryCredentialsAttribute = New-Object System.Management.Automation.ParameterAttribute
    $SecondaryCredentialsAttribute.Mandatory = $false
    $SecondaryCredentialsAttribute.HelpMessage = "This is the secondary share in a mirror and/or vault relationship"
    $SecondaryCredentialsParam = New-Object System.Management.Automation.RuntimeDefinedParameter('SecondaryCredentials', [String], $attributeCollection)
    $SecondaryCredentialsParam.Value = $PrimaryClusterCredentials

    #Add here all parameters to the dictionary to make them available for use in script
    $paramDictionary.Add('SecondaryCluster', $SecondaryClusterParam)
    $paramDictionary.Add('SecondarySVM', $SecondarySVMParam)
    $paramDictionary.Add('SecondaryVolume', $SecondaryVolumeParam)
    $paramDictionary.Add('SecondaryCredentials', $SecondaryCredentialsParam)
    #add here additional parameters if later needed
  }

  return $paramDictionary
}

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
    Write-Log -Info "Trying to load NetApp Powershell module" -Status Info
    try {
        Import-Module DataONTAP
        Write-Log -Info "Loaded NetApp Powershell module sucessfully" -Status Info
    } catch  {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Loading NetApp Powershell module failed" -Status Error
        exit 99
    }
  }

  # This function is used to connect to a specfix NetApp SVM
  function Connect-NetAppSystem($clusterName, $svmName, $clusterCredential)
  {
    Write-Log -Info "Trying to connect to SVM $svmName on cluster $clusterName " -Status Info
    try {
        # Read Credentials from credentials file
        $Credential = Import-CliXml -Path $clusterCredential -ErrorAction Stop
        # Save the controller session into a variable to return this into the main script 
        $ControllerSession = Connect-NcController -name $clusterName -Vserver $svmName -Credential $Credential -HTTPS -ErrorAction Stop
        Write-Log -Info "Connection established to $svmName on cluster $clusterName" -Status Info
    } catch {
        # Error handling if connection fails  
        Write-Log -Info "$_" -Status Error
        exit 1
    }
    return $controllersession
  }

  function Get-NetAppVolumeInfo($Controller, $SVM, $Volume)
  {
    try {
        $volumeObject = Get-NcVol -Controller $Controller -VserverContext $SVM -name $Volume
        if (!$volumeObject) {
            Write-Log -Info "Volume $Volume was not found" -Status Error
            exit 40
        }
        Write-Log -Info "Volume $Volume was found" -Status Info
        return $volumeObject
    } catch {
        # Error handling if snapshot cannot be removed
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Volume $Volume couldn't be located" -Status Error
        exit 40
    }
  }

  # This function deletes a snapshot 
  function Remove-NetAppSnapshot($SnapshotName, $Controller, $SVM, $Volume)
  {
    # If an Snapshot with the name exists delete it
    if(get-NcSnapshot -Controller $Controller -Vserver $SVM -Volume $Volume -Snapshot $SnapshotName -Verbose) {
      Write-Log -Info "Previous Snapshot exists and will be removed..." -Status Info
      try {
        Remove-NcSnapshot -Controller $Controller -VserverContext $SVM -Volume $Volume -Snapshot $SnapshotName -Verbose -Confirm:$false -ErrorAction Stop
        Write-Log -Info "Previous Snapshot was removed" -Status Info
      } catch {
        # Error handling if snapshot cannot be removed
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Previous Snapshot could be removed" -Status Error
        exit 50
      }
    }
  }

  # This function creates a snapshot on source system
  function Create-NetAppSnapshot($SnapshotName, $Controller, $SVM, $Volume)
  {
    Write-Log -Info "Snapshot will be created..." -Status Info
    try {
      New-NcSnapshot -Controller $Controller -VserverContext $SVM -Volume $Volume -Snapshot $SnapshotName -Verbose
      Write-Log -Info "Snapshot was created" -Status Info
    } catch {
      Write-Log -Info "$_" -Status Error
      Write-Log -Info "Snapshot could not be created" -Status Error
      exit 1
    }
  }

  # This function is used to rename snapshots on secondary system e.g. Snapvault volume.
  function Rename-NetAppSnapshot($SnapshotName, $NewSnapshotName, $Controller, $SVM, $Volume)
  {
    if(get-NcSnapshot -Controller $Controller -Vserver $SVM -Volume $Volume -Snapshot $SnapshotName -Verbose) {
      Write-Log -Info "Actual Snapshot exists and will be renamed..." -Status Info
      try {
      get-NcSnapshot -Controller $Controller -Vserver $SVM -Volume $Volume -Snapshot $SnapshotName | Rename-NcSnapshot -NewName $NewSnapshotName
      Write-Log -Info "Snapshot was renamed" -Status Info
      } catch {
        # Error handling if snapshot cannot be removed
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Snapshot could not be renamed" -Status Error
        exit 1
      }
    } 
  }

  # This function transfer snapshot to the destination system and waits until transfer is completed
  function Start-NetAppSync($Controller, $SecondarySVM, $SecondaryVolume, $PrimarySnapshotName)
  {
    #transfer snapshot to the destination system
      try {
        Write-Log -Info "SecondarySVM: $SecondarySVM" -Status Info
        Write-Log -Info "SecondaryVolume: $SecondaryVolume" -Status Info
        Write-Log -Info "Snapshot: $PrimarySnapshotName" -Status Info
        Invoke-NcSnapmirrorUpdate -Controller $Controller -DestinationVserver $SecondarySVM -DestinationVolume $SecondaryVolume -SourceSnapshot $PrimarySnapshotName -Verbose
        Write-Log -Info "Waiting for SV Transfer to finish..." -Status Info
        Start-Sleep 20
        # Check every 30 seconds if snapvault relationship is in idle state
        while (get-ncsnapmirror -Controller $Controller -DestinationVserver $SecondarySVM -DestinationVolume $SecondaryVolume | ? { $_.Status -ine "idle" } ) {
          Write-Log -Info "Waiting for SV Transfer to finish..." -Status Info
          Start-Sleep -seconds 30
        }
        Write-Log -Info "SV Transfer Finished" -Status Info
      } catch {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Transfering Snapshot to destination system failed" -Status Error
        exit 1
      }
  }

  # This function gets the snapshots from destination and delete all snapshots created by this script and maybe retain X snapshots
  # depending on parameter RetainLastDestinationSnapshots
  function CleanUp-SecondaryDestination($Controller, $SecondarySVM, $SecondaryVolume, $PrimarySnapshotName)
  {
    $SnapshotNameWithDate = $SnapshotName + "_*"
    Write-Log -Info "Starting with cleaning up destination snapshots" -Status Info
    #Checking if it is a vault or mirror
    $MirrorRelationship = Get-NcSnapmirror -Controller $Controller -DestinationVserver $SecondarySVM -DestinationVolume $SecondaryVolume
    if($MirrorRelationship.PolicyType -eq "vault")
    {
      try {
        Write-Log -Info "This is a snapvault relationship. Cleanup needed" -Status Info
        get-NcSnapshot -Controller $Controller -Vserver $SecondarySVM -Volume $SecondaryVolume -Snapshot $SnapshotNameWithDate | Sort-Object -Property Created -Descending | Select-Object -Skip $RetainLastDestinationSnapshots | Remove-NcSnapshot -Confirm:$false -ErrorAction Stop
        Write-Log -Info "Old Snapshots was cleaned up" -Status Info
      } catch {
        Write-Log -Info "$_" -Status Error
        Write-Log -Info "Snapshots couldn't be cleaned up at destination volume" -Status Error
      }
    }
    elseif($MirrorRelationship.PolicyType -eq "async_mirror")
    {
      Write-Log -Info "This is a snapmirror relationship. Cleanup not needed" -Status Info
    }
    elseif($MirrorRelationship.PolicyType -eq "mirror_vault")
    {
      Write-Log -Info "This is a mirror and vault relationship. No idea how it works so I do nothing." -Status Warning
    }
   
  }

  #Add dynamic paramters to use it in normal code
  foreach($key in $PSBoundParameters.keys)
    {
        Set-Variable -Name $key -Value $PSBoundParameters."$key" -Scope 0
    }

  #
  # Main Code starts
  #
  Write-Log -Status NewLog -Info "Starting new log file"


  # Additional checks for unsupported configuration
  if($PrimaryVolume.Count -gt 1) {
    Write-Log -Info "More than one primary volume was added. This is not supported with secondary destination" -Status Error
    exit 999
  }

  # Load the NetApp Modules
  Load-NetAppModule
  # Connect to the source NetApp system
  $PrimaryClusterSession = Connect-NetAppSystem -clusterName $PrimaryCluster -svmName $PrimarySVM -clusterCredential $PrimaryClusterCredentials

  # IF we use Secondary Storage System we need to connect to this controller (exept its the same system as source)
  if($UseSecondaryDestination -and ($PrimaryCluster -ne $SecondaryCluster))
  {
    $SecondaryClusterSession = Connect-NetAppSystem -clusterName $SecondaryCluster -svmName $SecondarySVM -clusterCredential $SecondaryCredentials
  } else {
    $SecondaryClusterSession = $PrimaryClusterSession
  }
  #Get the volume properties
  
  ForEach($SingleVolume in $PrimaryVolume) {
    $PrimaryVolumeObject = Get-NetAppVolumeInfo -Controller $PrimaryClusterSession -SVM $PrimarySVM -Volume $SingleVolume

    # This codeblock is only needed if we transfer to a secondary system. 
    if($UseSecondaryDestination)
    {
        #If using Snapvault or SnapMirror we cannot just delete the snapshot. We need to rename
        #it otherwise we get problems with the script
        $OldSnapshotName = $SnapshotName + "OLD"
        $SecondaryVolumeObject = Get-NetAppVolumeInfo -Controller $SecondaryClusterSession -SVM $SecondarySVM -Volume $SecondaryVolume
        Remove-NetAppSnapshot -SnapshotName $OldSnapshotName -Controller $PrimaryClusterSession -SVM $PrimarySVM -Volume $PrimaryVolumeObject
        # Rename exisiting Snapshot to $OldSnapshotName
        Rename-NetAppSnapshot -SnapshotName $SnapshotName -NewSnapshotName $OldSnapshotName -Controller $PrimaryClusterSession -SVM $PrimarySVM -Volume $PrimaryVolumeObject
        Create-NetAppSnapshot -SnapshotName $SnapshotName -Controller $PrimaryClusterSession -SVM $PrimarySVM -Volume $PrimaryVolumeObject
        Start-NetAppSync -Controller $SecondaryClusterSession -SecondarySVM $SecondarySVM -SecondaryVolume $SecondaryVolumeObject -PrimarySnapshotName $SnapshotNameObject
        Cleanup-SecondaryDestination -Controller $SecondaryClusterSession -SecondarySVM $SecondarySVM -SecondaryVolume $SecondaryVolumeObject -SourceSnapshotName $SnapshotName
    
        # If we dont use seconady systems we only take care of processing on the primary system.
    } else {
        #Just rotate the local snapshot when no secondary destination is enabled
        Remove-NetAppSnapshot -SnapshotName $SnapshotName -Controller $PrimaryClusterSession -SVM $PrimarySVM -Volume $PrimaryVolumeObject
        Create-NetAppSnapshot -SnapshotName $SnapshotName -Controller $PrimaryClusterSession -SVM $PrimarySVM -Volume $PrimaryVolumeObject
    }
  }

  Write-Log -Status Info -Info "Script execution finished"
} # END Process
