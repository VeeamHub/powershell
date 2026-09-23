# VB365 EWS Enablement

`vb365-EwsEnablement.ps1` grants a Veeam Backup for Microsoft 365 (VB365) organization's
Exchange Online app registration access to EWS, without disturbing any other app IDs
already allow-listed in the tenant.

Microsoft 365 tenants can restrict EWS (Exchange Web Services) access to a specific list
of application IDs (`EwsAllowedAppIDs`). If a VB365 organization's Azure AD app isn't on
that list — or EWS is disabled tenant-wide (`EwsEnabled`) — VB365 can fail to back up or
process Exchange Online mailboxes for that organization. This script finds the app ID
VB365 is actually using, checks it against the current Exchange Online configuration, and
adds it if needed.

> This script was created with the assistance of an AI coding tool (Claude/Anthropic).
> Review and test it in a lab environment before relying on it in production; provided
> as-is, with no warranty.

## What it does

1. Loads both required modules up front (see [Requirements](#requirements)): imports
   `Veeam.Archiver.PowerShell` by module manifest path, then installs
   `ExchangeOnlineManagement` (if missing) and imports it. Verifies both modules actually
   loaded and prints a confirmation; if either failed to load, the script stops with an
   error before doing anything else.
2. Connects to the VB365 server (prompting for a server name if not already connected) and
   lists all configured organizations.
3. Prompts you to select an organization by number.
4. Reads that organization's Exchange Online application ID from
   `$org.Office365ExchangeConnectionSettings.ApplicationId` and displays it.
5. Asks for confirmation before making any changes to Exchange Online. Answering "n"
   disconnects from VB365 and exits without touching Exchange Online.
6. Disconnects from VB365 and connects to Exchange Online (`Connect-ExchangeOnline`).
7. Displays the tenant's current `EwsEnabled` status. If it isn't `$true`, asks whether to
   enable it and, if confirmed, runs `Set-OrganizationConfig -EwsEnabled $true`.
8. Displays the tenant's current `EwsAllowedAppIDs` list.
9. Checks whether the VB365 organization's application ID is already in that list:
   - If it is, reports that no change is needed.
   - If it isn't, asks for confirmation and, if confirmed, **appends** the ID to the
     existing list (never overwrites it) and writes the result back with
     `Set-OrganizationConfig -EwsAllowedAppIDs`.
10. Re-reads and displays `EwsAllowedAppIDs` again so you can verify the change.

`Set-OrganizationConfig -EwsAllowedAppIDs` replaces the entire value rather than appending
to it, so the script always merges the new ID into the existing comma-separated list
in-memory before writing it back — existing application IDs are never lost.

## Requirements

- PowerShell 7 (enforced via `#Requires -Version 7.0`)
- The `ExchangeOnlineManagement` module (installed automatically for the current user if
  not already present)
- The `Veeam.Archiver.PowerShell` module (part of the VB365 console install), imported by
  its module manifest (`.psd1`) path rather than by module name — this avoids a pwsh 7
  issue where the Windows PowerShell compatibility/implicit-remoting layer silently drops
  `-Confirm:$false` on some VB365 cmdlets
- Permissions to connect to both the VB365 server and Exchange Online (Exchange
  administrator or equivalent role)

## Parameters

| Parameter              | Default                                                                                  | Description                                    |
|------------------------|--------------------------------------------------------------------------------------------|-------------------------------------------------|
| `-ArchiverModulePath`  | `C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1` | Path to the `Veeam.Archiver.PowerShell` module manifest. Override if VB365 is installed to a non-default location. |

## Usage

```powershell
./vb365-EwsEnablement.ps1
```

Run interactively; the script prompts for the VB365 server (if not already connected),
the organization to process, and confirmation (y/n) before each change to Exchange Online.

If VB365 is installed to a non-default path:

```powershell
./vb365-EwsEnablement.ps1 -ArchiverModulePath 'D:\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1'
```

## Notes

- The script only reads from VB365 (no VB365 configuration is changed) and disconnects
  from the VB365 server before connecting to Exchange Online.
- No changes are made to Exchange Online unless you confirm each prompt.
- The script does not disconnect the Exchange Online session (`Disconnect-ExchangeOnline`)
  at the end; close it yourself if needed.

## Author

- **Author:** David Bewernick
- **Last Modification Date:** 2026-09-17
- **License:** MIT
