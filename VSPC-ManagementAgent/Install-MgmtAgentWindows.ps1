<#
.SYNOPSIS
Veeam Service Provider Console (VSPC) Install Management Agent for Windows OS

.DESCRIPTION
This script will install a Veeam Service Provider Console management agent on a machine running the Windows operating system.

.PARAMETER Msi
Path to the VSPC management agent MSI file

.PARAMETER LogFile
Path to the installation log file. Default is the current folder with the name "VACAgentSetup.txt".

.PARAMETER InstallDir
Path to the installation directory. By default, Veeam Service Provider Console uses the "CommunicationAgent" subfolder of the "C:\Program Files\Veeam\Availability Console" folder.

Example: InstallDir="C:\Veeam\"

The component will be installed to: "C:\Veeam\CommunicationAgent"

.PARAMETER ServiceAccountType
Type of service account the management agent will use to run the agent service. 1 = Local System Account OR 2 = Account specified in ServiceUser and ServicePass parameters. Default is 1.

.PARAMETER ServiceUser
Username of an account under which management agent service will run. Required if ServiceAccountType is set to 2.

.PARAMETER ServicePass
Password of an account under which management agent service will run. Required if ServiceAccountType is set to 2.

.PARAMETER Tag
Tag that will be assigned to the management agent during installation. The tag can be used to filter agents in the VSPC web console.

.OUTPUTS
Install-MgmtAgentWindows.ps1 returns the exit code of the MSI installation process. A value of 0 indicates a successful installation.

.EXAMPLE
Install-MgmtAgentWindows.ps1 -Msi "ManagementAgent.My_Company.msi"

Description
-----------
Installs the VSPC management agent using the specified MSI file with default parameters

.EXAMPLE
Install-MgmtAgentWindows.ps1 -Msi "ManagementAgent.My_Company.msi" -LogFile "C:\Logs\VACAgentSetup.txt" -InstallDir "C:\Veeam"

Description
-----------
Installs the VSPC management agent using the specified MSI file, log file path, and installation directory

.EXAMPLE
Install-MgmtAgentWindows.ps1 -Msi "ManagementAgent.My_Company.msi" -Tag "My_Windows_Agent_01"

Description
-----------
Installs the VSPC management agent using the specified MSI file and assigns the specified tag to the management agent

.EXAMPLE
Install-MgmtAgentWindows.ps1 -Msi "ManagementAgent.My_Company.msi" -Verbose

Description
-----------
Verbose output is enabled to provide additional details

.NOTES
NAME:  Install-MgmtAgentWindows.ps1
VERSION: 1.0
AUTHOR: Chris Arceneaux
GITHUB: https://github.com/carceneaux

.LINK
https://helpcenter.veeam.com/docs/vac/deployment/silent_install_agent.html?ver=9

.LINK
https://helpcenter.veeam.com/rn/vspc_9_release_notes.html#system-requirements-veeam-management-agents-windows-os

#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$Msi,
    [Parameter(Mandatory = $false)]
    [string]$LogFile = "VACAgentSetup.txt",
    [Parameter(Mandatory = $false)]
    [string]$InstallDir = "C:\Program Files\Veeam\Availability Console\",
    [Parameter(Mandatory = $false)]
    [string]$Tag
)

# Validate the tag length does not exceed 64 characters and only contains alphanumberic characters and underscores
if ($Tag) {
    if ($Tag.Length -gt 64) {
        Write-Error "Tag length exceeds 64 characters."
        exit 1
    }
    if ($Tag -notmatch '^[a-zA-Z0-9_-]+$') {
        Write-Error "Tag contains invalid characters. Only alphanumeric characters and underscores are allowed."
        exit 1
    }
    Write-Verbose "Tag is valid."
}

# Ensure the MSI file exists and resolve its full path
if (-not (Test-Path -Path $Msi -PathType Leaf)) {
    Write-Error "The specified MSI file does not exist: $Msi"
    exit 1
}
$Msi = (Resolve-Path -Path $Msi).Path
Write-Verbose "Using MSI file: $Msi"

# Define the arguments for msiexec
$msiArguments = @(
    '/L*v "{0}"' -f $LogFile
    "/qn"
    '/i "{0}"' -f $Msi
    'INSTALLDIR="{0}"' -f $InstallDir
    "ACCEPT_THIRDPARTY_LICENSES=1"
    "ACCEPT_LICENSING_POLICY=1"
    "ACCEPT_REQUIRED_SOFTWARE=1"
    "ACCEPT_EULA=1"
)

# Add the tag argument if provided
if ($Tag) {
    $msiArguments += "VAC_MANAGEMENT_AGENT_TAG_NAME={0}" -f $Tag
}
Write-Verbose "MSI Arguments: $msiArguments"

# Start the msiexec process
$exitCode = (Start-Process msiexec.exe -Wait -ArgumentList $msiArguments -Passthru).ExitCode

# Check the exit code for success or failure (0 indicates success)
if ($exitCode -ne 0) {
    Write-Error "MSI installation failed with exit code: $exitCode"
    Write-Error "Check log file for more detailed information: $logFile"
}
else {
    Write-Verbose "MSI installation completed successfully."
}

return $exitCode
