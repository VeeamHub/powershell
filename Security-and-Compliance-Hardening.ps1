# Veeam Security & Compliance Analyzer enforcement script
# This script can report current status and enforce recommended security settings on backup server
# This script should be ran locally on backup server
# Version 1.1 12/14/2023

# Making sure Veeam PowerCLI is working
Write-Output "Importing VBR Powershell module..."
$path = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
$env:PSModulePath +="$([System.IO.Path]::PathSeparator)$path"
$veeamPSModule = Get-Module -ListAvailable | Where-Object{$_.Name -match "Veeam.Backup.PowerShell"}
Import-Module $veeamPSModule.Path -DisableNameChecking

# This function collects current status and prints out a compliance report
function Get-VBRComplianceReport
{
    Write-host "Initiating Analyzer and collecting compliance status..."

    # Checking Veeam Backup Service status
    if ((Get-Service VeeamBackupSvc -ErrorAction SilentlyContinue).Status -ne "Running") {Write-Host "Veeam Backup Service is not running. Check service status and try again."; break}

    # Trigger S&CA session
    Start-VBRSecurityComplianceAnalyzer
    Start-Sleep 10
   
    # Collect results into array
    $AnalyzerResult = ([Veeam.Backup.DBManager.CDBManager]::Instance.BestPractices.GetAll())
    $Recommendations = @()
    $Recommendations = @(
        [Ordered]@{ 
            Id = 1
            Name = "Remote Desktop Services (TermService) should be disabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "RemoteDesktopServiceDisabled"}).Status
            Remediation = "Script"
        }
        [Ordered]@{ 
            Id = 2
            Name = "Remote Registry service (RemoteRegistry) should be disabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "RemoteRegistryDisabled"}).Status
            Remediation = "Script"
        }
        [Ordered]@{ 
            Id = 3
            Name = "Windows Remote Management (WinRM) service should be disabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "WinRmServiceDisabled"}).Status
            Remediation = "Script"
        }
        [Ordered]@{ 
            Id = 4
            Name = "Windows Firewall should be enabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "WindowsFirewallEnabled"}).Status
            Remediation = "Script"
        }
        [Ordered]@{ 
            Id = 5
            Name = "WDigest credentials caching should be disabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "WDigestNotStorePasswordsInMemory"}).Status
            Remediation = "Script"
        }
        [Ordered]@{ 
            Id = 6
            Name = "Web Proxy Auto-Discovery service (WinHttpAutoProxySvc) should be disabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "WebProxyAutoDiscoveryDisabled"}).Status
            Remediation = "Script"
        }
        [Ordered]@{ 
            Id = 7
            Name = "Deprecated versions of SSL and TLS should be disabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "OutdatedSslAndTlsDisabled"}).Status
            Remediation = "Script"
        }
        [Ordered]@{ 
            Id = 8
            Name = "Windows Script Host should be disabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "WindowsScriptHostDisabled"}).Status
            Remediation = "Script"
        }
        [Ordered]@{
            Id = 9
            Name = "SMBv1 protocol should be disabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "SMB1ProtocolDisabled"}).Status
            Remediation = "Script"
        }
        [Ordered]@{ 
            Id = 10
            Name = "Link-Local Multicast Name Resolution (LLMNR) should be disabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "LLMNRDisabled"}).Status
            Remediation = "Script"
        }
        [Ordered]@{ 
            Id = 11
            Name = "SMBv3 signing and encryption should be enabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "CSmbSigningAndEncryptionEnabled"}).Status
            Remediation = "Script"
        }
        [Ordered]@{ 
            Id = 12
            Name = "MFA for the backup console should be enabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "MfaEnabledInBackupConsole"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 13
            Name = "Immutable or offline (air gapped) media should be used"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "ImmutableOrOfflineMediaPresence"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 14
            Name = "Password loss protection should be enabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "LossProtectionEnabled"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 15
            Name = "Backup server should not be a part of the production domain"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "BackupServerInProductionDomain"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 16
            Name = "Email notifications should be enabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "EmailNotificationsEnabled"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 17
            Name = "All backups should have at least one copy (the 3-2-1 backup rule)"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "ContainBackupCopies"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 18
            Name = "Reverse incremental backup mode is deprecated and should be avoided"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "ReverseIncrementalInUse"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 19
            Name = "Unknown Linux servers should not be trusted automatically"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "ManualLinuxHostAuthentication"}).Status
            Remediation = "Script"
        }
        [Ordered]@{ 
            Id = 20
            Name = "The configuration backup must not be stored on the backup server"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "ConfigurationBackupRepositoryNotLocal"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 21
            Name = "Host to proxy traffic encryption should be enabled for the Network transport mode"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "ViProxyTrafficEncrypted"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 22
            Name = "Hardened repositories should not be hosted in virtual machines"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "HardenedRepositoryNotVirtual"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 23
            Name = "Network traffic encryption should be enabled in the backup network"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "TrafficEncryptionEnabled"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 24
            Name = "Linux servers should have password-based authentication disabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "LinuxServersUsingSSHKeys"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 25
            Name = "Backup services should be running under the LocalSystem account"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "BackupServicesUnderLocalSystem"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 26
            Name = "Configuration backup should be enabled and use encryption"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "ConfigurationBackupEnabledAndEncrypted"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 27
            Name = "Credentials and encryption passwords should be rotated at least annually"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "PasswordsRotation"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 28
            Name = "Hardened repositories should have the SSH Server disabled"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "HardenedRepositorySshDisabled"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 29
            Name = "S3 Object Lock in the Governance mode does not provide true immutability"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "OsBucketsInComplianceMode"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 30
            Name = "Backup jobs to cloud repositories should use encryption"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "JobsTargetingCloudRepositoriesEncrypted"}).Status
            Remediation = "Manual"
        }
        [Ordered]@{ 
            Id = 31
            Name = "Latest product updates should be installed"
            Status = ($AnalyzerResult | Where-Object {$_.Type -eq "BackupServerUpToDate"}).Status
            Remediation = "Manual"
        }
    ) 

    # Formatting and better structure for future updates
    $Summary = $Recommendations | ForEach-Object {
        if ($_.Id -lt 10) { $CleanID = "0"+$_.Id } else { $CleanID = $_.Id }
        [PSCustomObject]@{
            Id = $CleanID
            Name = $_.Name
            Status = $_.Status
            Remediation = $_.Remediation
        } 
    }

    # Print out current status report
    Clear-Host
    Write-Host "Report:" -ForegroundColor Green
    Write-Host ""
    foreach ($Recommendation in $Summary)
    {
        switch ($Recommendation.Status)
        {
            "UnableToCheck"
                { Write-Host $Recommendation.Id "-" $Recommendation.Name ": " -NoNewline; Write-Host "Unable to detect" -ForegroundColor Yellow }
            {$Recommendation.Status -eq "Ok"}
                { Write-Host $Recommendation.Id "-" $Recommendation.Name ": " -NoNewline; Write-Host "Passed" -ForegroundColor Green }
            "Suppressed"
                { Write-Host $Recommendation.Id "-" $Recommendation.Name ": " -NoNewline; Write-Host "Suppressed" -ForegroundColor DarkGray }
            default
                { Write-Host $Recommendation.Id "-" $Recommendation.Name ": " -NoNewline; if($Recommendation.Remediation -eq "Script") {Write-Host "Not implemented" -ForegroundColor Red -NoNewline; Write-Host " (Use 'Apply configurations' option to fix)" -ForegroundColor Yellow} else {Write-Host "Not implemented" -ForegroundColor Red;} }
        }
    }
    return $Summary
}

# This function sets defined practice ID configuration on a server into a recommended state
function Set-VBRComplianceRecommendations($id)
{
    switch ([int]$id){
        1 {
            Write-host "Disabling Remote Desktop Services (TermService)..." -NoNewline
            Try {
                # This action locks server from RDP access!
                Set-Service "TermService" -StartupType "Disabled" -ErrorAction SilentlyContinue    
                Write-host "OK (Reboot required)" -ForegroundColor Green
            } 
            Catch {Write-host "Failed" -ForegroundColor Red}
        }
        2 {
            Write-host "Disabling Remote Registry service (RemoteRegistry)..." -NoNewline
            Try {
                Stop-Service "RemoteRegistry" -Force -ErrorAction SilentlyContinue
                Set-Service "RemoteRegistry" -StartupType "Disabled" -ErrorAction SilentlyContinue
                Write-host "OK" -ForegroundColor Green
            } 
            Catch {Write-host "Failed" -ForegroundColor Red}
        }
        3 {
            Write-host "Disabling Windows Remote Management (WinRM) service..." -NoNewline
            Try {
                Set-Service "WinRM" -StartupType "Disabled" -ErrorAction SilentlyContinue
                Write-host "OK" -ForegroundColor Green
            } 
            Catch {Write-host "Failed" -ForegroundColor Red}
        }
        4 {
            Write-host "Enabling Windows Firewall..." -NoNewline
            Try {
                Set-NetFirewallProfile -All -Enabled "True" -ErrorAction SilentlyContinue
                Write-host "OK" -ForegroundColor Green
            } 
            Catch {Write-host "Failed" -ForegroundColor Red}
        }
        5 {
            Write-host "Disabling WDigest credentials caching..." -NoNewline
            Try {
                Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name "UseLogonCredential" -ErrorAction Ignore
                Write-host "OK" -ForegroundColor Green
            } 
            Catch {Write-host "Failed" -ForegroundColor Red}
        }
        6 {
            Write-host "Disabling Web Proxy Auto-Discovery service (WinHttpAutoProxySvc)..." -NoNewline
            Try {
                Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\WinHttpAutoProxySvc -Name Start -Value 4
                Write-host "OK" -ForegroundColor Green
                
            } 
            Catch {Write-host "Failed" -ForegroundColor Red}
        }
        7 {
            Write-host "Disabling deprecated versions of SSL and TLS..." -NoNewline
            Try {
                # Write-host "SSL 2.0"
                New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server' -name 'Enabled' -value '0' -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server' -name 'DisabledByDefault' -value 1 -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
                New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client' -Force | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client' -name 'Enabled' -value '0' -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client' -name 'DisabledByDefault' -value 1 -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
            
                # Write-host "SSL 3.0"
                New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server' -name 'Enabled' -value '0' -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server' -name 'DisabledByDefault' -value 1 -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue| Out-Null
                New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client' -name 'Enabled' -value '0' -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client' -name 'DisabledByDefault' -value 1 -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
            
                # Write-host "TLS 1.0"
                New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -Force -ErrorAction SilentlyContinue | Out-Null
                New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -name 'Enabled' -value '0' -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -name 'DisabledByDefault' -value 1 -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
                New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client' -name 'Enabled' -value '0' -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client' -name 'DisabledByDefault' -value 1 -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
            
                # Write-host "TLS 1.1"
                New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server' -name 'Enabled' -value '0' -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server' -name 'DisabledByDefault' -value 1 -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
                New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client' -name 'Enabled' -value '0' -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client' -name 'DisabledByDefault' -value 1 -PropertyType 'DWORD' -Force -ErrorAction SilentlyContinue | Out-Null
                
                Write-host "OK (Reboot required)" -ForegroundColor Green
            } 
            Catch {Write-host "Failed" -ForegroundColor Red}
        }
        8 {
            Write-host "Disabling Windows Script Host..." -NoNewline
            Try {
                New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings" -Name "Enabled" -PropertyType "DWORD" -Value "0" -Force -ErrorAction SilentlyContinue | Out-Null
                Write-host "OK" -ForegroundColor Green
            } 
            Catch {Write-host "Failed" -ForegroundColor Red}
        }
        9 {
            Write-host "Disabling SMBv1 protocol..." -NoNewline
            Try {

                Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue | Out-Null
                Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart -ErrorAction SilentlyContinue | Out-Null 
                Write-host "OK" -ForegroundColor Green
            } 
            Catch {Write-host "Failed" -ForegroundColor Red}
            
        }
        10 {
            Write-host "Disabling Link-Local Multicast Name Resolution (LLMNR)..." -NoNewline
            Try {
                New-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT" -Name "DNSClient" -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMultiCast" -Value "0" -PropertyType "DWORD" -Force -ErrorAction SilentlyContinue | Out-Null
                Write-host "OK" -ForegroundColor Green
            } 
            Catch {Write-host "Failed" -ForegroundColor Red}
        }
        11 {
            Write-host "Enabling SMBv3 signing and encryption..." -NoNewline
            Try {
                Set-SmbServerConfiguration -EncryptData $true -Force -ErrorAction SilentlyContinue
                Set-SmbServerConfiguration -EnableSecuritySignature $true -Force -ErrorAction SilentlyContinue
                Set-SmbServerConfiguration -RequireSecuritySignature $true -Force -ErrorAction SilentlyContinue
                Write-host "OK" -ForegroundColor Green
            } 
            Catch {Write-host "Failed" -ForegroundColor Red}
        }
        19 {
            Write-host "Setting unknown Linux servers trust settings..." -NoNewline
            Try {
                Set-VBRLinuxTrustedHostPolicy -Type "KnownHosts"
                Write-host "OK" -ForegroundColor Green
            } 
            Catch {Write-host "Failed" -ForegroundColor Red}
        }
        21 {
            Write-host "Setting host to proxy traffic encryption in Network transport mode..." -NoNewline
            Try {
                Get-VBRViProxy | Where-Object {$_.UseSSL -ne $True} | Set-VBRViProxy -EnableHostToProxyEncryption -ErrorAction SilentlyContinue
                Write-host "OK" -ForegroundColor Green
            } 
            Catch {Write-host "Failed" -ForegroundColor Red}
        }
        default {Write-host "Unknown recommendation ID"}
    }
}

# This function draws main menu
function Get-VeeamMenu
{
    Write-host ""
    Write-host "Available actions:" -ForegroundColor Green
    Write-host ""
    Write-host "1  : Refresh compliance report"
    if ($RemediationCount -gt 0) {Write-host "2  : Apply ALL recommended configurations " -NoNewline; Write-host "(total:$RemediationCount)" -ForegroundColor Yellow } else {Write-host "2  : Apply all recommended security & compliance configurations"}
    Write-host "3  : Apply selected configuration only..."
    Write-host "0  : Exit"
    Write-host ""
}

# Trigger execution
Clear-Host
$Report = Get-VBRComplianceReport
do 
{
    # Things we can fix with the script
    $RemediationActions = $Report | Where-Object {$_.Remediation -eq "Script" -and $_.Status -eq "Violation"}
    $RemediationCount = ($RemediationActions | Measure-Object).count

    Get-VeeamMenu
    $choice = Read-host "Select action to perform"
    Write-host ""

    # Menu action list
    switch ($choice)
    {
        0 { break }
        1 { $Report = Get-VBRComplianceReport }
        2 { foreach ($Action in $RemediationActions) {Set-VBRComplianceRecommendations $Action.ID} }
        3 { $ActionID = Read-Host "Enter recommendation ID"; if ($Remediationactions.id -contains $ActionID) {Set-VBRComplianceRecommendations $ActionID} else { Write-host "Selected configuration ID does not need to be applied." -ForegroundColor Red } }
        default { Write-host "Error: select correct action." -ForegroundColor Red}
    }
} until ($choice -eq 0)
