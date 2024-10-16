#   ** Parameters **

# VMware PowerCLI variables
$vCenterServer = "<String:vCenterServer DNSName or IP>"
$vCenterServerCredsUsername = "<String: username>"
$vCenterServerCredsPassword = "<String: password>"

# Time, in minutes, to run GetVBOSession (will check for running jobs every 30 seconds for the duration specified)
$CheckTime = 4

# Time, in minutes, to check for additional sessions before ending
$BufferTime = 1

# Filepath for logging
$OutputFile = "<String: Path\to\log\file>"

# Name of proxy pool to be automated
$ProxyPoolName = "<String: Proxy pool name>"

<#
List of Proxy VM attributes used to manage proxy power and maintenance mode operations 
    ProxyVMName: 
        Name of the VM in Azure
    ProxyVMIPv4:
        The local IPv4 address of the proxy (potentially used to add proxy to VBO)
    ProxyMode:
        Set which proxy is to stay online ('Primary') and which are to be stopped after jobs complete ('Auto')
    ProxyBootTime:
        Sets the wait time (in seconds) after starting the VM for the guest OS to be up before sending proxy commands
    PoxyUserName:
        Windows- Start a local account username with "`.\" The period must be escaped with a back tick character. Domain account can use "domain\username" format.
        Linux - no domain needed
    ProxyUserPass:
        Password string
    ProxyRootPass:
        Root password string which may be required for Linux proxies.        
#>
$VBOAutomatedProxies = @(
    [PSCustomObject]@{
        ProxyVMName = "<String>";
        ProxyVMIPv4 = "<String>";
        ProxyMode = "Primay";
        ProxyOS = "<Windows/Linux>";
        ProxyBootTime = 120;
        ProxyUserName = '<String>';
        ProxyUserPass = '<String>';
        ProxyRootPass = '<String>'
    }
    [PSCustomObject]@{
        ProxyVMName = "<String>";
        ProxyVMIPv4 = "<String>";
        ProxyMode = "Auto";
        ProxyOS =  "<Windows/Linux>";
        ProxyBootTime = 120;
        ProxyUserName = '<String>';
        ProxyUserPass = '<String>';
        ProxyRootPass = '<String>'
    }
)

#   ** Functions **

# Functions to pass into background jobs
$InitializationScript = {
    function PreReqs {
        try{
            Import-Module VMware.VimAutomation.Sdk | Out-Null
            Import-Module VMware.VimAutomation.Common | Out-Null
            Import-Module VMware.VimAutomation.Cis.Core | Out-Null
            Import-Module VMware.VimAutomation.Core | Out-Null
        } catch {
            Write-Error "There was an error with the PowerCLI installation"
        } 
    }

    function ConnectVI ($Server, $Credential) {
        $Server = Connect-VIServer $Server -Credential $Credential
    }

    function GetPSCreds ($username, $password) {    
        $secpwd = ConvertTo-SecureString $password -AsPlainText $true
        return New-Object System.Management.Automation.PSCredential($userName, $secpwd)
    }

    function GetLinuxProxyCreds ($username, $password, $rootpass){
        $secpwd = ConvertTo-SecureString $password -AsPlainText $true
        $secrootpass = ConvertTo-SecureString $rootpass -AsPlainText $true
        New-VBOLinuxCredential -Account $username -Password $secpwd -ElevateAccountToRoot -RootPassword $secrootpass
    }

    function GetWindowsProxyCreds ($username, $password){    
        GetPSCreds -username $username -password $password
    }
}

# Check for running VBO job session(s)
function GetVBOSession ($minutes) {
    $count = 0
    $script:JobSessions = $null
    while ($count -lt ($minutes*2)) {
        $script:JobSessions = Get-VBOJobSession | Where-Object -FilterScript {$_.Status -eq 'Running'}
        if ($JobSessions.Count -gt 0) {
            $script:JobFound = $true
            break
        } 
        else {
            $count++
            Start-Sleep -Seconds 30
        }
    }
    if ($JobSessions.Count -eq 0) {
        $script:JobFound = $false
    }
}

# Monitor first identified job and wait for completion
function MonitorVBOSession ($session) {
    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`tStarting VBO job session monitor" | Out-File -FilePath $OutputFile -Append -Force
    $Status = 'Running'
    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t'$($session.JobName)' has the status of $Status" | Out-File -FilePath $OutputFile -Append -Force
    while ($Status -eq 'Running') {
        $Job = Get-VBOJob -Name "$($session.JobName)"
        $Status = (Get-VBOJobSession -Job $Job -Last).Status
        Start-Sleep -Seconds 10
    }
    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t'$($session.JobName)' has completed" | Out-File -FilePath $OutputFile -Append -Force

    # Run GetVBOSession again for 1 minute to verify all jobs are completed
    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`tRe-checking for running sessions" | Out-File -FilePath $OutputFile -Append -Force   
    GetVBOSession -minutes $BufferTime
}

# Check proxy state when no job was found. This is to help fix any potential errors or timeouts that may occur with background proxy jobs
function CheckVBOProxies ($ProxyPool) {
    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`tChecking proxy state"| Out-File -FilePath $OutputFile -Append -Force
    $CorrectState = $true
    # Loop through proxies checking for maintenance and power state.
    foreach ($ProxyName in $ProxyPool) {
        $proxyHostname = $ProxyName.Split(':').Trim()
        $proxy = Get-VBOProxy -Hostname $proxyHostname
        $ProxyVMName = $null
        $ProxyMode = $null
        foreach ($ProxyVM in $ProxyVMList) {
            if ($proxy.Hostname -eq $ProxyVM.ProxyVMIPv4) {
                $ProxyVMName = $ProxyVM.ProxyVMName
                $ProxyMode = $ProxyVM.ProxyMode
            } elseif ($proxy.Hostname -eq $ProxyVM.ProxyVMName) {
                $ProxyVMName = $ProxyVM.ProxyVMName
                $ProxyMode = $ProxyVM.ProxyMode
            }
        }
        if ($null -ne $ProxyVMName) {
            
            # Connect to vCenter PowerCLI
            Invoke-Expression -Command "$($InitializationScript)"
            PreReqs
            $VMwareCred = GetPSCreds -username $vCenterServerCredsUsername -password $vCenterServerCredsPassword
            Set-PowerCLIConfiguration -Scope User -ParticipateInCeip $false -Confirm:$false | Out-Null
            Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
            ConnectVI $vCenterServer $VMwareCred

            # Check 'Auto' proxies
            if ($ProxyMode -eq 'Auto') {

                # Check MaintenanceModeState
                if ($proxy.MaintenanceModeState -eq 'Disabled') {
                    $script:ProxiesRunning = $true
                } 
                
                # Check PowerState
                else {
                    $vm = Get-VM -Name $ProxyVMName
                    If ($vm.PowerState -eq 'PoweredOn') {
                        $script:ProxiesRunning = $true
                    }
                }
                $script:AutoProxies += $proxyHostname
            } 
            
            # Check 'Primary' proxy
            elseif ($ProxyMode -eq 'Primary') {

                # Check MaintenanceModeState
                if ($proxy.MaintenanceModeState -eq '*Ena*') {
                    $script:PrimaryOffline = $true
                } 
                # Check VBO Proxy State
                elseif ($proxy.State -eq 'Offline') {
                    $script:PrimaryOffline = $true
                } 
                # Check PowerState
                else {
                    $vm = Get-VM -Name $ProxyVMName
                    If ($vm.PowerState -eq 'PoweredOff') {
                        $script:PrimaryOffline = $true
                    }
                    
                }
                $script:PrimaryProxy += $proxyHostname
            }
        }
    }

    # Log the outcome of the proxy state check
    if ($ProxiesRunning) {
        "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tWarning`tAuto proxy state modification is required" | Out-File -FilePath $OutputFile -Append -Force  
        $CorrectState = $false 
    } 
    if ($PrimaryOffline) {
        "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tWarning`tPrimary proxy state modification is required" | Out-File -FilePath $OutputFile -Append -Force
        $CorrectState = $false
    }
    if ($CorrectState) {
        "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`tProxies are in the correct state" | Out-File -FilePath $OutputFile -Append -Force 
    }
}

# Start VBO proxies and disable maintenance mode
function StartVBOProxies ($ProxyPool) {
    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`tLaunching background jobs to check proxy state"| Out-File -FilePath $OutputFile -Append -Force

    # Loop through proxies checking for maintenance and power state. Modify where needed. 
    foreach ($ProxyName in $ProxyPool) {
        $proxyHostname = $ProxyName.Split(':').Trim()
        $proxy = Get-VBOProxy -Hostname $proxyHostname
        $ProxyVMName = $null

        # Match VBO Proxy to Proxy VM
        foreach ($ProxyVM in $VBOAutomatedProxies) {
            $match = $false
            if ($proxy.Hostname -eq $ProxyVM.ProxyVMIPv4) {
                $match = $true
            } elseif ($proxy.Hostname -eq $ProxyVM.ProxyVMName) {
                $match = $true
            }
            if ($match) {
                $ProxyVMName = $ProxyVM.ProxyVMName
                $ProxyMode = $ProxyVM.ProxyMode
                $ProxyOS = $ProxyVM.ProxyOS
                $ProxyBootTime = $ProxyVM.ProxyBootTime
                $ProxyUserName = $ProxyVM.ProxyUserName
                $ProxyUserPass = $ProxyVM.ProxyUserPass
                if (![string]::IsNullOrEmpty($ProxyVM.ProxyRootPass)) {
                    $ProxyRootPass = $ProxyVM.ProxyRootPass
                }
            }
        }
        if ($null -ne $ProxyVMName) {
            $ScriptBlock = {
                param(
                    $OutputFile,
                    $proxyHostname,
                    $ProxyVMName,
                    $ProxyUserName,
                    $ProxyUserPass,
                    $ProxyRootPass,
                    $ProxyOS,
                    $ProxyBootTime,
                    $vCenterServer,
                    $vCenterServerCredsUsername,
                    $vCenterServerCredsPassword
                )

                # Connect to vCenter PowerCLI
                try {
                    PreReqs
                    $VMwareCred = GetPSCreds -username $vCenterServerCredsUsername -password $vCenterServerCredsPassword
                    Set-PowerCLIConfiguration -Scope User -ParticipateInCeip $false -Confirm:$false | Out-Null
                    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
                    ConnectVI $vCenterServer $VMwareCred
                }
                catch {
                    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tError`t[ProxyJob ($($proxyHostname))] Connection to $($vCenterServer) failed" | Out-File -FilePath $OutputFile -Append -Force
                }

                # PowerON proxy
                $vm = Get-VM -Name $ProxyVMName
                If ($vm.PowerState -eq 'PoweredOff') {
                    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Starting $($vm.Name)" | Out-File -FilePath $OutputFile -Append -Force
                    try {
                        $VMstart = Start-VM -VM $vm
                        "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Start-VM command completed" | Out-File -FilePath $OutputFile -Append -Force
                    }
                    catch {
                        "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tError`t[ProxyJob ($($proxyHostname))] Start-VM command failed" | Out-File -FilePath $OutputFile -Append -Force
                    }
                    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Waiting for proxy guest OS ($($ProxyBootTime) seconds)" | Out-File -FilePath $OutputFile -Append -Force
                    Start-Sleep -Seconds $ProxyBootTime
                } 

                # Synchronize proxy
                 $proxy = Get-VBOProxy -Hostname $proxyHostname
                "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Synchronizing proxy" | Out-File -FilePath $OutputFile -Append -Force
                try {
                    $SyncProxy = Sync-VBOProxy -Proxy $proxy
                    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Synchronization completed" | Out-File -FilePath $OutputFile -Append -Force
                }
                catch {
                    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tError`t[ProxyJob ($($proxyHostname))] Synchronization error occurred" | Out-File -FilePath $OutputFile -Append -Force
                }

                 # Disable MaintenanceMode
                if ($proxy.MaintenanceModeState -like '*Enab*') {
                    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Disabling MaintenanceMode" | Out-File -FilePath $OutputFile -Append -Force
                    try {
                        if ($ProxyOS -eq "Linux"){
                            $ProxyCreds = GetLinuxProxyCreds -username $ProxyUserName -password $ProxyUserPass -rootpass $ProxyRootPass
                            $DisableMaintenanceMode = Set-VBOProxyMaintenance -Enable:$false -LinuxCredential $ProxyCreds -Proxy $proxy
                        } elseif ($ProxyOS -eq "Windows"){
                            $ProxyCreds = GetWindowsProxyCreds -username $ProxyUserName -password $ProxyUserPass
                            $DisableMaintenanceMode = Set-VBOProxyMaintenance -Enable:$false -WindowsCredential $ProxyCreds -Proxy $proxy
                        }
                        "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Disable MaintenanceMode command completed" | Out-File -FilePath $OutputFile -Append -Force
                    }
                    catch {
                        "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tError`t[ProxyJob ($($proxyHostname))] Disable MaintenanceMode command error occurred" | Out-File -FilePath $OutputFile -Append -Force
                    }
                }
            }

            # Start background job to run proxy tasks
            Start-Job -InitializationScript  $InitializationScript -Name $proxyHostname -ScriptBlock  $ScriptBlock -ArgumentList $OutputFile, $proxyHostname, $ProxyVMName, $ProxyUserName, $ProxyUserPass, $ProxyRootPass, $ProxyOS, $ProxyBootTime, $vCenterServer, $vCenterServerCredsUsername, $vCenterServerCredsPassword 
            if ($ProxyMode -eq 'Auto') {
                $script:ProxiesRunning = $true 
            }
        } 
    }
    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`tJobs to start proxies are running" | Out-File -FilePath $OutputFile -Append -Force
}

# Stop proxies set to 'Auto' and enable maintenance mode
function StopVBOProxies ($ProxyPool) {
    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`tLaunching background jobs to stop additional proxies"| Out-File -FilePath $OutputFile -Append -Force

    # Loop through proxies checking for maintenance and power state. Modify where needed. 
    foreach ($ProxyName in $ProxyPool) {
        $proxyHostname = $ProxyName.Split(':').Trim()
        $proxy = Get-VBOProxy -Hostname $proxyHostname
        $ProxyVMName = $null
        $ProxyMode = $null
        
        # Match VBO Proxy to Proxy VM
        foreach ($ProxyVM in $VBOAutomatedProxies) {
            $match = $false
            if ($proxy.Hostname -eq $ProxyVM.ProxyVMIPv4) {
                $match = $true
            } elseif ($proxy.Hostname -eq $ProxyVM.ProxyVMName) {
                $match = $true
            }
            if ($match) {
                $ProxyVMName = $ProxyVM.ProxyVMName
                $ProxyMode = $ProxyVM.ProxyMode
                $ProxyOS = $ProxyVM.ProxyOS
                $ProxyUserName = $ProxyVM.ProxyUserName
                $ProxyUserPass = $ProxyVM.ProxyUserPass
                if (![string]::IsNullOrEmpty($ProxyVM.ProxyRootPass)) {
                    $ProxyRootPass = $ProxyVM.ProxyRootPass
                }
            }
        }
        if ($null -ne $ProxyVMName) {
            if ($ProxyMode -ne 'Auto') {continue}

            # Script for background proxy jobs
            $ScriptBlock = {
                param(
                    $OutputFile,
                    $proxyHostname,
                    $ProxyVMName,
                    $ProxyUserName,
                    $ProxyUserPass,
                    $ProxyRootPass,
                    $ProxyOS,
                    $vCenterServer,
                    $vCenterServerCredsUsername,
                    $vCenterServerCredsPassword
                )

                # Connect to vCenter PowerCLI
                try {
                    PreReqs
                    $VMwareCred = GetPSCreds -username $vCenterServerCredsUsername -password $vCenterServerCredsPassword
                    Set-PowerCLIConfiguration -Scope User -ParticipateInCeip $false -Confirm:$false | Out-Null
                    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
                    ConnectVI $vCenterServer $VMwareCred
                }
                catch {
                    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tError`t[ProxyJob ($($proxyHostname))] Connection to $($vCenterServer) failed" | Out-File -FilePath $OutputFile -Append -Force
                }

                # Enable MaintenanceMode
                $proxy = Get-VBOProxy -Hostname $proxyHostname
                if ($proxy.MaintenanceModeState -eq 'Disabled') {

                    # If proxy is offline with disabled maintenance mode, attempt to start the proxy to modify
                    $vm = Get-VM -Name $ProxyVMName
                    If ($vm.PowerState -eq 'PoweredOff') {
                        "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tWarning`t[ProxyJob ($($proxyHostname))] Proxy offline. Attempting to start proxy to modify MaintnenanceMode" | Out-File -FilePath $OutputFile -Append -Force
                        "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Starting $($vm.Name)" | Out-File -FilePath $OutputFile -Append -Force
                        try {
                            $VMstart = Start-VM -VM $vm
                            "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Start-VM command completed" | Out-File -FilePath $OutputFile -Append -Force
                        }
                        catch {
                            "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tError`t[ProxyJob ($($proxyHostname))] Start-VM command failed" | Out-File -FilePath $OutputFile -Append -Force
                        }
                        Start-Sleep -Seconds 60 
                    }

                    # Synchronize the proxy
                        "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Synchronizing proxy" | Out-File -FilePath $OutputFile -Append -Force
                        try {
                            $SyncProxy = Sync-VBOProxy -Proxy $proxy
                            "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Synchronization completed" | Out-File -FilePath $OutputFile -Append -Force
                        }
                        catch {
                            "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tError`t[ProxyJob ($($proxyHostname))] Synchronization error occurred" | Out-File -FilePath $OutputFile -Append -Force
                        }
                
                    # Enable maintenance mode
                    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Enabling MaintenanceMode" | Out-File -FilePath $OutputFile -Append -Force
                    try {
                        if ($ProxyOS -eq "Linux"){
                            $ProxyCreds = GetLinuxProxyCreds -username $ProxyUserName -password $ProxyUserPass -rootpass $ProxyRootPass
                            $EnableMaintenanceMode = Set-VBOProxyMaintenance -Enable -LinuxCredential $ProxyCreds -Proxy $proxy
                        } elseif ($ProxyOS -eq "Windows"){
                            $ProxyCreds = GetWindowsProxyCreds -username $ProxyUserName -password $ProxyUserPass
                            $EnableMaintenanceMode = Set-VBOProxyMaintenance -Enable -WindowsCredential $ProxyCreds -Proxy $proxy
                        }
                        "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Enable MaintenanceMode command completed" | Out-File -FilePath $OutputFile -Append -Force
                    }
                    catch {
                        "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tError`t[ProxyJob ($($proxyHostname))] Enable MaintenanceMode command error occurred" | Out-File -FilePath $OutputFile -Append -Force
                    }
                }

                # PowerOFF proxy
                $vm = Get-VM -Name $ProxyVMName
                If ($vm.PowerState -eq 'PoweredOn') {
                    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Stopping $($vm.Name)" | Out-File -FilePath $OutputFile -Append -Force
                    try {
                        $VMStop= Stop-VM -VM $vm -Confirm:$false
                        "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`t[ProxyJob ($($proxyHostname))] Stop-VM command completed" | Out-File -FilePath $OutputFile -Append -Force
                    }
                    catch {
                        "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tError`t[ProxyJob ($($proxyHostname))] Stop-VM command error occurred" | Out-File -FilePath $OutputFile -Append -Force
                    }
                }
            }

            # Start background job to run proxy tasks
            Start-Job -InitializationScript  $InitializationScript -Name $proxyHostname -ScriptBlock  $ScriptBlock -ArgumentList $OutputFile, $proxyHostname, $ProxyVMName, $ProxyUserName, $ProxyUserPass, $ProxyRootPass, $ProxyOS, $vCenterServer, $vCenterServerCredsUsername, $vCenterServerCredsPassword   
        }
    }
    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`tJobs to stop proxies are running" | Out-File -FilePath $OutputFile -Append -Force   
}

#   ** BEGIN Script Execution **

# Initialize script-scope variables
[bool]$JobFound = $false
[bool]$PrimaryOffline = $false
[bool]$ProxiesRunning = $false
$JobSessions = $null
$ProxyPool = @()
foreach ($proxy in (Get-VBOProxyPool -Name $ProxyPoolName).Proxies) {
    $ProxyPool += $proxy.Hostname        
}

"[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`tChecking for running VBO Job Sessions - CheckTime=$($CheckTime), BufferTime=$($BufferTime), ProxyPoolName=$($ProxyPoolName)" | Out-File -FilePath $OutputFile -Append -Force

# Check for running job sessions for specified duration
GetVBOSession -minutes $CheckTime 

# If session found, start proxies and monitor session. Else, verify that proxy state is in maintenance mode and offline
if ($JobFound) {
    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`tLocated running session" | Out-File -FilePath $OutputFile -Append -Force
    if (!$ProxiesRunning){
            StartVBOProxies -ProxyPool $ProxyPool
    }
    Do {
        MonitorVBOSession -session $JobSessions[0]
    } while ($JobFound)
} 

if (!$JobFound -and !$ProxiesRunning) {
    "[$((Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString())]`tInfo`tNo running VBO Job Session(s) found" | Out-File -FilePath $OutputFile -Append -Force
    $PrimaryProxy = @()
    $AutoProxies = @()
    CheckVBOProxies -ProxyPool $ProxyPool

    # If 'Primary' proxy is offline or needs maintenance mode disabled, run StartVBOProxies just for the Primary 
    if ($PrimaryOffline) {
        if ($PrimaryProxy.Count -gt 0) {
            StartVBOProxies -ProxyPool $PrimaryProxy
        }
    }
}

# If proxies are running, enable maintenance mode and poweroff
if ($ProxiesRunning) {
    if ($AutoProxies.Count -gt 0) {
        StopVBOProxies -ProxyPool $AutoProxies
    } else {
        StopVBOProxies -ProxyPool $ProxyPool
    }
}

# Wait for background proxy jobs. timeout set to CheckTime in seconds
Get-Job | Wait-Job -Timeout ($CheckTime * 60)
