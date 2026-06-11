# Collect-GuestLogs

# 📗 Documentation
## **Versions supported**
This script has been tested to work on Windows Server/Workstation operating systems that use PowerShell version 4.0 or higher.

PowerShell 4.0 ships in-box with Windows Server 2012 R2 / Windows 8.1 and later. Older guest OSes still supported by Veeam Backup & Replication 12 (e.g. Windows Server 2008 R2 SP1 / Windows 7 SP1) must have [WMF 4.0](https://www.microsoft.com/en-us/download/details.aspx?id=40855) installed. On operating systems older than Windows Server 2012 / Windows 8, the script automatically falls back to built-in alternatives for cmdlets that are not available (e.g. `netsh advfirewall` instead of `Get-NetFirewallProfile`).

The script uses only components shipped with a default Windows installation — no third-party tools or modules are required.

## **Purpose**
This script helps automate and simplify the Guest OS log collection process documented in [Veeam KB1789](https://www.veeam.com/kb1789).

## **Description:**
Automated collection of Windows-based logs for troubleshooting of Veeam Backup jobs with _Application Aware Processing_ enabled (ie. SQL/Exchange/Active Directory/SharePoint/Oracle).

## **Requirements** <br>
Local Administrator permissions and permission to execute scripts in an elevated PowerShell console.

## **Usage:** <br>

1. **[Download the script](https://raw.githubusercontent.com/VeeamHub/powershell/master/BR-Collect-GuestLogs/Collect-GuestLogs.ps1)** <--- **THIS LINK!** (Right-click > '_Save link as_') and save it to the Windows machine where logs need to be collected. DO NOT right-click and save the Collect-GuestLogs.ps1 at the top of this page, otherwise you will end up with a ps1 file containing nothing but HTML code.
2. Open an Administrative PowerShell Console, and navigate to the directory where the script was saved. 
     - (**NOTE**: Running the script in PowerShell ISE is **NOT** supported due to the additional modules that PowerShell ISE loads that can conflict with the script's execution.)
4. Run the following to execute the script:
     (Note: PowerShell's Execution Policy is set to _RemoteSigned_ by default on Windows Server machines. This is the reason _Unblock-File_ command is ran prior to calling the script.)
```
Unblock-File .\Collect-GuestLogs.ps1
.\Collect-GuestLogs.ps1
```
4. While the script runs, the PowerShell console will display information about what's happening during each step of the process. 
5. [Attach the generated **.zip** file to the Veeam support case.](https://www.veeam.com/kb4162)

### **Optional parameters** <br>

| Parameter | Description |
| --- | --- |
| `-IncludeSecurityEvents` | Includes the Security event log in the exported Windows Event Logs. If omitted in an interactive session, a prompt is shown (defaults to No). In a non-interactive session, the Security log is excluded unless this switch is passed. |
| `-Force` | Suppresses the confirmation normally shown when the script detects it is running on a Veeam Backup & Replication server. Required for unattended runs on a VBR server. |
| `-OutputDirectory <path>` | Directory where the collected log bundle is created. Useful when the default location (a _Case_Logs_ folder on the same volume as the Veeam log directory) is low on disk space. The directory is created if it does not exist. |

### **Remote execution** <br>
The script can be executed against a remote guest OS using PowerShell Remoting. All interactive prompts are automatically skipped in remote sessions, so use the parameters above to control behavior:
```
Invoke-Command -FilePath .\Collect-GuestLogs.ps1 -ComputerName <GUEST_OS_SERVERNAME> -Credential (Get-Credential)
```

## **Features** <br>
This script will collect the following information from the machine. Tabular data (installed software, services, volumes, local accounts, '_File and Printer Sharing_' status) is exported in CSV format so it can be sorted and filtered in a spreadsheet application.

* Collects _GuestHelper_, _GuestIndexer_ and other logs located in _%ProgramData%\Veeam\Backup\_ (or alternate configured directory)
* Collects output of various VSSAdmin commands: Writers/Shadows/ShadowStorage/Providers
* Collects output of SystemInfo.exe
* Collects output of FLTMC.exe (list of registered Filter Manager minifilter drivers)
* Detects the hypervisor and collects guest tools information (VMware Tools / Hyper-V Integration Services / Nutanix Guest Tools version and service status)
* Collects list of installed Windows updates/hotfixes
* Collects various registry values (_Veeam Backup and Replication_, _SCHANNEL_ and _System_ hives specifically) to check for various settings that affect In-Guest Processing
* Checks for Veeam registry values which may have leading or trailing whitespace which would cause them not to work as intended
* Collects list of installed software (read from the registry uninstall keys — avoids the Windows Installer consistency checks and repair operations that querying _Win32\_Product_ would trigger)
* Collects permissions for all SQL users for each database if one or more running SQL instances have been detected
* Collects information about connected volumes
* Collects list of accounts with Local Administrator permissions
* Collects status of Windows Services
* Checks if '_File and Printer Sharing_' is enabled/disabled
* Collects Event Viewer logs
* Collects status of Windows Firewall profiles
* Collects settings of attached NICs
* Collects a point-in-time netstat snapshot (with an embedded disclaimer noting that Veeam data transport ports are only bound during active jobs; deliberately excluded from the triage summary)
* Collects list of installed features/roles
* Writes a _CollectionErrors.log_ into the archive listing any collection steps that failed, so it is possible to distinguish "collection failed" from "not present on this system"
* Generates a triage summary (_!_SUMMARY.txt_) at the root of the archive surfacing facts an engineer typically checks first: VSS writer states, non-default VSS providers, key service states, low disk space, minifilter drivers not shipped in-box with Windows, pending reboot indicators, SCHANNEL protocol customizations, and any collection failures. The summary is advisory only (facts, not a diagnosis) — any check that cannot be parsed (e.g. localized vssadmin output on non-English OSes) is flagged for manual review instead of reporting an all-clear

## Project Notes
**Author:** Chris Evans <br>

### **Feedback** <br>
Should you encounter any issues or bugs in the script, please [submit an issue](https://github.com/VeeamHub/powershell/issues) and provide details so it can be looked into further.

 <sub>THIS SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.</sub>
