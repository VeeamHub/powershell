
## Veeam Backup & Replication Pre-Upgrade Readiness Check (VBR 13.0 / 13.1)

## Author

Jason Berry (@twistedf8)

## Function

Connects to a VBR server via the REST API and validates all pre-upgrade
    requirements documented at:
    https://helpcenter.veeam.com/docs/vbr/userguide/upgrade_vbr_byb.html?ver=13

    Use -TargetVersion to select the upgrade target:
      13.0 (default)  Upgrading from VBR 12.x   -  requires 12.3.1.1139+ or 12.3.2+
      13.1            Upgrading to VBR 13.1       -  requires 12.3.1.1139+, 12.3.2+, 13.0.1, or 13.0.2
                      (direct upgrade from v12.3.1.1139+ is supported, per KB4763 / RN 13.1)

    Checks performed:
      1.  Server connectivity and API availability
      2.  Current VBR version eligibility for the selected target
      3.  License status and expiry
      4.  Configuration backup  -  enabled and recent (within 7 days)
      5.  Running backup/replication/copy jobs (must be zero)
      6.  Running restore sessions (must be zero)
      7.  Running SureBackup / SureLive sessions (must be zero)
      8.  Repository free space (warns below 10 GB, fails below 2 GB)
      9.  Backup proxy availability
      10. Managed Server Components (out of date)
      11. Deprecated Features
	      - Reversed incremental backup mode
	      - Restore point-based retention
	      - Per-Machine backup disabled
	      - AD-based auth for Cloud Connect tenants
      Checks 12-20 use WMI/CIM and only run when the script is executed directly
      on the VBR server. They are skipped when run remotely.

      12. Local OS version (Windows Server 2019 or 2022 required for VBR 13)
      13. Pending Windows reboot check
      14. Veeam Windows services status
      15. System drive free disk space (>= 10 GB recommended for installer)
      16. Port 443 availability (VBR 13 REST service requires port 443 — skipped for 13.1 target)
      17. SQL Server version (2016 or later required; PostgreSQL is fine)
      18. PowerShell 7 installed (required for Veeam PS module in VBR 13)
      19. CPU core count (minimum 8 logical cores required)
      20. RAM (minimum 16 GB required)
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
### EXAMPLE 3
.\VBR13-PreUpgradeCheck.ps1 -VBRServer vbr01.corp.local -TargetVersion 13.1 -Credential (Get-Credential)
