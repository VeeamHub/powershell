<#
.SYNOPSIS

Get-BackupProtectionSingleTenant.ps1

.DESCRIPTION

Allows you to select Backup Protection Tenant account and return total storage in GB and cost of storage to the provider and to the client.
Folder Calculation code taken from https://www.gngrninja.com/script-ninja/2016/5/24/powershell-calculating-folder-sizes

.VERSION HISTORY:

0.1 - First Pass

LIMITATIONS:

- Not aware of multiple SOBR extents so limited to single repository for Base Path
- No checking if entered in value for tenant is correct. Incorrect value will exit.
- Need to round storage costs down to two decimal places

KEY VARIABLES

- $BaseParth = Path to _RecycleBin
- $StorageCost = Cost of storage to you
- $StorageCharge = What are you charging your customer

#>
 
# Path of the _RecycleBin folder as per your repository
$BasePath = 'E:\Backups\_RecycleBin\'

if (!(get-pssnapin -name VeeamPSSnapIn -erroraction silentlycontinue)) {
 add-pssnapin VeeamPSSnapIn
}
 
# This section commented out. Uncomment to prompt for Storage costs
#Write-Host ""
#Write-Host "Enter in your Storage Costs"

#$StorageCostString = Read-Host "Cost of Storage per GB"
#$StorageChargeString = Read-Host "Storage Charge per GB"

#$StorageCost = $StorageCostString
#$StorageCharge = $StorageChargeString

#Hardcoded cents per GB. Comment out if above section is in use
$StorageCost = 0.03
$StorageCharge = 0.09

# Select the Tenant Account
clear
Write-Host ""
Write-Host "Get Total Insider Protection Storage and Storage Costs for a Single Tenant" -ForegroundColor Green
write-host ""
 
Write-Host "Gathering all Tenant Accounts from Cloud Connect Server with Backup Protection Enabled:"
Get-VBRCloudTenant | Where { $_.BackupProtectionEnabled -eq "True" } | FT Name
write-host "-----------------------------------------------------------"
Write-Host "Note: No Erorr Checking so incorrect tenant value will exit" -ForegroundColor Red
write-host "-----------------------------------------------------------"
write-host ""
$foldername = read-host "Enter the Tenant Account"

# Get a list of all the directories in the base path we're looking for.
$folder = Get-ChildItem $basePath -Directory -Force | Where-Object {($_.BaseName -like $FolderName) -and ($_.FullName -notin $OmitFolders)}

    #Store the full path to the folder and its name in separate variables
    $fullPath = $folder.FullName
    $folderBaseName = $folder.BaseName                

    #Get folder info / sizes
    $folderSize = Get-Childitem -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue       
        
    #Perform strong to decimal conversions and do some PS Math to get bytes to GB
    $foldersizeInt = [int64]($folderSize.Sum)
    $folderSizeInGB = (($foldersizeInt/1024)/1024)/1024

    #Get some more Tenant info
    $tenant = Get-VBRCloudTenant -Name $folderBaseName

    #Print out the results 
     write-host""
     write-host "Tenant Account   : $folderBaseName"
     write-host "Size in GB       :"$([math]::round(($folderSizeInGB),2))""
     write-host "Storage Costs    :"$([math]::round(($StorageCost*$folderSizeInGB),2))""
     write-host "Billable Amount  :"$([math]::round(($StorageCharge*$folderSizeInGB),2))""
     write-host "Retention Period :"$tenant.BackupProtectionPeriod