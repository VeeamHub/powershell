# Automated Veeam Security & Compliance Analyzer enforcement script

## Function

This script can report current status and enforce recommended security settings on backup server. It is designed to run on the Veeam Backup Server.

***NOTE:*** Before executing this script in a production environment, I strongly recommend you:

* Read [Veeam Security & Compliance Analyzer Documentation](https://helpcenter.veeam.com/docs/backup/vsphere/best_practices_analyzer.html)
* Read [KB4525](https://www.veeam.com/kb4525)
* Fully understand what the script is doing
* Test the script in a lab environment

## Known Issues

* 

## Requirements

* Veeam Backup & Replication 12.1 or later

## Additional Information

* The script only applies missing security best practices found on the machine where Veeam Backup & Replication is installed, where the script is run from. The script will not apply security best practices to any other machine.
* Some of the practices apply security settings that **might affect other applications**. For example, the script will attempt to disable SSL2.0 on a server, which will cause other applications that depend on SSL 2.0 to fail.
* Some of the practices apply security settings that **might cause server lockdown**. For example, the script may attempt to disable Remote Desktop Services (TermService), restricting RDP access to the server; it may also disable Windows Remote Management (WinRM service), which, when disabled, may cause problems with external management of the server.
* The script will not process Suppressed entries within the Security & Compliance Analyzer UI. Before using the apply option within the script, compare the report output of the script to the entries within the UI and suppress any security recommendations you do not want the script to attempt to remediate.
* This script does not have an undo option. Once changes are made, if you wish to revert those changes, you must do so manually.
