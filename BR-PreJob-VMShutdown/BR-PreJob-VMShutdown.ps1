# Adam Congdon, 20260312

<#
.SYNOPSIS
    Veeam pre-job script: gracefully shuts down all VMs in a backup job before it runs.

.DESCRIPTION
    Designed for machines with the Veeam Backup & Replication Console (not the full
    VBR server). Connects to VBR via public PowerShell cmdlets (Connect-VBRServer),
    enumerates all VMs in the specified job using Get-VBRJob / Get-VBRJobObject,
    then uses VMware PowerCLI to issue guest shutdown (Shutdown-VMGuest) for each
    powered-on VM and waits for power-off confirmation before exiting.

    When connecting to auto-discovered vCenter servers (via Veeam), the script looks for
    exported PSCredential XML files in a "creds" subfolder next to the script, named
    <vCenterHostname>.xml (e.g. creds\vcsa.lab.local.xml). Create these once per vCenter:

        Get-Credential | Export-Clixml "C:\Scripts\BR-PreJob-VMShutdown\creds\vcsa.lab.local.xml"

    Run as the same user account that executes the backup job (DPAPI-encrypted, user+machine bound).
    If no matching credential file is found, the script falls back to Windows SSO.
    You may also pass -vCenterServer and -vCenterCredential explicitly instead.

    If VMware Tools is not installed or not running on a VM, graceful shutdown is
    impossible. Use -ForceShutdown to hard-power-off those VMs, or they will be
    skipped with a warning (job will still proceed).

    Exit code 0  = all targeted VMs powered off; job may proceed.
    Exit code 1  = one or more VMs failed to power off; job is blocked.

.PARAMETER JobName
    Name of the Veeam backup job to enumerate VMs from.

.PARAMETER VBRServer
    Hostname or IP of the Veeam Backup & Replication server to connect to.
    Default: 'localhost'.

.PARAMETER ForceShutdown
    When set, VMs where VMware Tools is not installed or not running will be
    hard-powered-off via Stop-VM instead of being skipped.

.PARAMETER ShutdownTimeoutSeconds
    How long (in seconds) to wait for each VM to reach PoweredOff state after
    issuing the shutdown command. Default: 300 (5 minutes).

.PARAMETER vCenterServer
    Optional. vCenter hostname or IP to connect to. If omitted, the script uses
    all vCenter servers registered in Veeam Backup & Replication.

.PARAMETER vCenterCredential
    Optional. PSCredential for vCenter. If omitted, uses Veeam-managed credentials.

.EXAMPLE
    # Configured in Veeam job Advanced Settings > Scripts:
    # Pre-job script: pwsh.exe -NonInteractive -ExecutionPolicy Bypass -File
    #   "C:\Scripts\BR-PreJob-VMShutdown\BR-PreJob-VMShutdown.ps1" -JobName "My Backup Job"

.EXAMPLE
    # Connecting to a remote VBR server with force shutdown:
    # pwsh.exe -NonInteractive -ExecutionPolicy Bypass -File
    #   "C:\Scripts\BR-PreJob-VMShutdown\BR-PreJob-VMShutdown.ps1"
    #   -JobName "My Backup Job" -VBRServer "vbr.lab.local" -ForceShutdown
#>

Param(
    [Parameter(Mandatory = $true)][string]  $JobName,
    [string]                                $VBRServer = 'localhost',
    [switch]                                $ForceShutdown,
    [int]                                   $ShutdownTimeoutSeconds = 300,
    [string]                                $vCenterServer,
    [PSCredential]                          $vCenterCredential
)

$Version = "2.0.0"
$ScriptName = $MyInvocation.MyCommand.Name
$ExitCode = 0

#region --- Logging helper ---

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts][$Level] $Message"
}

#endregion

#region --- Module imports ---

Write-Log ("="*78)
Write-Log "Script    : $ScriptName v$Version"
Write-Log "JobName   : $JobName"
Write-Log "VBRServer : $VBRServer"
Write-Log "Force     : $ForceShutdown"
Write-Log "Timeout   : ${ShutdownTimeoutSeconds}s"
Write-Log ("="*78)

Write-Log "Importing Veeam.Backup.PowerShell..."
try {
    Import-Module Veeam.Backup.PowerShell -ErrorAction Stop
} catch {
    Write-Log "FATAL: Failed to import Veeam.Backup.PowerShell: $_" -Level "ERROR"
    exit 1
}

Write-Log "Importing VMware PowerCLI..."
try {
    # Strip OneDrive paths from PSModulePath so module resolution only finds system-wide
    # installations. This prevents "cloud file denied" errors when VMware modules were
    # originally installed to a OneDrive-backed user profile folder.
    $env:PSModulePath = ($env:PSModulePath -split [IO.Path]::PathSeparator |
        Where-Object { $_ -notmatch 'OneDrive' }) -join [IO.Path]::PathSeparator

    # Import VMware.VimAutomation.Core rather than the VMware.PowerCLI meta-module.
    # The meta-module pulls legacy Sdk.Types version dependencies which may only exist
    # in OneDrive. VimAutomation.Core provides all cmdlets this script requires.
    Import-Module VMware.VimAutomation.Core -ErrorAction Stop
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -ParticipateInCEIP $false -Confirm:$false | Out-Null
} catch {
    Write-Log "FATAL: Failed to import VMware.PowerCLI: $_" -Level "ERROR"
    exit 1
}

#endregion

#region --- VBR connection ---

Write-Log "Connecting to VBR server '$VBRServer'..."
try {
    Connect-VBRServer -Server $VBRServer -ErrorAction Stop
    Write-Log "Connected to VBR server: $VBRServer"
} catch {
    Write-Log "FATAL: Could not connect to VBR server '$VBRServer': $_" -Level "ERROR"
    exit 1
}

#endregion

#region --- Veeam job lookup ---

Write-Log "Resolving Veeam job '$JobName'..."

$job = Get-VBRJob -Name $JobName
if ($null -eq $job) {
    Write-Log "FATAL: Job '$JobName' not found." -Level "ERROR"
    Disconnect-VBRServer -ErrorAction SilentlyContinue
    exit 1
}

Write-Log "Attached to job: $($job.Name)"

#endregion

#region --- vCenter connections ---

Write-Log "Connecting to vCenter server(s)..."

$connectedVCs = @()

if ($vCenterServer) {
    # Explicit vCenter provided
    try {
        if ($vCenterCredential) {
            $conn = Connect-VIServer -Server $vCenterServer -Credential $vCenterCredential -Force -ErrorAction Stop
        } else {
            $conn = Connect-VIServer -Server $vCenterServer -Force -ErrorAction Stop
        }
        $connectedVCs += $conn
        Write-Log "Connected to vCenter: $vCenterServer"
    } catch {
        Write-Log "FATAL: Could not connect to vCenter '$vCenterServer': $_" -Level "ERROR"
        Disconnect-VBRServer -ErrorAction SilentlyContinue
        exit 1
    }
} else {
    # Use all vCenter servers registered in Veeam
    $vbrVCServers = Get-VBRServer -Type VC
    if ($vbrVCServers.Count -eq 0) {
        Write-Log "FATAL: No vCenter servers found in VBR. Use -vCenterServer to specify one." -Level "ERROR"
        Disconnect-VBRServer -ErrorAction SilentlyContinue
        exit 1
    }
    $credsDir = Join-Path $PSScriptRoot "creds"
    foreach ($vc in $vbrVCServers) {
        try {
            $credFile = Join-Path $credsDir "$($vc.Name).xml"
            if (Test-Path $credFile) {
                $psCred = Import-Clixml -Path $credFile
                Write-Log "Using stored credential ($($psCred.UserName)) from '$credFile'"
                $conn = Connect-VIServer -Server $vc.Name -Credential $psCred -Force -ErrorAction Stop
            } else {
                Write-Log "No credential file found at '$credFile' - falling back to Windows SSO"
                $conn = Connect-VIServer -Server $vc.Name -Force -ErrorAction Stop
            }
            $connectedVCs += $conn
            Write-Log "Connected to vCenter: $($vc.Name)"
        } catch {
            Write-Log "WARNING: Could not connect to vCenter '$($vc.Name)': $_" -Level "WARN"
        }
    }
    if ($connectedVCs.Count -eq 0) {
        Write-Log "FATAL: Could not connect to any vCenter server." -Level "ERROR"
        Disconnect-VBRServer -ErrorAction SilentlyContinue
        exit 1
    }
}

#endregion

#region --- VM enumeration ---

Write-Log "Enumerating VMs in job '$($job.Name)'..."

$jobObjects = Get-VBRJobObject -Job $job
$targetVMs = [System.Collections.Generic.List[object]]::new()
$resolvedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($obj in $jobObjects) {
    $objName = $obj.Object.Name
    $objType = $obj.Object.Type.ToString()

    Write-Log "  Job object: '$objName' (Type: $objType)"

    switch ($objType) {

        "VM" {
            $viObj = Get-VM -Name $objName -ErrorAction SilentlyContinue
            if ($viObj) {
                foreach ($vm in $viObj) {
                    if ($resolvedNames.Add($vm.Name)) {
                        $targetVMs.Add($vm)
                        Write-Log "    -> VM (direct): $($vm.Name)"
                    }
                }
            } else {
                Write-Log "    -> WARNING: VM '$objName' not found in vCenter." -Level "WARN"
            }
        }

        { $_ -in "Folder", "Directory" } {
            $folder = Get-Folder -Name $objName -ErrorAction SilentlyContinue
            if ($folder) {
                $vms = Get-VM -Location $folder -ErrorAction SilentlyContinue
                foreach ($vm in $vms) {
                    if ($resolvedNames.Add($vm.Name)) {
                        $targetVMs.Add($vm)
                        Write-Log "    -> VM (from folder '$objName'): $($vm.Name)"
                    }
                }
            } else {
                Write-Log "    -> WARNING: Folder '$objName' not found in vCenter." -Level "WARN"
            }
        }

        "ResourcePool" {
            $rp = Get-ResourcePool -Name $objName -ErrorAction SilentlyContinue
            if ($rp) {
                $vms = Get-VM -Location $rp -ErrorAction SilentlyContinue
                foreach ($vm in $vms) {
                    if ($resolvedNames.Add($vm.Name)) {
                        $targetVMs.Add($vm)
                        Write-Log "    -> VM (from resource pool '$objName'): $($vm.Name)"
                    }
                }
            } else {
                Write-Log "    -> WARNING: Resource pool '$objName' not found in vCenter." -Level "WARN"
            }
        }

        "VApp" {
            $vapp = Get-VApp -Name $objName -ErrorAction SilentlyContinue
            if ($vapp) {
                $vms = Get-VM -Location $vapp -ErrorAction SilentlyContinue
                foreach ($vm in $vms) {
                    if ($resolvedNames.Add($vm.Name)) {
                        $targetVMs.Add($vm)
                        Write-Log "    -> VM (from vApp '$objName'): $($vm.Name)"
                    }
                }
            } else {
                Write-Log "    -> WARNING: vApp '$objName' not found in vCenter." -Level "WARN"
            }
        }

        "Tag" {
            $tag = Get-Tag -Name $objName -ErrorAction SilentlyContinue
            if ($tag) {
                $vms = Get-VM -Tag $tag -ErrorAction SilentlyContinue
                foreach ($vm in $vms) {
                    if ($resolvedNames.Add($vm.Name)) {
                        $targetVMs.Add($vm)
                        Write-Log "    -> VM (from tag '$objName'): $($vm.Name)"
                    }
                }
            } else {
                Write-Log "    -> WARNING: Tag '$objName' not found in vCenter." -Level "WARN"
            }
        }

        default {
            Write-Log "    -> Unhandled object type '$objType' for '$objName' - skipping." -Level "WARN"
        }
    }
}

if ($targetVMs.Count -eq 0) {
    Write-Log "No VMs to shut down. Exiting with success."
    Disconnect-VBRServer -ErrorAction SilentlyContinue
    exit 0
}

Write-Log "Total VMs targeted for shutdown: $($targetVMs.Count)"

#endregion

#region --- Shutdown logic ---

$failedVMs = [System.Collections.Generic.List[string]]::new()

foreach ($vm in $targetVMs) {
    $vmName = $vm.Name
    Write-Log ("-"*60)

    # Refresh VM state (Select-Object -First 1 guards against duplicate names across vCenters)
    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $vm) {
        Write-Log "[$vmName] WARNING: VM not found in vCenter - skipping." -Level "WARN"
        continue
    }

    $powerState = $vm.PowerState

    # Already off - skip
    if ($powerState -eq "PoweredOff") {
        Write-Log "[$vmName] Already powered off - skipping."
        continue
    }

    # Check VMware Tools status
    $toolsStatus = $vm.ExtensionData.Guest.ToolsStatus
    $toolsRunning = ($toolsStatus -eq "toolsOk") -or ($toolsStatus -eq "toolsOld")

    Write-Log "[$vmName] Power: $powerState | Tools: $toolsStatus"

    if ($toolsRunning) {
        # Graceful guest shutdown
        Write-Log "[$vmName] Issuing graceful guest shutdown..."
        try {
            Shutdown-VMGuest -VM $vm -Confirm:$false -ErrorAction Stop | Out-Null
        } catch {
            Write-Log "[$vmName] ERROR: Shutdown-VMGuest failed: $_" -Level "ERROR"
            $failedVMs.Add($vmName)
            continue
        }
    } else {
        # Tools not available
        if ($ForceShutdown) {
            Write-Log "[$vmName] VMware Tools not available (status: $toolsStatus). Forcing hard power-off (-ForceShutdown set)." -Level "WARN"
            try {
                Stop-VM -VM $vm -Confirm:$false -ErrorAction Stop | Out-Null
            } catch {
                Write-Log "[$vmName] ERROR: Stop-VM failed: $_" -Level "ERROR"
                $failedVMs.Add($vmName)
                continue
            }
        } else {
            Write-Log "[$vmName] VMware Tools not available (status: $toolsStatus). Skipping - use -ForceShutdown to hard-power-off." -Level "WARN"
            continue
        }
    }

    # Wait for power-off
    Write-Log "[$vmName] Waiting up to ${ShutdownTimeoutSeconds}s for power-off..."
    $elapsed = 0
    $pollInterval = 5
    $poweredOff = $false

    while ($elapsed -lt $ShutdownTimeoutSeconds) {
        Start-Sleep -Seconds $pollInterval
        $elapsed += $pollInterval
        $currentState = (Get-VM -Name $vmName -ErrorAction SilentlyContinue | Select-Object -First 1).PowerState
        if ($currentState -eq "PoweredOff") {
            $poweredOff = $true
            break
        }
        Write-Log "[$vmName] Still $currentState after ${elapsed}s..."
    }

    if ($poweredOff) {
        Write-Log "[$vmName] Powered off successfully after ${elapsed}s."
    } else {
        Write-Log "[$vmName] ERROR: Did not power off within ${ShutdownTimeoutSeconds}s." -Level "ERROR"
        $failedVMs.Add($vmName)
        $ExitCode = 1
    }
}

#endregion

#region --- Disconnect and exit ---

Write-Log ("="*78)
foreach ($vc in $connectedVCs) {
    Disconnect-VIServer -Server $vc -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}
Disconnect-VBRServer -ErrorAction SilentlyContinue

if ($failedVMs.Count -gt 0) {
    $failList = $failedVMs -join ", "
    Write-Log "FAILED VMs ($($failedVMs.Count)): $failList" -Level "ERROR"
    Write-Log "Exiting with code 1 - backup job will be blocked."
    exit 1
} else {
    Write-Log "All targeted VMs powered off successfully."
    Write-Log "Exiting with code 0 - backup job will proceed."
    exit 0
}

#endregion
