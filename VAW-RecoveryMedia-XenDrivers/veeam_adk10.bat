rem Sample script for installing XenServer PV Drivers to a Windows PE Image
rem Script downloaded from https://github.com/xenserver/win-installer/blob/master/src/pescripts/ADK8.bat
rem 
rem Modified to use the Microsoft Windows 10 ADK 
rem
rem	Modified by Jason Berry
rem
rem usage: veeam_adk10.bat <wim file> <driver folder> 
rem
rem ADK typically found at C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim
rem Citrix drivers found in C:\Program Files\Citrix\Xentools\Drivers

echo "Wim File: %~1"
echo "Drivers: %~2"
rem echo "Arch: %3"

rem Create a folder to mount the wim file to, then mount it
mkdir mountpe
dism /Mount-Image /ImageFile:"%~1" /index:1 /MountDir:"mountpe"

rem Take ownership of the Realtek RTL8139C+ drivers folders to delete them

takeown /R /A /F mountpe\Windows\system32\DriverStore\FileRepository\netrtl64.inf_amd64_e646b306d9138846
takeown /R /A /F mountpe\Windows\WinSxS\amd64_netrtl64.inf.resources_31bf3856ad364e35_10.0.26100.1_en-us_1ff3bf29fb1413c3

rem Set premissions to allow deleting of the Realtek Drivers - RTL8139C+

icacls mountpe\Windows\system32\DriverStore\FileRepository\netrtl64.inf_amd64_e646b306d9138846 /grant Everyone:(F) /T
icacls mountpe\Windows\WinSxS\amd64_netrtl64.inf.resources_31bf3856ad364e35_10.0.26100.1_en-us_1ff3bf29fb1413c3 /grant Everyone:(F) /T

rem Delete folders and files for the Realtek Drivers

rmdir /s /q mountpe\Windows\system32\DriverStore\FileRepository\netrtl64.inf_amd64_e646b306d9138846
rmdir /s /q mountpe\Windows\WinSxS\amd64_netrtl64.inf.resources_31bf3856ad364e35_10.0.26100.1_en-us_1ff3bf29fb1413c3

rem Add the driver files

dism /Image:"mountpe" /Add-Driver /Driver:"%~2" /Recurse


rem Make the registry changes needed to set up filters and unplug
rem the emulated devices

reg load HKLM\pemount mountpe\Windows\System32\config\SYSTEM
reg ADD HKLM\pemount\ControlSet001\Services\xenfilt /v WindowsPEMode /t REG_DWORD /d 1
reg ADD HKLM\pemount\ControlSet001\Services\xenfilt\UNPLUG /v DISKS /t REG_MULTI_SZ /d xenvbd
reg ADD HKLM\pemount\ControlSet001\Services\xenfilt\UNPLUG /v NICS /t REG_MULTI_SZ /d xenvif\0xennet
reg ADD HKLM\pemount\ControlSet001\Control\class\{4D36E96A-E325-11CE-BFC1-08002BE10318} /v UpperFilters /t REG_MULTI_SZ /d XENFILT
reg ADD HKLM\pemount\ControlSet001\Control\class\{4D36E97D-E325-11CE-BFC1-08002BE10318} /v UpperFilters /t REG_MULTI_SZ /d XENFILT
reg unload HKLM\pemount

rem Unmount the wim file, and commit the changes

dism /unmount-image /mountdir:mountpe /commit