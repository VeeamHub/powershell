# Collect-GuestLogs

# 📗 Documentation


## **Purpose**
This script helps automate and simplify the Guest OS log collection process documented in [Veeam KB1789](https://www.veeam.com/kb1789).

## **Description:**
Automated collection of Windows **guest OS** logs for troubleshooting of Veeam Backup jobs with _Application Aware Processing_ enabled (ie. SQL/Exchange/Active Directory/SharePoint/Oracle).

## **Requirements** <br>
Local Administrator permissions to be able to execute the script as Administrator.


## **Usage:** <br>

1. Download the script **[Collect-GuestLogs.ps1](https://raw.githubusercontent.com/VeeamHub/powershell/master/BR-Collect-GuestLogs/Collect-GuestLogs.ps1)** (Right-click link > '_Save link as_') and save it to the Windows machine where logs need to be collected.
2. Open an Administrative PowerShell Console (PowerShell ISE not supported), and navigate to the directory where the script was saved.
3. Run the following to execute the script:
     (Note: PowerShell's Execution Policy is set to _RemoteSigned_ by default on Windows Server machines. This is the reason _Unblock-File_ command is ran prior to calling the script.)
```
Unblock-File .\Collect-GuestLogs.ps1
.\Collect-GuestLogs.ps1
```
4. While the script runs, the PowerShell console will display information about what's happening during each step of the process. 
5. [Attach the generated **.zip** file to the Veeam support case.](https://www.veeam.com/kb4162)

## **Features** <br>
This script will collect the following information from the machine:

* Collects _GuestHelper_, _GuestIndexer_ and other logs located in _%ProgramData%\Veeam\Backup\_ (or alternate configured directory)
* Collects output of various VSSAdmin commands: Writers/Shadows/ShadowStorage/Providers
* Collects output of SystemInfo.exe
* Collects various registry values (_Veeam Backup and Replication_, _SCHANNEL_ and _System_ hives specifically) to check for various settings that affect In-Guest Processing
* Checks for Veeam registry values which may have leading or trailing whitespace which would cause them not to work as intended
* Collects list of installed software
* Collects permissions for all SQL users for each database if one or more running SQL instances have been detected
* Collects information about connected volumes
* Collects list of accounts with Local Administrator permissions
* Collects status of Windows Services
* Checks if '_File and Printer Sharing_' is enabled/disabled
* Collects _Application_ and _System_ Event Viewer logs
* Collects _VMMS_ Event Viewer logs if Hyper-V role is detected
* Collects status of Windows Firewall profiles
* Collects settings of attached NICs
* Collects list of installed features/roles

## Project Notes
**Author:** Chris Evans <br>

### **Feedback** <br>
Should you encounter any issues or bugs in the script, please [submit an issue](https://github.com/VeeamHub/powershell/issues) and provide details so it can be looked into further.

 <sub>THIS SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.</sub>
