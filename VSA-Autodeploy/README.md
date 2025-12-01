# Veeam Software Appliance ISO Automation Tool

[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%2BWSL-lightgrey.svg)](https://docs.microsoft.com/en-us/windows/wsl/)
[![Veeam](https://img.shields.io/badge/Veeam-v13.0-00B336.svg)](https://www.veeam.com/)

> 🚀 **Enterprise-grade PowerShell automation tool for customizing Veeam Software Appliance ISO files.**

## Overview

This advanced PowerShell script automates the customization of Veeam Software Appliance ISO files, enabling fully automated, unattended appliance deployments with enterprise-grade, reusable configurations. It supports JSON configuration loading, out-of-place ISO modification, advanced logging, and optional IS backup creation. Network, security, and monitoring details can be configured to fit enterprise environments.

- Tested on build 13.0.0.4967_20250822 & 13.0.1.180_20251101
- For Auto-Deployment PowerShell Exemple : [Powershell Folder](https://github.com/BaptisteTellier/autodeploy/tree/main/powershell)
---

## What's New (v2.6)
- Now requires PowerShell 7+ 
- Add Service Provider doesn't require any external tool anymore
- Node_Exporter install use offline_repo
- debug works for all VIA
- 2.6.1 : fixed issue - hardened repo not pairing automatically after deployment 
- 2.6.2 : fixed issue - official updater repo re-enablement after being disabled by offline repo (node exporter & restore conf)

## What's New (v2.5)

- Now works with RTM_13.0.1.180_20251101
- Confirmed with RTM : Add service provider works with SO (no logic added w/o SO yet)
- Enhanced logics with retry & Restart TTY end of script for reliability

## What's New (v2.4)

- Optionnal feature : Debug ! (enable root and ssh)
- Automatique unattended configuration restore now works offline

## What's New (v2.3)

- Optionnal feature : Automatique unattended configuration restore !
- Improved log inside VSA

## What's New (v2.2)

- Now support Veeam Infrastructure Appliance (JeOS) - Proxy / VMware Proxy / Hardened Repository

## What's New (v2.1)

- Fix network configuration not applied correctly
- CFGOnly parameter to create cfg file without iso creation or modification - useful for Packer or Cloud init
- NodeExporterDNF parameter to install Node Exporter with DNF (require online)

## What's New (v2.0)

- JSON configuration support for all parameters
- Out-of-place ISO customization by default
- Optional backup creation for in-place editing
- Improved script logging and in VSA logging

---

## Features

- Load configuration from JSON for reproducible deployments
- APPLIANCE TYPE SELECTION: Support for VSA, VIA, VIAVMware, and VIAHR appliances with dedicated deployment workflows
- Modify ISO files (create custom copies or modify in place)
- Automated GRUB and Kickstart configuration injection
- DHCP and static IP support, validated in script
- Regional keyboard & timezone settings
- Secure password and MFA configuration for Veeam accounts
- (optional) Prometheus node_exporter deployment
- (optional) Service Provider (VCSP) integration for v13.0.1+
- (optional) VBR licensing import and VBR tunning exemple such as Syslog server addition
- (optional) Support for Automatique unattended configuration restore
- (optional) Debug mode (enable root and ssh)
- Enterprise-level logging and error handling

---

## Disclaimer : Before you edit your ISO
Installing additional Linux packages, third-party applications, or changing OS settings (other than those that can be controlled via the Veeam Host Management Console) on the Veeam Appliances is not supported. Veeam Customer Support cannot provide technical support for appliances with unsupported modifications due to their unpredictable impact on the appliance's security, stability, and performance.

https://www.veeam.com/kb4772

---

## Prerequisites

### System Requirements
- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Version 7 or higher
- **WSL**: Windows Subsystem for Linux (Ubuntu/Debian recommended)
- **Memory**: Minimum 4GB RAM (8GB recommended for large ISOs)
- **Storage**: At least 14GB free space for ISO manipulation

### Software Dependencies
**Software dependencies:**
- `xorriso` installed in WSL
    ```
    sudo apt-get update
    sudo apt-get install xorriso
    ```
- For RHEL/CentOS/Rocky:
    ```
    sudo yum install xorriso
    ```

**PowerShell configuration:**
- Run with an appropriate execution policy
- Confirm WSL is accessible:
    ```
    wsl --version
    ```

### Optionnal Dependencies
**VBR tunning : License file**
- `license` folder at / of the folder where you run the script
- `xxx.lic` file inside the folder and `xxx.lic` for the `LicenseFile` parameter
- `LicenseVBRTune` set to `$true`

**node_exporter**
- copy offline_repo in the same folder you execut the script
- Might not work on VIA - Hardened Repository (not tested)

**Veeam Service Provider support**
- fill json parameters starting with VCSP

**Configuration Restore**
- download `conf` folder from repo with inside `unattended.xml`, `veeam_addsoconfpw.sh`, and your bco rename to `conftoresto.bco` (hard coded)
- Edit `unattended.xml` with your configuration password at BACKUP_PASSWORD. **It's the password for your configuration you set in VBR console.**
- Set JSON `RestoreConfig` to true and edit with your `ConfigPasswordSo`. **It's the password you set for "configuration backup" as Security Officer.**
- download `offline_repo` folder and place it at / of the folder where you run the script

---

## Quick Start

### Using JSON Configuration (Recommended)

1. Create a JSON configuration file like the example below or download it from the repo :

    ```
    {
    "SourceISO": "VeeamSoftwareAppliance_13.0.1.180_20251101.iso",
    "OutputISO": "",
    "ApplianceType": "VSA",
    "InPlace": false,
    "CreateBackup": true,
    "CleanupCFGFiles": true,
    "CFGOnly": false,
    "GrubTimeout": 0,
    "KeyboardLayout": "fr",
    "Timezone": "Europe/Paris",
    "Hostname": "veeam-backup",
    "UseDHCP": false,
    "StaticIP": "192.168.1.166",
    "Subnet": "255.255.255.0",
    "Gateway": "192.168.1.1",
    "DNSServers": ["192.168.1.64", "8.8.8.4", "8.8.8.8"],
    "VeeamAdminPassword": "123q123Q123!123",
    "VeeamAdminMfaSecretKey": "JBSWY3DPEHPK3PXP",
    "VeeamAdminIsMfaEnabled": "true",
    "VeeamSoPassword": "123w123W123!123",
    "VeeamSoMfaSecretKey": "JBSWY3DPEHPK3PXP",
    "VeeamSoIsMfaEnabled": "true",
    "VeeamSoRecoveryToken": "12345678-90ab-cdef-1234-567890abcdef",
    "VeeamSoIsEnabled": "true",
    "NtpServer": "time.nist.gov",
    "NtpRunSync": "true",
    "NodeExporter": false,
    "LicenseVBRTune": false,
    "LicenseFile": "Veeam-100instances-entplus-monitoring-nfr.lic",
    "SyslogServer": "",
    "VCSPConnection": false,
    "VCSPUrl": "",
    "VCSPLogin": "",
    "VCSPPassword": "",
    "RestoreConfig": false,
    "ConfigPasswordSo": "",
    "Debug": false
    }
    ```

2. Place the script, ISO, and JSON in the same directory.

3. Run:
    `
    .\autodeploy.ps1 -ConfigFile "production-config.json"
    `
4. See [Powershell Folder](https://github.com/BaptisteTellier/autodeploy/tree/main/powershell) for Auto-Deployment PowerShell Exemple :

- Create-ISO.ps1 - Generates multiple bootable ISO images for Veeam appliances ( VSA + VIA Proxy + VIA Hardened Repository )
- AutoProvisionning.ps1 - Add ISO to VMs, change boot order to DVD-ROM and starts Hyper-V VMs
- Install-VeeamInfra.ps1 - Configures Veeam infrastructure components (VIA Proxy + VIA Hardened Repository)

---

## Configuration Parameters

### Core Parameters

| Parameter | Type   | Description                      | Default                                   | Required     |
|-----------|--------|----------------------------------|-------------------------------------------|-------------|
| ConfigFile    | String | Path to JSON file                 | ""                                        | No          |
| SourceISO     | String | Source ISO filename (required)    | VeeamSoftwareAppliance_13.0.0.4967_20250822.iso | Yes         |
| OutputISO     | String | Customized ISO filename           | auto (adds _customized)                   | No          |
| ApplianceType    | String | VSA, VIA, VIAVMware, and VIAHR | VSA                                       | No          |
| InPlace       | Bool   | Modify original ISO directly      | false                                     | No          |
| CreateBackup  | Bool   | Create backup for InPlace changes | true                                      | No          |
| CleanupCFGFiles| Bool  | Clean temp config files           | true                                      | No          |
| CFGOnly | Bool  | write cfg file and don't touch ISO (for cloudInit/packer)  | false                   | No          |
| GrubTimeout   | Int    | GRUB timeout (seconds)            | 10                                        | No          |
| KeyboardLayout| String | Keyboard code                     | fr                                        | No          |
| Timezone      | String | System timezone                   | Europe/Paris                              | No          |
| Hostname      | String | Hostname for appliance (15char max for Microsoft Domaine)  | veeam-server     | No          |

### Network Parameters

| Parameter   | Type     | Description                     | Default         |
|-------------|----------|---------------------------------|-----------------|
| UseDHCP     | Bool     | Use DHCP for network config     | false           |
| StaticIP    | String   | Static IP address               | 192.168.1.166   |
| Subnet      | String   | Subnet mask                     | 255.255.255.0   |
| Gateway     | String   | Gateway IP                      | 192.168.1.1     |
| DNSServers  | Array    | DNS servers (comma-separated)   | ["192.168.1.64", "8.8.4.4"] |

### Veeam Security Appliance Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| VeeamAdminPassword | String | Password for Veeam admin account. Must meet complexity requirements (15+ chars with mixed case, numbers, symbols) | `123q123Q123!123` |
| VeeamAdminMfaSecretKey | String | Base32-encoded MFA secret key for admin account TOTP authentication (16-32 characters) | `JBSWY3DPEHPK3PXP` |
| VeeamAdminIsMfaEnabled | String | Enable/disable multi-factor authentication for admin account ("true"/"false") | `"true"` |
| VeeamSoPassword | String | Password for Veeam Security Officer (SO) account. Must meet same complexity requirements as admin | `123w123W123!123` |
| VeeamSoMfaSecretKey | String | Base32-encoded MFA secret key for SO account TOTP authentication | `JBSWY3DPEHPK3PXP` |
| VeeamSoIsMfaEnabled | String | Enable/disable multi-factor authentication for SO account ("true"/"false") | `"true"` |
| VeeamSoRecoveryToken | String | GUID-format recovery token for SO account emergency access and recovery scenarios | `eb9fcbf4-2be6-e94d-4203-dded67c5a450` |
| VeeamSoIsEnabled | String | Enable/disable the Security Officer account entirely ("true"/"false") | `"true"` |
| NtpServer | String | Network Time Protocol server for time synchronization (FQDN or IP address) | `time.nist.gov` |
| NtpRunSync | String | Enable automatic time synchronization on boot ("true"/"false") - if sync fails customization fails | `"true"` |

### Optional Features

| Parameter           | Type    | Description                      | Default                                   |
|---------------------|---------|----------------------------------|-------------------------------------------|
| NodeExporter        | Bool    | Deploy Prometheus node_exporter - offline_repo folder required | false                |
| LicenseVBRTune      | Bool    | Auto-install Veeam license (only VSA) | false                                |
| LicenseFile         | String  | License filename                 | Veeam-100instances-entplus-monitoring-nfr.lic |
| SyslogServer        | String  | Syslog server IP                 | ""                                        |
| VCSPConnection      | Bool    | Connect to VCSP  (only VSA)      | false                                     |
| VCSPUrl             | String  | VCSP server URL                  | ""                                        |
| VCSPLogin           | String  | VCSP tenant's login              | ""                                        |
| VCSPPassword        | String  | VCSP tenant's password           | ""                                        |
| RestoreConfig       | Bool    | Enable unattended Configuration Restore     | false                          |
| ConfigPasswordSo    | String  | SO Config Password               | ""                                        |
| Debug               | Bool    | enable root and ssh (don't use in production)             | false                                        |

---

### Security Notes

**Password Requirements**
- The passwords for the veeamadmin and veeamso account must meet the following requirements:
- 15 characters minimum
- 1 upper case character
- 1 lower case character
- 1 numeric character
- 1 special character
- No more than 3 characters of the same class in a row. For example, you cannot use more than 3 lowercase or 3 numerical characters in sequence
- The passwords for the veeamadmin and veeamso accounts must be different
**NTP Configuration**
- To avoid timing issues with multifactor authentication, it is recommended to set ntp.runSync=true.
**MFA requirements**
- The multifactor authentication secret key must be specified as a 16 digit, Base32-encoded string.
- The recovery token must be specified using hexadecimal values — 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, A, B, C, D, E, F. Note that you can generate an appropriate string with the New-Guid cmdlet in Microsoft PowerShell.
**Security Officer Account**
- The SO account provides service-level access separate from the administrative account for improved security separation

### Network Security
- **IP Validation**: Comprehensive IPv4 address format validation using regex patterns
- **DNS Configuration**: Support for multiple DNS servers with individual validation
- **Static Configuration**: Complete network parameter validation for enterprise deployments

### File Security
- **Transcript Logging**: Comprehensive logging with timestamp and severity levels

---

## How Optional Feature works :

### Node_Exporter
The script install node_exporter from offline repo
- Prometheus monitoring with firewall configuration 9100

### VBR Tunning
- **License Installation**: Automated license deployment and activation
- **Run custom script** : Exemple PS script : install lic and add Syslog Server
- If syslog parameters is empty, Add-VBRSyslogServer is not added

Current Exemple in the script is : 
```
$CustomVBRBlock = @(
    "# Custom VBR config",
    "pwsh -Command '",
    "Import-Module /opt/veeam/powershell/Veeam.Backup.PowerShell/Veeam.Backup.PowerShell.psd1",
    "Install-VBRLicense -Path /etc/veeam/license/$LicenseFile",
    "Add-VBRSyslogServer -ServerHost '$SyslogServer' -Port 514 -Protocol Udp",
    "'"
)
```

### VCSP Connection (RTM_13.0.1.180_20251101 and above)
- **VCSP Connection**: Veeam Service service provider integration with credential management & VSPC management agent flag enable
- (works with optional feature : VBR Tunning to install license)
- check `/var/log/veeam_init.log` for progression
- If you want to remotly enable analytics, for cloud init for exemple, check VCSP folder for bash script


### CFG files Only
- **CFGOnly** : Useful for Packer/CloudInit deployment, you can set parameters to $true thus the script generate only CFG files and do not edit ISO

### Automatique Unattended Restore
- (works with optional feature : VBR Tunning to install license)
- How unattended.xml works : https://helpcenter.veeam.com/docs/vbr/userguide/restore_vbr_linux_edit.html?ver=13
- **Restore process can be very long** : check `/var/log/veeam_init.log` for progression

To speedup the process, you can set `"vbr_control.runStart=false"` in the script ( hardcoded `function Get-VeeamHostConfigBlock`)
- find log - Password SO config: `/var/log/veeam_addsoconfpw.log` & Config restore: `/var/log/veeam_configrestore.log`
- What veeam_addsoconfpw.sh do :
```
Retrieving local IP address
VSA URL: https://192.168.1.169:10443
Generating TOTP code (oathtool)
TOTP code generated
Step 1/4: Authentication (curl)
Authentication successful
Step 2/4: login check
login verified
Step 3/4: Add password
Password added successfully
Step 4/5: Create current configuration password
Current configuration password created successfully
Step 5/5: Final verification
Final verification successful
Process completed successfully
```
- install curl and oathtool from offline repo and then removes oathtool

---

## Known issues
- If you enable NtpRunSync and it fails, customization fails
- Using static IP doesn't set DNS properly : BUG in VSA, will be fix by Veeam. **Workaround :** DHCP or Enter Network in TUI parameter and Apply
- If it boots on the init wizard but it's already fully configured and you cannot go through. wait 2-3min. Then check `/var/log/veeam_init.log` (ctrl+alt+F2-F3 etc... to change TTY ) - something went wrong. **Workaround :** Reinstall

## Troubleshooting

### Making ISO
- If you just installed WSL, you need to reboot
- Ensure WSL is installed and available (`wsl --list --verbose`)
- Install `xorriso` in WSL (`sudo apt-get install xorriso`) or update it
- If you just installed WSL, you might have permission issue, reboot Windows
- Confirm ISO file is located in the same directory as the script
- Use correct JSON structure with all parameters
- You **cannot override** parameters in CLI if you use JSON
- If you use optionnal features: check prerequisite and folder structure
- Use `$CFGOnly=true` to verify your kickstart file contain all Configurations Blocks
- Check log file `ISO_Customization.log` for timestamped error messages
- to browse ISO with WSL xorriso `wsl xorriso -indev "VeeamSoftwareAppliance_13.0.0.4967_20250822.iso" -ls /`

### Booting ISO
- If your specified answers do not meet these requirements, the configuration process will fail. To troubleshoot errors, you can use the Live OS ISO to view the `/var/log/VeeamBackup/veeam_hostmanager/veeamhostmanager.log` file and the system logs files in the `/var/log/anaconda directory.`
- During installation and after boot, you can try CTRL+ALT+1 to 6 to change TTY, sometimes welcome wizard will dispears and you can check logs
- Post-install log and Veeam init are stored here : `/var/log/appliance-installation-logs/post-install.log` & `/var/log/veeam_init.log`
- If you enable NtpRunSync and it fails, customization fails
- Unattended Configuration Restore logs are stored here : wrong SO Password & TOTP : `/var/log/veeam_addsoconfpw.log` & wrong unattended config password or fail restore : `/var/log/veeam_configrestore.log`

### Troubleshooting parameters

#### Network Configuration Validation
- **IP Format**: Ensure IP addresses match IPv4 format (xxx.xxx.xxx.xxx)
- **Subnet Masks**: Use standard subnet mask formats (255.255.255.0)
- **DNS Arrays**: Provide DNS servers as PowerShell arrays: `@("8.8.8.8", "8.8.4.4")`

#### ISO File Access
- **File Locks**: Ensure ISO files aren't mounted or locked by other applications
- **Permissions**: Verify read/write access to ISO file location
- **Path Format**: don't use path, put ISO in the same directory to avoid issue with WSL

---

## Work with MFA & Recovery Token

- For MFA creation, you can use this PowerShell :
  
    `
    $MFASecret = -join ((1..16) | ForEach-Object { "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"[(Get-Random -Maximum 32)] })
    `
  
    `
    R2NV4ICF4GM274OU
    `
- For Recovery Token, you can use this PowerShell :
  
    `
    New-Guid
    `
  
    `
    16173f8b-54de-43c7-8364-da36a11ec8ab
    `
  
--

## Contributing

1. Fork this repo and create a pull request to suggest improvements.
2. Use [GitHub Issues](https://github.com/PleXi00/autodeploy/issues) for bugs or feature requests.

---

## TO DO

- [x] Parameters to change Hostname ✅ **Completed**
- [x] Function to change IP / DHCP ✅ **Completed**
- [x] Support for multiple ISO formats (JEoS & VSA) ✅ **Completed**
- [x] Automated backup creation before modification ✅ **Completed**
- [x] Support for JSON configuration file ✅ **Completed**
- [x] Automated Restore Configuration ✅ **Completed**
- [x] Automated Restore Configuration offline ✅ **Completed**
- [ ] Test Automated Restore Configuration offline with RTM/GA
- [x] Add offline repo support for node_exporter instead of binary ✅ **Completed**
- [ ] Remove curl after install to only keep curl-minimal (automated conf restore)


## Support

### Documentation Resources
- [Veeam Backup & Replication Documentation](https://helpcenter.veeam.com/docs/vbr/userguide/overview.html?ver=13)
- [Veeam Software Appliance Unattended Documentation](https://helpcenter.veeam.com/docs/vbr/userguide/deployment_linux_silent_deploy_configure.html?ver=13)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Rocky Linux Kickstart Guide](https://docs.rockylinux.org/guides/automation/kickstart/)
- [Node Exporter Releases](https://github.com/prometheus/node_exporter/releases)


## Author & Stats

**Author**: Baptiste TELLIER  
**Version**: 2.6.2
**Creation**: November 28, 2025

![GitHub stars](https://img.shields.io/github/stars/PleXi00/autodeploy)
![GitHub forks](https://img.shields.io/github/forks/PleXi00/autodeploy)
![GitHub issues](https://img.shields.io/github/issues/PleXi00/autodeploy)
![GitHub last commit](https://img.shields.io/github/last-commit/PleXi00/autodeploy)

---

_Made with ❤️ for the Veeam community by Baptiste TELLIER and the help of AI_

---

*If this project helps you automate Veeam deployments, please give it a star on GitHub!*
