# CollectKB4438Logs

# 📗 Documentation

# Versions supported

This script has been tested to work on Windows Server/Workstation operating systems that use PowerShell version 2.0 or higher.

# Purpose

This script helps automate and simplify the Veeam SQL Plug-in's log collection process documented in [Veeam KB4438](https://www.veeam.com/kb4438).

# Description:

Automated collection of Veeam SQL Plug-in logs as well as OS related information for troubleshooting of Veeam SQL Plug-in backup jobs 

# Requirements

Local Administrator permissions and permission to execute scripts in an elevated PowerShell console.

# Usage:

How to download the script:

1) [For the machines with the Internet access] Download the script via this command:

    "Invoke-WebRequest https://raw.githubusercontent.com/VeeamHub/powershell/master/VeeamPluginforMSSQL-Logs/SQL_Plugin_KB.ps1 -o $Env:Temp\SQL_Plugin_KB.ps1"
   
2) [For the machines without Internet access] Use the machine with the Interner access to either download the script via "click on the name of the script -> Download raw file" or use the command above. After that copy the script to the machine in question, where Veeam SQL Plug-in is installed.

How to use the script:

1) Open an Administrative PowerShell Console, and navigate to the directory where the script was saved.
    (NOTE: Running the script in PowerSell ISE is NOT supported due to the additional modules that PowerShell ISE loads that can conflict with the script's execution.)
2) Run the following to execute the script: 

  PowerShell.exe -ExecutionPolicy ByPass -File "Path to the script\SQL_Plugin_KB.ps1"

3) While the script runs, the PowerShell console will display information about what's happening during each step of the process.
4) At the last step the script will offer to open the folder with the log's archive - enter Y and press Enter
5) Attach the generated .zip file to the Veeam support case.

# Features

This script will collect the following information from the machine:

- Veeam Plug-in for Microsoft SQL Server log files located in C:\ProgramData\Veeam\Backup\MSSQLPluginLogs
- Windows Application, System, Security, SMB, and Windows FailoverClustering events
- Native SQL_Err_Log_Folder log folder.
- System information
- Boot configuration : bcdedit /v
- Mounted volumes : mountvol /l
- Drivers : Get-WmiObject Win32_PnPSignedDriver| select devicename,drivername,infname,driverversion
- Hardware information : Get-CimInstance -ClassName Win32_ComputerSystemProduct 
- .NET Framework setup : Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
- Applied group policy settings : gpresult /z
- Environment variables : Get-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Control\Session Manager\Environment" and Get-ItemProperty -Path "HKCU:\Environment"
- Uptime : Get-CimInstance -ClassName Win32_OperatingSystem | Select LastBootUpTime
- Installed updates : get-wmiobject -class win32_quickfixengineering
- Windows Firewall settings : Get-NetFirewallProfile | Format-List
- TLS Settings : reg export "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL"
- Installed software : Get-WmiObject Win32_Product | Sort-Object Name | Format-Table IdentifyingNumber, Name, InstallDate -AutoSize
- Windows services status : gwmi win32_service | select displayname, name, startname,startmode,state
- Network configuration settings: "Get-NetAdapterBinding | Where-Object { $_.DisplayName -match "File and Printer Sharing" } | Format-Table -AutoSize"
- Network configuration: "ipconfig /all" , "netstat -bona" , "route print"
- Filters output: "fltmc instances "

# Feedback

Should you encounter any issues or bugs in the script, [please submit](https://github.com/VeeamHub/powershell/issues) an issue and provide details so it can be looked into further.

THIS SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
