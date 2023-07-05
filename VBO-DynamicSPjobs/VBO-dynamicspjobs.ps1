<# 
.NAME
    Veeam Backup for Microsoft Office 365 Dynamic SP Jobs
.SYNOPSIS
    Script to use for automatically adding SharePoint Sites to a backup job
.DESCRIPTION
    Script to use for dynamically creating and adding SharePoint Sites to a backup job based upon the first letter of the site name
    Schedule with task manager to run daily to capture new sites
    Created for Veeam Backup for Microsoft Office 365 v4
    Released under the MIT license.
.LINK
    https://github.com/tsmithco
#>

<# 
.INSTRUCTIONS
    Modify the repository name in the script to the desired target repository name.
    Run the script daily via task scheduler.
#>


#Import the VBO PS module
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

#connect to the organization (assuming 1 org)
$Org = Get-VBOOrganization 


#Modify the target repository name below
$repo = Get-VBOrepository -name "minio"

#Get all sites within the organization that are not personal SP sites, and that are not already in a backup job.
$Sites = Get-VBOOrganizationSite -org $org -IncludePersonalSite:$false -NotInJob


#Job name as a string and as integers so it can be incremented to the next letter
$SPjob=[int[]][char[]]'SP-A'
$letter=[char[]]$SPjob -join ""


$i=0
while ($i -lt 26){

#Filter set to anything that starts with the 4th character of the job name, "A" to begin with.
$filter = '^' + ([char[]]$SPjob[3])

ForEach ($Site in $Sites) {
  $FilteredSite = $Site.Name -match "$Filter"

  # Only add the sites if the filter is True
  if ($FilteredSite) {
    $newSite = New-VBOBackupItem -Site $Site

    #Attempt to create the backup job for the filtered letter if it doesn't exist.
    try{
        $job = Add-VBOJob -Organization $org -Name $letter -repo $repo -SelectedItems $newSite
        }
    #If the job exists, add the site to the existing job
    catch{
       $job = Get-VBOJob -name $letter
       Add-VBOBackupItem -Job $Job -BackupItem $newSite
       }
  }
}

#Increment the job name's 4th character to the next letter.
    $SPjob[-1]++
    $letter=[char[]]$SPjob -join ""

    $i++

}
