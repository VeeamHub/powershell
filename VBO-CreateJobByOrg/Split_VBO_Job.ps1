Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn;

# This scipt is just an example of how to create multiple VBO Jobs, spliting up the
# mailboxes within an Organization. Currenly it only points to one repository.
# It could be further enhanced to create jobs with multiple unique repositories.

$VeeamBackupJobName = "Backup Job "
$VeeamRepository = "MailBackup"
$OrgUnit = "DC=ACME,DC=local"

Write-Host "The following script will create multiple VBO jobs based on the input value below."
Write-Host "For example, if you have 2000 users and select 10 jobs, it will create"
Write-Host "10 VBO jobs with 200 users per job."


$NumberOfJobs = Read-Host -Prompt 'How many backups jobs do  you want to define'
                                    

$org = Get-VBOOrganization                                         # Retruns Exchange Organization
if ($org -eq $null) {
    Write-host "No Exchange organization is defined!"
    exit 1
}
$repository = Get-VBORepository -Name $VeeamRepository             # Veeam O365 Repository
if ($repository -eq $null) {
    Write-host "Repository $VeeamRepository does not exist."
    exit 1
}

# O365 PowerShell call - Retrieve all Exchange Mailboxes (and only return regular users)
Try
{
    $MailBoxes = Get-VBOOrganizationMailbox -Organization $org | Where-Object {$_.Name -ne "Administrator" -and $_.Name -ne "Discovery Search Mailbox"} | Sort-Object Name
}
Catch
{
    Write-Host "No mailboxes defined!"
    Exit 1
}



$FinalList = @()
$JobNumber = 1
$MailboxNum = 0
$MailPerJob = [decimal]::ceiling($MailBoxes.count / $NumberOfJobs)

Write-Host "Found " $MailBoxes.count " mailboxes"
Write-Host "Will create" $NumberOfJobs "VBO Jobs with" $MailPerJob "users per job"

#Nested for loop to compare the contents of the Exchange list vs. the Get-VBOOrg..list. Only add matches based
#on email address.
$i=1
ForEach ($MailBox in $MailBoxes) {
  Write-Progress -Activity "Parsing Mailboxes" -status "Mailbox $Mailbox.Email" -percentComplete ($i / $Mailboxes.count * 100)

  $FinalList += @($MailBox)
  $MailBoxNum=$MailBoxNum+1  

  Write-Host "Adding user " $MailBox

  if ($MailBoxNum -ge $MailPerJob) {
    If ($JobId = Get-VBOJob -Name $VeeamBackupJobName$JobNumber) {
        write-host "Job Exists! Updating Job"
        $results = Set-VBOJob -Job $JobId -Repository $repository -SelectedMailboxes $FinalList
    } else {
        $results = Add-VBOJob -Name  $VeeamBackupJobName$JobNumber -Organization $org -Repository $repository -SelectedMailboxes $FinalList
    }
    
    $FinalList = @()
    $MailboxNum = 0
    $JobNumber = $JobNumber+1
   }

  
  $i=$i+1
}
Write-Progress -Activity "Parsing Mailboxes" -Completed


    If ($JobId = Get-VBOJob -Name $VeeamBackupJobName$JobNumber) {
        write-host "Job Exists! Updating Job"
        $results = Set-VBOJob -Job $JobId -Repository $repository -SelectedMailboxes $FinalList
    } else {
        $results = Add-VBOJob -Name  $VeeamBackupJobName$JobNumber -Organization $org -Repository $repository -SelectedMailboxes $FinalList
    }

