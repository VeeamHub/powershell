# Isilon-snapshot-orchestration
This script creates a snapshot in a DellEMC Isilon system for the path of a defined SMB share. The snapshot is presented in the root subfolder .snapshots of the filesystem root.

Hugh kodos go to Christopher Banck who created the PowerShell Module for Isilon which is used by this script: https://github.com/vchrisb/Isilon-POSH

Based on https://github.com/marcohorstmann/psscripts/tree/master/NASBackup by Marco Horstmann (marco.horstmann@veeam.com)

Important: IsilonPlatform and SSLValidation are required to run this here successfully and can be found here: https://github.com/vchrisb/Isilon-POSH

This is version 1.4

# Example
.\Invoke-IsilonNASBackup_v1.4.ps1 -IsilonName "192.168.60.218" -IsilonCluster "isiloncl01" -IsilonAccessZone "demo01" -IsilonShare "az01share01" -IsilonCredentialFile 'C:\Scripts\isilon-system-credentials.xml' -IsilonSnapExpireDays "2"
