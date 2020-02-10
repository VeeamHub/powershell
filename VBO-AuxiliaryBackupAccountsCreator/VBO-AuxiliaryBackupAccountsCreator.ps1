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
#>

# Modify the values below to your needs
# Number of accounts to add - advised is to add in bulk of 8 accounts
[Int]$Accounts = 8

# Number to start from (change this if you are adding extra accounts)
[Int]$StartFrom = 1

# Display Name for the accounts (these will get a number at the end, eg VeeamBackupAccount1, VeeamBackupAccount2)
$DisplayName = "VeeamBackupAccount"

# Your domain name
$Domain = "yourdomain(.onmicrosoft).com"

# Your security group name
$SecurityGroup = "VBO"

# Organization name as configured in Veeam Backup for Microsoft Office 365
$OrganizationName = "yourdomain(.onmicrosoft).com"

# Do not change below unless you know what you are doing
if ((Get-InstalledModule -Name "MSOnline" -ErrorAction SilentlyContinue) -eq $null) {
    Install-Module -Name MSOnline
}

Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"
Import-Module -Name MSOnline

# Connect to Office 365
Write-Host "Provide your Office365 Admin Account Credentials" -BackgroundColor DarkGreen
Connect-MsolService -Credential $Credential

Write-Host "Connecting to AzureAD..." -BackgroundColor DarkGreen
Write-Host "Adding accounts..." -BackgroundColor DarkGreen

[Int]$TotalAccounts = $StartFrom + $Accounts - 1
$AccountsArray = @()

For ($i = $StartFrom; $i -le $TotalAccounts; $i++) {
  $FirstName = "VeeamBackup"
  $LastName = "Account" + $i
  $PrincipalName = $DisplayName.ToLower() + $i + "@" + $Domain

  $Length = Get-Random -Minimum 8 -Maximum 16
  $NonAlphaChars = 3
  $Password = [System.Web.Security.Membership]::GeneratePassword($Length, $NonAlphaChars)

  $CheckUser = Get-MsolUser -UserPrincipalName $PrincipalName -ErrorAction SilentlyContinue
  
  if ($checkUser) {
    Write-Host "Account $DisplayName$i already exists. Exiting script to prevent unwanted changes." -BackgroundColor DarkRed
    Exit
  }

  $SecGroup = Get-MsolGroup -GroupType Security | Where-Object { $_.DisplayName -eq $SecurityGroup}

  if (!$secGroup) {
    $secGroup = New-MsolGroup -DisplayName $SecurityGroup -Description "Veeam Backup for Microsoft Office 365 Auxiliary Backup Accounts group" -ErrorAction SilentlyContinue
  }
  
  Write-Host "Adding account: $DisplayName$i" -BackgroundColor DarkGreen
  $newUser = New-MsolUser -DisplayName $DisplayName$i -FirstName $FirstName -LastName $LastName -UserPrincipalName $PrincipalName -ForceChangePassword $false -PasswordNeverExpires $true -StrongPasswordRequired $false -Password $Password -ErrorAction SilentlyContinue
  $AccountsArray += ,@($PrincipalName, $Password)

  Write-Host "Adding account $DisplayName$i to security group $SecurityGroup." -BackgroundColor DarkGreen
  Add-MsolGroupMember -GroupObjectId $SecGroup.ObjectId -GroupMemberType User -GroupMemberObjectId $newUser.ObjectId
}

Write-Host "Sleeping for 60 seconds to prevent sync issues." -BackgroundColor DarkGray
Start-Sleep -Seconds 60

# Connect to Veeam Backup for Microsoft Office 365
Write-Host "Connecting to Veeam Backup for Microsoft Office 365..." -BackgroundColor DarkGreen

$Org = Get-VBOOrganization -Name $OrganizationName
$Group = Get-VBOOrganizationGroup -Organization $Org -Name $SecurityGroup
$Members = Get-VBOOrganizationGroupMember -Group $Group
$BackupAccounts = @()

Write-Host "Configuring Backup Account for Veeam Backup for Microsoft Office 365..." -BackgroundColor DarkGreen

For ($j = 0; $j -lt $AccountsArray.Length; $j++) {
  ForEach ($Member in $Members) {
    if ($Member.Login -eq $AccountsArray[$j][0]) {
      Write-Host "Setting Backup Account password for $Member." -BackgroundColor DarkGreen
      $SecurePassword = ConvertTo-SecureString -String $AccountsArray[$j][1] -AsPlainText -Force
      $BackupAccounts += New-VBOBackupAccount -SecurityGroupMember $Member -Password $SecurePassword
    }
  }
}

Write-Host "Enabling Backup Accounts for Veeam Backup for Microsoft Office 365 for $OrganizationName." -BackgroundColor DarkGreen
Set-VBOOrganization -Organization $Org -BackupAccounts $BackupAccounts | Out-Null

# Wipe the Accounts array
$AccountsArray = @()