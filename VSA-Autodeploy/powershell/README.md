# Veeam Software Appliance Auto-Deployment PowerShell Exemple

A complete PowerShell automation solution for deploying and configuring Veeam Backup & Replication infrastructure, including VBR servers, Linux proxies, and hardened repositories on Hyper-V.
Use it as an exemple for your own deployment

## 🎯 Overview

This project provides three integrated PowerShell scripts that automate the entire lifecycle of Veeam Software Appliance deployment:

1. **Create-ISO.ps1** - Generates multiple bootable ISO images for Veeam appliances ( VSA + VIA Proxy + VIA Hardened Repository )
2. **AutoProvisionning.ps1** - Add ISO to VMs, change boot order to DVD-ROM and starts Hyper-V VMs
3. **Install-VeeamInfra.ps1** - Configures Veeam infrastructure components

## 📋 Prerequisites

- **PowerShell**: 5.1 or later (PowerShell 7+ recommended)
- **Hyper-V**: Windows Server 2016+ or Windows 10/11 Pro with Hyper-V enabled
- **Veeam B&R**: Veeam Backup & Replication 13
- **Permissions**: Administrator privileges on Hyper-V host and VBR server
- **Network**: Connectivity to Hyper-V host and VBR server

### Required PowerShell Modules

Install required modules

`Install-Module -Name Hyper-V -Force`

## 🚀 Quick Start

### Complete Deployment Workflow

- Step 1: Create ISO images for all appliances

`.\Create-ISO.ps1`

- Step 2: Add ISO to VMs (already existing VMs), change boot order to DVD-ROM and starts Hyper-V VMs

`.\AutoProvisionning.ps1`

- Step 3: Configure Veeam infrastructure - Once VMs are booted, run this script to add them together

```
    $cred = Get-Credential
    .\Install-VeeamInfra.ps1 -VbrServer "192.168.1.168" -Credential $cred `
        -ProxyIP "192.168.1.141" -RepositoryIP "192.168.1.122" `
        -RepositoryName "HardenedRepo-122" -ImmutabilityPeriod 30 `
        -LicenseFilePath "K:\autodeploy vsa\test\license\Veeam-100instances-entplus-monitoring-nfr.lic"
```

---

## 📖 Script Documentation

### 1. Create-ISO.ps1

Creates bootable ISO images for Veeam appliances by processing JSON configuration files.

#### Purpose
Automates the generation of customized ISO images for multiple Veeam Software Appliances (VBR, VIA Proxy, Hardened Repository).

#### Configuration Files

The script processes three JSON configuration files sequentially:

- **viaproxy.json** - Configuration for Veeam Linux Proxy appliance
- **dhcp.json** - Configuration for VBR with DHCP networking
- **vhr.json** - Configuration for Veeam Hardened Repository

#### Usage
Run with default configuration files

`.\Create-ISO.ps1`

#### JSON Configuration Format

Each JSON file should contain appliance-specific settings :  **See main project**

#### Output

- Creates ISO files in the configured output directory
- Displays progress for each configuration file
- Reports success/failure status for each ISO creation

#### Error Handling

If a configuration file fails, the script:
- Displays a warning with the exit code
- Continues processing remaining configurations
- Returns overall status at completion

---

### 2. AutoProvisionning.ps1

Automates Hyper-V VM provisioning by mounting ISO images, configuring boot order, and starting VMs.

#### Synopsis

Mounts ISOs to Hyper-V VMs and boots them from DVD for automated deployment and QA testing.

#### Features

- ✅ Automatic ISO mounting to VM DVD drives
- ✅ Boot order configuration (Gen 2 UEFI support)
- ✅ VM state validation (prevents re-provisioning running VMs)
- ✅ Detailed logging with transcript support
- ✅ CSV-based configuration or hardcoded defaults
- ✅ Comprehensive error handling and reporting

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ConfigFile` | String | No | Path to CSV file with VM configurations |
| `ISOBasePath` | String | No | Base directory for ISO files (for relative paths) |
| `TranscriptPath` | String | No | Path for transcript logging (default: `.\Logs`) |

#### Usage Examples

**Using default configuration:**
Uses hardcoded VM configurations

`.\AutoProvisionning.ps1`

Load VMs from CSV file

`.\AutoProvisionning.ps1 -ConfigFile ".\hyperv-config.csv"`

#### CSV Configuration Format

Create a `vm-config.csv` file with the following structure : **see hyperv-config.csv**


#### Default VM Configurations

If no CSV is provided, the script uses these defaults:

- **VBRv13DHCP** - VBR server with DHCP
- **VBRv13Static** - VBR server with static IP
- **VIAPROXY** - Linux backup proxy
- **VeeamJEOSVHR13** - Hardened repository

#### Output

The script provides detailed output for each VM:

```
VM: VBRv13DHCP
✓ ISO found: K:\autodeploy vsa\test\DHCP_13.0.1.180_20251101.iso
✓ VM found (Generation 2, State: Off)
✓ ISO mounted to existing DVD drive
✓ Boot order set: DVD first
✓ VM started successfully
```

#### Summary Report

At completion, displays:
- Total VMs processed
- Success/failure counts
- Detailed results per VM
- Actions performed (ISO mounted, boot configured, VM started)

#### Exit Codes

- `0` - All VMs provisioned successfully
- `1` - One or more VMs failed to provision

#### Logging

Transcript logs are saved to:
`.\Logs\HyperV-QA_YYYYMMDD_HHMMSS.log`


---

### 3. Install-VeeamInfra.ps1

Automates Veeam Backup & Replication infrastructure configuration, including license installation, Linux proxy deployment, and hardened repository setup.

#### Synopsis

Connects to a VBR server, applies a license, and registers Linux infrastructure components with automatic retry logic.

#### Features

- 🔐 Secure credential handling with interactive prompts
- 🔄 Automatic retry logic (up to 45 minutes for VBR availability)
- 📜 License installation with validation
- 🐧 Linux host pairing with certificate authentication
- 💾 Hardened repository with immutability support
- 📊 Comprehensive deployment summary
- 📝 Full audit logging with transcripts
- ✅ Idempotent operations (safe to re-run)

#### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `VbrServer` | String | ✅ Yes | - | IP address or hostname of VBR server |
| `VbrUsername` | String | No | Prompt | Username for VBR authentication |
| `VbrPassword` | String | No | Prompt | Password for VBR authentication |
| `ProxyIP` | String | No | - | IP address of Linux Proxy (JeOS) |
| `RepositoryIP` | String | No | - | IP address of Hardened Repository |
| `RepositoryName` | String | No | - | Name for backup repository in VBR |
| `PairingCodeProxy` | String | No | `000000` | 6-digit pairing code for proxy |
| `PairingCodeRepo` | String | No | `000000` | 6-digit pairing code for repository |
| `LicenseFilePath` | String | No | - | Full path to Veeam license file (.lic) |
| `ImmutabilityPeriod` | Int | No | `21` | Immutability period in days (1-365) |
| `RetryInterval` | Int | No | `120` | Seconds between connection retries |
| `Timeout` | Int | No | `2700` | Total connection timeout (seconds) |
| `ProxyMaxTasks` | Int | No | `4` | Max concurrent tasks for proxy (1-32) |
| `TranscriptPath` | String | No | `.\Logs` | Path for transcript logging |

#### Usage Examples

**Interactive mode (prompts for credentials):**
```
.\Install-VeeamInfra.ps1 -VbrServer "192.168.1.50" -ProxyIP "192.168.1.51" `
-RepositoryIP "192.168.1.52" -RepositoryName "HardenedRepo-01" `
-PairingCodeProxy "123456" `
-PairingCodeRepo "654321"
```

**With credentials and license:**
```
.\Install-VeeamInfra.ps1 -VbrServer "192.168.1.50" -VbrUsername "veeamadmin" `
-VbrPassword "SecurePass123!" -ProxyIP "192.168.1.51" `
-RepositoryIP "192.168.1.52" -RepositoryName "HardenedRepo-01" `
-PairingCodeProxy "123456" -PairingCodeRepo "654321" `
-LicenseFilePath "C:\Licenses\veeam.lic" `
-ImmutabilityPeriod 30
```


#### Deployment Steps

The script executes in 7 phases:

1. **Load Veeam PowerShell Module** - Imports required Veeam assemblies and cmdlets
2. **Connect to VBR Server** - Establishes connection with retry logic
3. **Install License** - Applies Veeam license file (optional)
4. **Validate Prerequisites** - Checks components to configure
5. **Add Linux Hosts** - Registers Linux appliances with certificate pairing
6. **Configure Backup Proxy** - Sets up Linux proxy with task limits
7. **Configure Hardened Repository** - Creates repository with immutability

#### Pairing Codes

Linux appliances require pairing codes for certificate-based authentication:

1. Access appliance console or web interface
2. Navigate to configuration settings
3. Copy the 6-digit pairing code
4. Provide code via `-PairingCodeProxy` or `-PairingCodeRepo` parameters

**Important:** Pairing codes are time-limited. Generate them immediately before running the script.

#### Connection Retry Logic

If VBR is unavailable (e.g., still booting):
- Retries connection every 2 minutes (configurable)
- Continues for up to 45 minutes (configurable)
- Displays progress and remaining time
- Fails gracefully if timeout exceeded

#### License Installation

The script handles multiple license scenarios:
- ✅ Validates license file exists and is valid XML
- ✅ Skips if license already installed
- ✅ Provides detailed error messages for failures
- ✅ Continues deployment even if license fails

#### Repository Immutability

Hardened repositories support immutability:
- Prevents backup deletion/modification for specified period
- Protects against ransomware and accidental deletion
- Configurable from 1-365 days
- Enabled by default with 21-day period

#### Output Example
```
========================================
Veeam B&R - Infrastructure Deployment
Version 2.0

[1/7] Loading Veeam PowerShell module...
✓ Veeam PowerShell module loaded successfully

[2/7] Connecting to VBR server...
✓ Connected to VBR server: 192.168.1.50

[3/7] Installing license...
Checking license file: C:\Licenses\veeam.lic
File format: Valid XML
✓ License installed successfully
Edition: Enterprise Plus
Status: Valid

[5/7] Adding Linux hosts...
✓ Linux hosts added successfully

[6/7] Configuring backup proxy...
✓ Proxy configured for 192.168.1.51 with 4 max tasks

[7/7] Configuring hardened repository...
✓ Hardened repository 'HardenedRepo-01' created (Immutability: 30 days)
========================================
Deployment Summary

Linux Hosts: 2

    192.168.1.51

    192.168.1.52

Backup Proxies: 1

    192.168.1.51 [Enabled] (Max Tasks: 4)

Backup Repositories: 1

    HardenedRepo-01

✓ Deployment completed successfully

```

#### Exit Codes

- `0` - Deployment successful
- `1` - Critical failure (connection timeout, missing prerequisites)

#### Logging

Full transcript logs saved to:
`.\Logs\VeeamDeploy_YYYYMMDD_HHMMSS.log`

#### Exit Codes

- `0` - Deployment successful
- `1` - Critical failure (connection timeout, missing prerequisites)

#### Logging

Full transcript logs saved to:


---

## 🔧 Configuration

### Network Requirements

Ensure network connectivity between:
- Hyper-V host ↔ VBR server
- VBR server ↔ Linux appliances (proxy/repository)
- All components should be on same network or routable subnets

### Firewall Ports

Required ports for Veeam infrastructure:

| Port | Protocol | Purpose |
|------|----------|---------|
| 9392 | TCP | Veeam Backup Service |
| 6162 | TCP | Veeam Mount Service |
| 2500-3300 | TCP | Data transmission |
| 22 | TCP | SSH (Linux appliances) |

### Security Best Practices

1. **Credentials**: Never hardcode passwords in scripts
2. **Pairing Codes**: Generate fresh codes before deployment
3. **License Files**: Store securely with restricted access
4. **Network**: Use private networks for backup infrastructure
5. **Logging**: Review transcripts for security events

---

## 📁 Project Structure
```
veeam-autodeploy/
├── Create-ISO.ps1 # ISO generation wrapper
├── AutoProvisionning.ps1 # Hyper-V VM provisioning
├── Install-VeeamInfra.ps1 # Veeam infrastructure configuration
├── configs/
│ ├── viaproxy.json # Proxy appliance config
│ ├── dhcp.json # VBR DHCP config
│ ├── vhr.json # Repository config
│ └── vm-config.csv # VM provisioning config
├── Logs/ # Transcript logs (auto-created)
└── README.md # This file
```

---

## 🔄 Workflow Diagram
```
┌─────────────────────┐
│ Create-ISO.ps1 │ Generate bootable ISOs from JSON configs
└──────────┬──────────┘
│
▼
┌─────────────────────┐
│ AutoProvisionning │ Provision Hyper-V VMs and boot from ISOs
│ .ps1 │
└──────────┬──────────┘
│
▼
┌─────────────────────┐
│ Install-VeeamInfra │ Configure VBR, license, proxies, repos
│ .ps1 │
└─────────────────────┘
```

---

## 📝 License

MIT

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

---

## 📧 Support

For issues related to:
- **Scripts**: Open an issue in this repository
- **Veeam Products**: Contact [Veeam Support](https://www.veeam.com/support.html)
- **Hyper-V**: Refer to [Microsoft Documentation](https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/)

---

## 📚 Additional Resources

- [Veeam Backup & Replication Documentation](https://helpcenter.veeam.com/docs/backup/)
- [Veeam PowerShell Reference](https://helpcenter.veeam.com/docs/backup/powershell/)
- [Hyper-V PowerShell Module](https://docs.microsoft.com/en-us/powershell/module/hyper-v/)
- [Veeam Best Practices](https://bp.veeam.com/)

---

**Version**: 2.0  
**Last Updated**: December 2025  
**Tested On**: Veeam B&R 13, Windows Server 2022, Hyper-V Gen2 VMs
