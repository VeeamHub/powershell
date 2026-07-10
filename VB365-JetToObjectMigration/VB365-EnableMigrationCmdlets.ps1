<#
.SYNOPSIS
	Enable the migration related cmdlets for migrating Jet Repositories to Object Storage Repositories.

.DESCRIPTION
  This script need to be run in PowerShell v7. It enables the migration related cmdlets for migrating Jet Repositories to Object Storage Repositories and the easiest way would be to run it on the VB365 Controller.
  The enablement is only for the current PowerShell session, so if you want to use the migration cmdlets in a new PowerShell session, you will need to run this script again.

.OUTPUTS
	Enabled migration related cmdlets for migrating Jet Repositories to Object Storage Repositories.

.NOTES
	NAME:  VB365-EnableMigrationCmdlets.ps1
	VERSION: 1
	AUTHOR: David Bewernick
	GITHUB: https://github.com/d-works

#>

# If VBO is installed in a different path, please replace it with your own path.
Import-Module 'C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell.dll'

#enable the migration option (on VB365 server)
[Environment]::SetEnvironmentVariable("VEEAM_DATA_MIGRATION_ENABLED", "true")