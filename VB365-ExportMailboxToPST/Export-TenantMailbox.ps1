<#
.SYNOPSIS
    Exports an M365 user mailbox to PST via Cloud Connect

.DESCRIPTION
    The script is designed to be executed on a VBR server with the Exchange Explorer installed &
    configured as defined in Veeam documentation (see link below). It's interactive so no
    parameters are required. Upon execution, the script polls for information which culminates
    in the specified user mailbox being exported to a PST file.

.OUTPUTS
    Export-TenantMailbox returns string output to guide the user

.EXAMPLE
    Export-TenantMailbox.ps1

	Description
    ------------
    Exports a user mailbox to a PST file

.NOTES
	NAME:  Export-TenantMailbox.ps1
	VERSION: 0.4
    AUTHOR: Chris Arceneaux
	TWITTER: @chris_arceneaux
	GITHUB: https://github.com/carceneaux

.LINK
    https://helpcenter.veeam.com/docs/vbo365/guide/vbo_baas_tenant.html?ver=60

.LINK
    https://helpcenter.veeam.com/docs/backup/explorers_powershell/veeam_explorer_for_microsoft_exchange.html?ver=110

.LINK
	https://arsano.ninja/

#>

$ErrorActionPreference = "Stop"

Import-Module Veeam.Archiver.PowerShell
Import-Module Veeam.Exchange.PowerShell

function Set-EmailAddress()
{
    # specifying email address of user
    Write-Host ""
    $address = Read-Host  "Enter email address of user mailbox"
    return $address
}

# welcome message
Clear-Host
Write-Host "Export-TenantMailbox.ps1" -ForegroundColor Green
Write-Host "-----------------------"
Write-Host "WARNING: This script exports the specified user mailbox to a PST file." -ForegroundColor Yellow
Write-Host "If you do not want to do this, please quit." -ForegroundColor Yellow
#Timeout /NoBreak 10
Write-Host ""
Write-Host ""

# choosing organization
$orgs = Get-VBOOrganization | Sort-Object Name
for($i=0; $i -lt $orgs.count; $i++){Write-Host $i "-" $orgs[$i].name}
Write-Host ""
$orgNumber = Read-Host  "Enter organization number"
$org = $orgs[$orgNumber]

# no org chosen
if ($org -eq $null)
{
    Write-Error "No Organization chosen. Quitting script now."
    Exit
}

# setting email address
$email = Set-EmailAddress

# starting exchange restore session
$session = Start-VBOExchangeItemRestoreSession -LatestState -Organization $org -ShowDeleted -Reason "Exporting employee ($email) data to PST"

# if anything fails, stop the restore session so it doesn't remain open
try
{
    $selection = $null
    while ($selection -eq $null)
    {
        # retrieving user mailbox
        $database = Get-VEXDatabase -Session $session
        $mailbox = Get-VEXMailbox -Database $database -Name $email

        # check if mailboxes found
        if ($mailbox -eq $null)
        {
            # no mailbox found
            Write-Warning "No mailboxes found for search: $email"
            Write-Host ""
            $question = 'Would you like to re-enter the email address?'
            $choices  = '&Yes', '&No'

            $decision = $Host.UI.PromptForChoice("", $question, $choices, 1)
            if ($decision -eq 0)
            {
                # yes
                $email = Set-EmailAddress
            }
            else
            {
                # no, stopping restore session and quitting
                $session = Get-VBORestoreSession -Id $session.Id
                Stop-VBORestoreSession -Session $session
                Exit
            } #end if $decision
        } 
        else
        {
            # mailbox(es) found
            if ($mailbox.Count -gt 1)
            {
                Write-Host "Multiple mailboxes ($($mailbox.Count)) found!" -ForegroundColor Green
                Write-Host ""
                # choosing mailbox
                for($i=0; $i -lt $mailbox.count; $i++)
                {
                    # creating an object for each mailbox
                    New-Object PSObject -Property ([ordered]@{
                        Mailbox = $i
                        Id = $mailbox[$i].Id
                        Name = $mailbox[$i].Name
                        Email = $mailbox[$i].Email
                        IsDeleted = $mailbox[$i].IsDeleted
                        IsArchive = $mailbox[$i].IsArchive
                    })
                } # end for loop
                Write-Host ""
                $boxNumber = Read-Host  "Enter mailbox number"
                $selection = $mailbox[$boxNumber]
            }
            else
            {
                Write-Host "Mailbox found!" -ForegroundColor Green
                $selection = $mailbox
            } # end if single/multiple mailbox found
        } # end if $mailbox
    } # end while loop
    
    # specifying location of PST
    Write-Host ""
    Write-Host "Example: C:\North Backup\Sales\Sales.pst" -ForegroundColor Yellow
    Write-Host ""
    $location = Read-Host  "Enter location of the new PST"

    # exporting mailbox to pst location
    Write-Host ""
    Write-Host "Exporting mailbox: ($($selection.Name) - $($selection.Email)) to $location"
    Export-VEXItem -Mailbox $selection -To $location

    # stopping restore session
    $session = Get-VBORestoreSession -Id $session.Id
    Stop-VBORestoreSession -Session $session
    Exit
    
}
catch
{
    Write-Error "Error encountered. Stopping restore session.`n$_" -ErrorAction Continue
    
    # stopping restore session
    $session = Get-VBORestoreSession -Id $session.Id
    Stop-VBORestoreSession -Session $session
    Exit
}
