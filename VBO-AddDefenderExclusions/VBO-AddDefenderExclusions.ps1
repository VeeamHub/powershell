<#
.SYNOPSIS
    Add Windows Defender Exclusions for Veeam Backup for Microsoft Office 365
.DESCRIPTION
    Add path exclusions to the directories which are scanned by Windows Defender for VBO based on 
    https://www.veeam.com/kb3074.
    Does resolve the repository paths automatically and adds them, too.
.EXAMPLE
    PS C:\>VBO-AddDefenderExclusions.ps1
    Add exclusions on the local server
.INPUTS
    NONE
.OUTPUTS
    Print a list of excluded directories
.NOTES
    Written by Stefan Zimmermann <stefan.zimmermann@veeam.com>

    v1.0.0  27.04.2020    Initial version for local VBO management server and it's repos

    - Requires Veeam.Archiver.PowerShell module on the system.
    - Script can run multiple times as exclusions will be overwritten if they exist already.
#>
#requires -modules Veeam.Archiver.PowerShell

Import-Module Veeam.Archiver.PowerShell

$vbo_exclusions = @(
    "${env:ProgramFiles}\Veeam",
    "${env:ProgramFiles(x86)}\Veeam",
    "${env:ProgramFiles}\Common Files\Veeam",
    "${env:ProgramFiles(x86)}\Common Files\Veeam",
    "${env:windir}\Veeam",
    "${env:ProgramData}\Veeam"
)

$proxy_exclusions = @(
    "${env:windir}\Veeam",
    "${env:ProgramData}\Veeam"
)

$local_proxy = Get-VBOProxy -Hostname $env:COMPUTERNAME

# Add local repository paths to VBO exclusions
Get-VBORepository -Proxy $local_proxy | % { $vbo_exclusions += $_.Path }

# Add exclusions to local VBO instance

foreach ($exclusion in $vbo_exclusions) {
    try {
        Add-MpPreference -ExclusionPath $exclusion
        Write-Host -BackgroundColor DarkGreen "Excluding $exclusion"
    } catch {
        Write-Host -BackgroundColor Red "Error excluding $exclusion"
    }    
}

# TODO: Add exclusions on external proxy servers via remote PowerShell if possible
# $other_proxies = Get-VBOProxy | ? { $_.Hostname -ne $env:COMPUTERNAME }