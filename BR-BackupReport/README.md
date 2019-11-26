# Backup and Backup Copy Report

This cmdlet queries every backup/backup copy task session and pulls data for virtual machines specified in a text file
in html format.
The code is ran against a localhost.
Default report path is `C:\Temp\BackupReport.html`.

## Import
To import this cmdlet, `cd` to the directory where `BackupReport.ps1` is kept and execute the following: \
\
`Import-Module .\BackupReport.ps1`

## Parameters
`-Path` - parses a source file with virtual machine names. *REQUIRED* \
`-Backup` - pulls info for backups. *OPTIONAL* \
`-BackupCopy` - pulls info for backup copies. *OPTIONAL* \
\
*If neither `-Backup` nor `-BackupCopy` specified, the report will be generated for both Backups and Backup Copies.*

## Usage

To retrieve backup information on virtual machines specified: \
`Get-BackupReport -Path 'C:\Temp\VirtualMachines.txt' -Backup` \

Backup copy information: \
`Get-BackupReport -Path 'C:\Temp\VirtualMachines.txt' -BackupCopy`\

Both: \
`Get-BackupReport -Path 'C:\Temp\VirtualMachines.txt'`
