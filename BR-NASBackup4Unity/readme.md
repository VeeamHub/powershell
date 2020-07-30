Unity-snapshot-orchestration
This script creates a snapshot in a DellEMC Unity system for the path of a defined SMB share. The snapshot is presented as a new share for backup purpose.

Hugh kodos go to Erwan Quélin who created the PowerShell Module for Unity which is used by this script: https://github.com/equelin/Unity-Powershell

!Attention! The PowerShell module masters branch has a missing parameter which prevents it from running in the system context. So use the code from the dev branch for now.

Based on https://github.com/marcohorstmann/psscripts/tree/master/NASBackup by Marco Horstmann (marco.horstmann@veeam.com)

This is version 1.3

Example
c:\scripts\latest\Invoke-UnityNASBackup.ps1 -Name unity01 -Share share01 -CredentialFile C:\Scripts\unity-credentials.xml
