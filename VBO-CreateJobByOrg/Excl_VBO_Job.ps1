$VeeamBackupJobName = "Job Name"
$VeeamRepository = "Repository name"
$OrgUnit = "DC=ACME,DC=local"
$username = "0365admin@acme.local"
$pwdTxt = Get-Content "C:\temp\ExportedPassword.txt"
$securePwd = $pwdTxt | ConvertTo-SecureString -AsPlainText -Force
$exc_cred = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securePwd
#$exc_cred = Get-Credential                                         # Comment out to use interactive authentication
$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $exc_cred -Authentication Basic -AllowRedirection
Import-PSSession $session


$org = Get-VBOOrganization                                         # Returns Exchange Organization
if ($org -eq $null) {
    Write-host "No Exchange organization is defined!"
    exit 1
}
$repository = Get-VBORepository -Name $VeeamRepository             # Veeam O365 Repository
if ($repository -eq $null) {
    Write-host "Repository $VeeamRepository does not exist."
    exit 1
}

# O365 PowerShell call - Return all Exchange Mailboxes
Try
{
    $MailBoxes = Get-VBOOrganizationMailbox -Organization $org
}
Catch
{
    Write-Host "No mailboxes defined!"
    Exit 1
}

# Exchange Online Powershell call - Return all Exchange Mailboxes under the Organizational Unit $OrgUnit defined above.
Try
{
  $mbxs = @()
  $no_licensed_user = @()
  foreach ($user in Get-ADUser -Filter * -SearchBase $OrgUnit){
      $found = Get-Mailbox -Identity $user.Name
      if ($found -eq $null){
        $no_licensed_user += @($found)
      } else {
        $mbxs += @($found)
      }
  }

  Write-Host "Users with no licensed mailbox will be skipped:"
  Write-Host $no_licensed_user
}
Catch
{
    Write-Host "No mailboxes within $OrgUnit defined!"
    Exit 1
}

$FinalList = @()

#Nested for loop to compare the contents of the Exchange list vs. the Get-VBOOrg..list. Only add matches based
#on email address.
$i=1
ForEach ($MailBox in $MailBoxes) {
  Write-Progress -Activity "Parsing Mailboxes" -status "Mailbox $Mailbox.Email" -percentComplete ($i / $Mailboxes.count * 100)
  ForEach ($mbx in $mbxs) {
     if ($MailBox.Email -match $mbx.UserPrincipalName) {
#         Write-Host $mbx.EmailAddresses[0].AddressString
         $FinalList += @($MailBox)
     }
  }
  $i=$i+1
}
Write-Progress -Activity "Parsing Mailboxes" -Completed

If ($JobId = Get-VBOJob -Name $VeeamBackupJobName) {
    write-host "Job Exists! Updating Job"
    $results = Set-VBOJob -Job $JobId -Repository $repository -AllMailBoxes -ExcludedMailboxes $FinalList
} else {
    $results = Add-VBOJob -Name  $VeeamBackupJobName -AllMailBoxes -Organization $org -Repository $repository -ExcludedMailboxes $FinalList
}


Write-Host "Number of Mailboxes Excluded from Organizational Unit $OrgUnit = " $mbxs.count
