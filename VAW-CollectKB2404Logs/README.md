# CollectKB2404Logs

# 📗 Documentation

# Versions supported

This script has been tested to work on Windows Server/Workstation operating systems that use PowerShell version 2.0 or higher.

# Purpose

This script helps automate and simplify the Veeam Agent's log collection process documented in [Veeam KB2404](https://www.veeam.com/kb2404).

# Description:

Automated collection of Veeam Agent logs as well as OS related information for troubleshooting of Veeam Agent backup jobs 

# Requirements

Local Administrator permissions and permission to execute scripts in an elevated PowerShell console.

# Usage:

1) For Windows machines with an internet connection, open an Administrative PowerShell console on the Windows machine where Veeam Agent for Microsoft Windows is installed and run these two lines to automatically download the log collection script to %temp% and execute it:

> 1: Invoke-WebRequest https://raw.githubusercontent.com/VeeamHub/powershell/master/VAW-CollectKB2404Logs/CollectKB2404Logs.ps1 -o $Env:Temp\CollectKB2404Logs.ps1 

> 2: PowerShell.exe -ExecutionPolicy ByPass -File $env:temp\CollectKB2404Logs.ps1 
    
2) If the script was manually downloaded to the machine in question, open an Administrative PowerShell Console, and navigate to the directory where the script was saved.
    (NOTE: Running the script in PowerSell ISE is NOT supported due to the additional modules that PowerShell ISE loads that can conflict with the script's execution.)
3) Run the following to execute the script: 

  PowerShell.exe -ExecutionPolicy ByPass -File "Path to the script\CollectKB2404Logs.ps1"

4) While the script runs, the PowerShell console will display information about what's happening during each step of the process.
5) At the last step the script will offer to open the folder with the log's archive - enter Y and press Enter
6) Attach the generated .zip file to the Veeam support case.

# Features

This script will collect the following information from the machine:

- Veeam Agent for Microsoft Windows log files located in C:\ProgramData\Veeam\Endpoint
- Veeam Installer Service logs from %programdata%\Veeam\Backup
- VSS hardware provider logs from %programdata%\Veeam\Backup
- Information provided by the systeminfo command
- Information provided by the vssadmin command
- Information provided by the fltmc command
- Windows Application, System, Security and Veeam Agent events
- The HKEY_LOCAL_MACHINE\SOFTWARE\Veeam\Veeam Endpoint Backup registry key.
- Computer UUID
- Veeam Agent certificate (for Agent Management) : Get-ChildItem Cert:\LocalMachine\My\ | where{$_.FriendlyName -eq 'Veeam Agent Certificate'} |Format-List -Property Issuer, Subject, SerialNumber, Thumbprint, NotAfter
- System information
- Boot configuration : bcdedit /v
- Mounted volumes : mountvol /l
- Drivers : Get-WmiObject Win32_PnPSignedDriver| select devicename,drivername,infname,driverversion
- Hardware information : wmic csproduct
- .NET Framework setup : Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
- Applied group policy settings : gpresult /z
- Environment variables : Get-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Control\Session Manager\Environment" and Get-ItemProperty -Path "HKCU:\Environment"
- Uptime : Get-CimInstance -ClassName Win32_OperatingSystem | Select LastBootUpTime
- Installed updates : get-wmiobject -class win32_quickfixengineering
- Windows Firewall settings : Get-NetFirewallProfile | Format-List
- TLS Settings : reg export "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL"
- Installed software : Get-WmiObject Win32_Product | Sort-Object Name | Format-Table IdentifyingNumber, Name, InstallDate -AutoSize
- Windows services status : gwmi win32_service | select displayname, name, startname,startmode,state
- Windows events : Microsoft-Windows-SMBClient/Connectivity, Microsoft-Windows-SMBClient/Operational
- Windows cluster events
- Network configuration settings: "Get-NetAdapterBinding | Where-Object { $_.DisplayName -match "File and Printer Sharing" } | Format-Table -AutoSize"
- Network configuration: "ipconfig /all" , "netstat -bona" , "route print"

# Feedback

Should you encounter any issues or bugs in the script, [please submit](https://github.com/VeeamHub/powershell/issues) an issue and provide details so it can be looked into further.

THIS SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
