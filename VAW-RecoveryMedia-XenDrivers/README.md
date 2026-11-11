## Modifying Veeam Recovery ISO to include Xen Network Drivers

## Author

Jason Berry (@twistedf8)

## Function

This script automates the modifying of Windows PE image used in the Veeam Recovery Image creation process.   This allows of the Xen drivers to be discovered automatically, where environments would leverage the generic drivers getting less performance specific to network bandwidth.   Using the Xen drivers allows for 1 Gb speeds vs. 100 Mb 

***NOTE:***

* This script is a modified version of the one found here: [xenserver - ADK8](https://github.com/xenserver/win-installer/blob/master/src/pescripts/ADK8.bat)
* WIM is typically found here: "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim"
* Citrix Drivers typically found here: "C:\Program Files\Citrix\Xentools\Drivers"
* Once .bat has been run you will need to modify the registry to tell Veeam Recovery Image creation process to use the ADK for the Recovery Media
	* Regedit - HKLM\SOFTWARE\Veeam\Endpoint Backup\
	* REG_DWORD - ForceUseAdkForRecoveryMedia - 1
* Batch file should only need to be run once and future versions of the agent will need to be installed and only the Veeam Recovery Image creation process should need to be run

## Known Issues

* *None*

## Requirements

* Windows Assessment and Deployment Kit
  * Install only the deployment tool
  * Works with Windows 2019 - should work with other versions but hasn't been tested
* Veeam Windows Agent 6.x
* Citrix - XenTools installed on the machine or downloaded and extracted to a folder that can be referenced

## Usage

./veeamadk10.bat [directory for wim] [directory for Citrix drivers]