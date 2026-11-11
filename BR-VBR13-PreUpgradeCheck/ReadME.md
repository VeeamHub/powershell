
## Veeam Backup & Replication v13 Pre-Upgrade Readiness Check

## Author

Jason Berry (@twistedf8)

## Function

Connects to a VBR server via the REST API and validates all pre-upgrade
    requirements documented at:
    https://helpcenter.veeam.com/docs/vbr/userguide/upgrade_vbr_byb.html?ver=13

    Checks performed:
      1.  Server connectivity and API availability
      2.  Current VBR version (must be v11 or v12 to upgrade to v13)
      3.  License status and expiry
      4.  Configuration backup  -  enabled and recent (within 7 days)
      5.  Running backup/replication/copy jobs (must be zero)
      6.  Running restore sessions (must be zero)
      7.  Running SureBackup / SureLive sessions (must be zero)
      8.  Repository free space (warns below 10 GB, fails below 2 GB)
      9.  Backup proxy availability
      10. Managed Server Components (out of date)
      11. Local OS version (Windows Server 2019 or 2022 required for VBR 13)
      12. Pending Windows reboot check
      13. Veeam Windows services status
      14. System drive free disk space (>= 10 GB recommended for installer)
      15. Deprecated Features
	      - Reversed incremental backup mode
	      - Restore point-based retention
	      - Per-Machine backup disabled
	      - AD-based auth for Cloud Connect tenants 
[Download Example Report](http://htmlpreview.github.io/powershell/BR-VBR13-PreUpgradeCheck/VBR13_PreUpgrade_Report_20260629_121002.html)

## Known Issues

* *None*

## Requirements

-   Veeam Backup and Recovery 
    -   Administrator account used to access the REST API.
-   Network connectivity
    -   The server executing the script needs to be able to access the VBR REST API
-   PowerShell Core

## Usage

### EXAMPLE 1
![example 1](https://snipboard.io/a8PBUd.jpg)
.\VBR13-PreUpgradeCheck.ps1 -VBRServer vbr01.corp.local -SkipCertCheck -Credential (Get-Credential)
### EXAMPLE 2
![example 2](https://snipboard.io/kFuzjU.jpg)
.\VBR13-PreUpgradeCheck.ps1 -VBRServer 10.0.0.50 -SkipCertCheck -ReportPath C:\Temp
