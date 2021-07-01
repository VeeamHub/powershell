#Credentials to be set for all new servers to be abdded to job
$MasterWindowsCredentialUsername = 'FSGLAB\svc_veeam_bkup'
$MasterWindowsCredentialDescription = 'Veeam Backup Access to member servers'
$VeeamMasterWindowsCredential = Get-VBRCredentials -Name $MasterWindowsCredentialUsername | Where-Object Description -eq $MasterWindowsCredentialDescription

#Create list of servers from content of text file on share
$FilePath = '\\fileserver\share\servers-customcreds.txt'
$ServerList = Get-Content $FilePath

#Create new scope object for servers in list
$Servers = $ServerList | ForEach-Object { New-VBRIndividualComputerCustomCredentials -HostName $PSItem -Credentials $VeeamMasterWindowsCredential }
$AddServerScope = New-VBRIndividualComputerContainer -CustomCredentials $Servers

#Get existing protection group
$ProtectionGroup = Get-VBRProtectionGroup -Name 'ServersFromTextFile'

#Get custom credentials object from new scope object & existing protection group
$ExistingCredsScope = $ProtectionGroup.Container.CustomCredentials
$NewCredsScope = $AddServerScope.CustomCredentials

#Combine scope object arrays into new scope object
$NewScope = [array]$ExistingCredsScope + $NewCredsScope

#Create new combined container for combined scope object
$NewContainer = Set-VBRIndividualComputerContainer -Container $ProtectionGroup.Container -CustomCredentials $NewScope

#Set new combined container back to existing protection group
Set-VBRProtectionGroup -ProtectionGroup $ProtectionGroup -Container $NewContainer