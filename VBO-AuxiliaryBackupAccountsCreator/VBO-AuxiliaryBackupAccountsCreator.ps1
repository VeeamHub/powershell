<# 
.NAME
    Veeam Backup for Microsoft Office 365 Auxiliary Backup Accounts creator
.SYNOPSIS
    Script to use for automatically creating auxiliary backup accounts
.DESCRIPTION
    Script to use for automatically creating auxiliary backup accounts for backing up SharePoint/OneDrive for Business
    Created for Veeam Backup for Microsoft Office 365 v4

    Requires MSOnline Module (will be installed if missing)

    The script will perform the following steps:
    - Add accounts to your Office 365 subscription and a security group
    - Configure accounts as backup accounts within Veeam Backup for Microsoft Office 365

    Released under the MIT license.
.LINK
    http://www.github.com/nielsengelen
	
	Modified by Herbert Szumovski 2020 07 27:
	
		1) Microsoft needs TLS 1.2 now, so I added it.
		2) Modified Login to avoid http request, because it dies at some customers with HttpRequestException, dependent on 
			their server setup.
		3) Let users enter a password (cleartext) instead of generating a random one (multiple user wish).
		4) Check if the securitygroup already contains existing backup users. If yes, I remember them, otherwise they would be
			erroneously disabled.
		5) Moved securitygroup creation out of the userloop, to avoid nasty sync issues which created multiple 
			secgroups with the same name at some customers.
		6) Changed parameter in Get-VBOOrganizationGroup from "Name" to "Displayname" to avoid warningmessage about deprecated parameter.
		
#>

# Modify the values below to your needs
# Number of accounts to add - advised is to add in bulk of 8 accounts
[Int]$Accounts = 8

# Number to start from (change this if you are adding additional accounts to already existing ones)
[Int]$StartFrom = 1

# Display Name for the accounts (these will get a number at the end, eg VeeamBackupAccount1, VeeamBackupAccount2)
$DisplayName = "VeeamBackupAccount"

# Your domain name
$Domain = "yourdomain(.onmicrosoft).com"

# Your security group name
$SecurityGroup = "VBO"

# Organization name as configured in Veeam Backup for Microsoft Office 365
$OrganizationName = "yourdomain(.onmicrosoft).com"
#----------------------------------------------------------------
# Do not change below unless you know what you are doing

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ((Get-InstalledModule -Name "MSOnline" -ErrorAction SilentlyContinue) -eq $null) {
    Install-Module -Name MSOnline
}
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"
Import-Module -Name MSOnline

# Connect to Microsoft Office 365
Write-Host "Provide your Office365 Admin Account Credentials" -BackgroundColor DarkGreen

$Credential = Get-Credential

Write-Host "Connecting to AzureAD..." -BackgroundColor DarkGreen
Connect-MsolService -Credential $Credential

Write-Host "Adding accounts..." -BackgroundColor DarkGreen

[Int]$TotalAccounts = $StartFrom + $Accounts - 1
$AccountsArray = @()

Write-Host 
Write-Host "In case you add additional backup users, they must use the same password as the already existing ones !!"
$Password = Read-Host 'Type password which will be used by all backup users' 

$SecGroup = Get-MsolGroup -GroupType Security | Where-Object { $_.DisplayName -eq $SecurityGroup}
if (!$secGroup) {
    $secGroup = New-MsolGroup -DisplayName $SecurityGroup -Description "Veeam Backup for Microsoft Office 365 Auxiliary Backup Accounts group" -ErrorAction SilentlyContinue
	Write-Host "Sleeping for 30 seconds to prevent sync issues for newly created security group $SecurityGroup ." -BackgroundColor DarkGray
	Start-Sleep -Seconds 30
}

# Connect to Veeam Backup for Microsoft Office 365 and remember old backup users, in case they exist, before adding new ones
Write-Host "Connecting to Veeam Backup for Microsoft Office 365..." -BackgroundColor DarkGreen
$Org = Get-VBOOrganization -Name $OrganizationName

Write-Host "Collecting VBO group and old members ..." -BackgroundColor DarkGreen
$Group = Get-VBOOrganizationGroup -Organization $Org -DisplayName $SecurityGroup

$Members = Get-VBOOrganizationGroupMember -Group $Group
$BackupAccounts = @()
ForEach ($Member in $Members) {
      Write-Host "Setting Backup Account password for old backup user $Member." -BackgroundColor DarkGreen
      $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
      $BackupAccounts += New-VBOBackupAccount -SecurityGroupMember $Member -Password $SecurePassword
}

Write-Host "Now generating new backup users ..." -BackgroundColor DarkGreen
For ($i = $StartFrom; $i -le $TotalAccounts; $i++) {
  $FirstName = "VeeamBackup"
  $LastName = "Account" + $i
  $PrincipalName = $DisplayName.ToLower() + $i + "@" + $Domain

  $CheckUser = Get-MsolUser -UserPrincipalName $PrincipalName -ErrorAction SilentlyContinue
  
  if ($checkUser) {
    Write-Host "Account $DisplayName$i already exists. Exiting script to prevent unwanted changes." -BackgroundColor DarkRed
    Exit
  }
  
  Write-Host "Adding account: $DisplayName$i" -BackgroundColor DarkGreen
  $newUser = New-MsolUser -DisplayName $DisplayName$i -FirstName $FirstName -LastName $LastName -UserPrincipalName $PrincipalName -ForceChangePassword $false -PasswordNeverExpires $true -StrongPasswordRequired $false -Password $Password -ErrorAction SilentlyContinue
  $AccountsArray += ,@($PrincipalName, $Password)

  Write-Host "Adding account $DisplayName$i to security group $SecurityGroup." -BackgroundColor DarkGreen
  Add-MsolGroupMember -GroupObjectId $SecGroup.ObjectId -GroupMemberType User -GroupMemberObjectId $newUser.ObjectId
}

Write-Host "Sleeping for 60 seconds to prevent sync issues for users." -BackgroundColor DarkGray
Start-Sleep -Seconds 60

$Members = Get-VBOOrganizationGroupMember -Group $Group

Write-Host "Configuring new Backup Accounts for Veeam Backup for Microsoft Office 365..." -BackgroundColor DarkGreen

For ($j = 0; $j -lt $AccountsArray.Length; $j++) {
  ForEach ($Member in $Members) {
    if ($Member.Login -eq $AccountsArray[$j][0]) {
      Write-Host "Setting Backup Account password for new $Member." -BackgroundColor DarkGreen
      $SecurePassword = ConvertTo-SecureString -String $AccountsArray[$j][1] -AsPlainText -Force
      $BackupAccounts += New-VBOBackupAccount -SecurityGroupMember $Member -Password $SecurePassword
    }
  }
}

Write-Host "If the following command terminates with error 403, it's often just a sync issue." -BackgroundColor DarkGreen
Write-Host "Check your backup accounts in VBO365, they will still be correctly configured in most cases. Otherwise add the passwords manually." -BackgroundColor DarkGreen
Write-Host "Enabling Backup Accounts for Veeam Backup for Microsoft Office 365 for $OrganizationName, please wait ..." -BackgroundColor DarkGreen

Set-VBOOrganization -Organization $Org -BackupAccounts $BackupAccounts | Out-Null
