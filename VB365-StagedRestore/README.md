# Staged, Resumable Restore of SharePoint & OneDrive Content

## Author

* Jim Jones (@k00laidIT)

## Function

This script performs a staged, resumable batch restore of SharePoint or OneDrive
content from Veeam Backup for Microsoft 365 (VB365) v8. It is built for very
large sites and drives where a single monolithic restore is fragile: it restores
a configurable number of direct children at a time, lets you stop whenever you
want, and resumes later without re-restoring anything already processed.

A fresh run walks you through numbered menus: organization → backup job →
restore point. The script then detects whether that restore point holds
SharePoint data, OneDrive data, or both, and offers only what is present — then
site → library → folder (SharePoint) or user → folder (OneDrive). Your selections
are saved to a JSON config file next to the script *before* anything is restored,
so a run can always be resumed with `-ConfigPath`.

Batching: the direct children of the chosen folder are sorted by name and
restored `-Items` at a time (default 500). A file counts as one item; a subfolder
counts as one item and is restored **recursively** within that batch. The script
never passes `-RestoreChangedItems`, so items already present in the target are
skipped (the VB365 default) — re-runs are safe and never duplicate content.
Between batches you choose to continue, restore all remaining, or quit and save.

## Known Issues

* *No known issues*

## Requirements

* Veeam Backup for Microsoft 365 v8
  * *Other versions are untested*
* Must be executed on the VB365 server (or a machine with the VB365 console)
* **PowerShell 7 (`pwsh.exe`)** — enforced by a `#Requires -Version 7.0`
  statement. The VB365 SharePoint module's dependencies fail to load under
  Windows PowerShell 5.1 (`powershell.exe`).
* An account with VB365 restore rights
* The organization must use **application-based (modern) authentication** — the
  script reads `ApplicationId` and `ApplicationCertificateThumbprint` from
  `$organization.Office365SharePointConnectionSettings`. OneDrive restores reuse
  these same organization app credentials.
* The application certificate must be present in `LocalMachine\My` or
  `CurrentUser\My` with an **exportable private key** (the script exports a
  temporary PFX because the restore cmdlets require a PFX path and have no
  thumbprint parameter). If the key is not exportable, export the PFX yourself
  and pass it with `-PfxPath`; the script validates its thumbprint against the
  organization's configured certificate before restoring.

## Usage

Script contains built-in documentation which can be accessed using the typical
PowerShell method:

```powershell
Get-Help .\Start-VBOStagedRestore.ps1 -Full
```

The script is interactive. A dry run first is strongly recommended — it runs the
full wizard, produces the batch plan, and writes the config file, all without
restoring anything:

```powershell
# Dry run: full wizard + batch plan + logging, zero restores
.\Start-VBOStagedRestore.ps1 -DryRun

# Fresh interactive run, 500 items per batch (auto-detects SharePoint/OneDrive)
.\Start-VBOStagedRestore.ps1

# Smaller batches, remote VB365 server, pre-supplied SharePoint site
.\Start-VBOStagedRestore.ps1 -Server vb365.corp.local -Items 250 -SiteUrl https://tenant.sharepoint.com/sites/big

# Resume a previous run (config file is written next to the script)
.\Start-VBOStagedRestore.ps1 -ConfigPath .\stagedRestore-BigSite.config.json

# Resume with a different batch size
.\Start-VBOStagedRestore.ps1 -ConfigPath .\stagedRestore-BigSite.config.json -Items 1000
```

### Parameters

| Parameter | Default | Purpose |
|---|---|---|
| `-Server` | `localhost` | VB365 server; remote servers prompt for credentials |
| `-Items` | `500` | Direct children restored per batch |
| `-ConfigPath` | — | Resume from a saved config file |
| `-PfxPath` | — | Manual app-cert PFX (fallback when store export fails) |
| `-SiteUrl` / `-LibraryName` / `-FolderPath` | — | Pre-supply SharePoint wizard selections (e.g. `-FolderPath /Reports/2024/`); `-FolderPath` also applies to OneDrive |
| `-DryRun` | off | Everything except the restore calls |
| `-RestorePermissions` | off | Also restore item permissions/shared access (notifications suppressed) |
| `-DiagnoseDetection` | off | Dump full data-type probe detail when detection is unexpected |

### Files produced (next to the script)

* `stagedRestore-<name>.config.json` — resumable state: selections plus processed
  items (`<name>` is the site name for SharePoint, the user name for OneDrive).
  Rewritten after every batch. Never contains passwords.
* `stagedRestore-<name>.log` — append-mode log shared across sessions: each file
  individually, `FOLDER: <name> -- restored recursively` for subfolders, target
  boundaries, batch boundaries, and errors.

### Suggested first live run

1. `-DryRun` to validate the whole chain and review the batch plan in the log.
2. A real run against a small test folder with `-Items 5` to verify restore,
   skip-existing, quit/resume, and logging behavior.
3. The full staged recovery.

## Out of scope

Generic SharePoint lists (announcements, tasks), changed/deleted item versions,
alternate-location or cross-user restores, and Exchange/Teams/Groups data. This
script covers SharePoint document libraries and OneDrive drives only.
