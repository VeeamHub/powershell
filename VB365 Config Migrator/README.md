# VB365 Configuration Export / Import Scripts

PowerShell scripts to back up and restore the configuration of a **Veeam Backup for Microsoft 365 (VB365)** server. Designed for migration, disaster recovery preparation, or standing up a replacement server with an identical configuration. The import does not cover everything so far, but this will grow over time.

---

## Scripts

| Script | Version | Purpose |
|---|---|---|
| `Export-VB365Config_v2.ps1` | v2 | Exports the full VB365 configuration to JSON files |
| `Import-VB365Config_v2.ps1` | v2 | Restores organizations, repositories, backup jobs, and backup copy jobs |

---

## Export-VB365Config_v2.ps1

### .SYNOPSIS

Exports the full configuration of a VB365 server to a timestamped folder of JSON files and PFX certificate files.

### .DESCRIPTION

Connects to a VB365 server (locally or remotely) and collects the following configuration data, writing each section to a separate JSON file:

- **Server information** — product version, installed components, license status
- **Global settings** — email notifications, internet proxy, REST API, security, restore portal, tenant and operator authentication, history retention, folder exclusions, RBAC roles, federated authentication authorities
- **Infrastructure** — backup proxy servers and proxy pools
- **Repositories** — local disk repositories and object storage repositories (Azure Blob, Amazon S3, S3-compatible); for object storage the account name, container/bucket name, folder name, and region are captured
- **Encryption keys** — key descriptions and hints (key material is not exportable)
- **Cloud credentials** — Azure service accounts, Azure Blob storage accounts, Amazon S3 accounts, S3-compatible accounts; account names and access keys are exported. **Secret keys are not** since they are stored encrypted inside VB365 and cannot be retrieved, you need to enter them manually during restore.
- **Organizations** — all registered Microsoft 365 organizations including region, backup application IDs, and authentication certificates (PFX files exported from the Windows certificate store)
- **Backup jobs** *(optional, requires `-IncludeJobs`)* — job name, linked organization and repository, schedule policy, all selected and excluded items with their workload flags (Mailbox, Archive Mailbox, OneDrive, SharePoint, Teams, Teams Chats)
- **Backup copy jobs** *(optional, requires `-IncludeJobs`)* — linked backup job, target repository, and schedule policy

Each backup job and backup copy job is written to its own file under a `Jobs\` subdirectory, named after the job.

### .PARAMETERS

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-OutputPath` | String | Yes | Root folder for the export. A timestamped subfolder (`VB365_Export_YYYYMMDD_HHmmss`) is created inside. |
| `-CertificatePassword` | SecureString | No | Password used to protect exported PFX files. Prompted interactively if omitted. |
| `-IncludeJobs` | Switch | No | Also exports backup job and backup copy job configuration. |
| `-Server` | String | No | VB365 server hostname or IP. Defaults to `localhost`. |
| `-Port` | Int | No | Management service port. Only needed if moved from the default. |
| `-Credential` | PSCredential | No | Credentials for the VB365 server. Omit to use the current Windows session. |

### .OUTPUT

```
VB365_Export_YYYYMMDD_HHmmss\
├── ServerInfo.json
├── ProxyServers.json
├── ProxyPools.json
├── EncryptionKeys.json
├── CloudCredentials.json
├── Repositories.json
├── Organizations.json
├── Certificates\
│   ├── BackupApp_<AppId>_<Thumbprint>.pfx
│   └── AzureServiceAccount_<AppId>_<Thumbprint>.pfx
└── Jobs\                          (only with -IncludeJobs)
    ├── BackupJob_<JobName>.json
    └── BackupCopyJob_<JobName>.json
```

### .NOTES

- Must be run on a machine with the `Veeam.Archiver.PowerShell` module installed (typically the VB365 server itself).
- Certificate PFX files are exported from the **local Windows certificate store**. If the script runs on a different machine than the one holding the certificates, PFX files will be missing. The thumbprint is still recorded in `Organizations.json` so certificates can be exported manually.
- Cloud account **secret keys are never exported** — they are stored encrypted inside VB365 and cannot be retrieved via PowerShell. They must be re-entered manually during restore.
- The export is read-only and makes no changes to the VB365 configuration.

### .EXAMPLE

```powershell
# Run locally on the VB365 server — includes jobs
.\Export-VB365Config_v2.ps1 -OutputPath C:\VB365_Backup -IncludeJobs

# Remote server with explicit credentials
$cred = Get-Credential
.\Export-VB365Config_v2.ps1 -Server vb365.corp.local -Credential $cred `
    -OutputPath D:\Exports -IncludeJobs
```

---

## Import-VB365Config_v2.ps1

### .SYNOPSIS

Restores VB365 configuration from an export folder onto a fresh or replacement VB365 installation.

### .DESCRIPTION

Reads the output produced by `Export-VB365Config_v2.ps1` and recreates the configuration in the following order:

1. **Organizations** — re-registers each Microsoft 365 organization using modern app-only authentication. The backup application certificate is imported from the exported PFX file. Organizations that already exist by name are skipped.

2. **Cloud storage accounts** — checks whether each account referenced by an exported repository already exists. If an account is missing it is created interactively: the script prompts once per unique account for the secret key (Shared Key for Azure Blob, Secret Access Key for Amazon S3 / S3-compatible). This step runs before any repository is created so all prompts are presented up front.

3. **Object storage repositories** — adds each exported object storage repository to the default backup proxy (the only proxy available on a fresh installation). Repositories are matched by name; existing ones are skipped. After all repositories are added the proxy is rescanned and each newly added repository is synchronised.

4. **Backup jobs** *(if `Jobs\BackupJob_*.json` files are present)* — recreates each backup job against the matching organization and repository (resolved by name). The schedule policy is reconstructed from the export. Selected and excluded items (users, groups, sites, teams) are resolved from the target organization by display name, UPN, or URL. Jobs whose organization or repository cannot be found on the target are skipped with a warning.

5. **Backup copy jobs** *(if `Jobs\BackupCopyJob_*.json` files are present)* — creates a backup copy job for each exported entry by locating the source backup job and target repository by name. The copy schedule policy is reconstructed. Copy jobs for a backup job that already has a copy job are skipped.

The script is **idempotent** — it can be re-run safely. Every resource is checked by name before creation and skipped if it already exists.

### .PARAMETERS

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-ImportPath` | String | Yes | The timestamped export subfolder produced by the export script (e.g. `C:\VB365_Backup\VB365_Export_20260630_120000`). |
| `-CertificatePassword` | String | Yes | Password that was set when the PFX files were exported. |
| `-Server` | String | No | VB365 server hostname or IP. Defaults to `localhost`. |
| `-Port` | Int | No | Management service port. Only needed if moved from the default. |
| `-Credential` | PSCredential | No | Credentials for the VB365 server. Omit to use the current Windows session. |
| `-SyncRepositories` | Switch | No | After adding repositories, rescan the proxy and start a synchronisation session for each new repository. Off by default. |
| `-WhatIf` | Switch | No | Shows what would be done without making any changes. |

### .OUTPUT

Progress is written to the console with colour-coded status tags:

| Tag | Meaning |
|---|---|
| `[OK]` | Resource created or action succeeded |
| `[SKIP]` | Resource already exists — no action taken |
| `[WARN]` | Non-fatal issue (e.g. an item could not be resolved) |
| `[FAIL]` | Resource could not be created — see message for reason |

A summary table is printed at the end showing counts for each resource type.

### .NOTES

- Must be run on a machine with the `Veeam.Archiver.PowerShell` module installed.
- **Cloud account secret keys must be available** at run time. The script will prompt for them interactively if the account does not already exist. Have the keys ready before starting the import.
- Object storage repositories are assigned to the **default (first) backup proxy**. On a fresh installation this is the only available proxy. If proxy pools are required they must be configured manually after the import.
- Backup job items (users, groups, sites, teams) are resolved by **display name, UPN, or URL** against the target organization. If an object has been renamed or removed in the Microsoft 365 tenant since the export was taken, it will not resolve and a warning is shown. The job is still created with all items that did resolve.
- **Repository and organization matching uses names, not IDs.** IDs change when a resource is recreated on a new server. Ensure repository and organization names on the target match those in the export.
- Import v1 (`Import-VB365Config_v1.ps1`) covers only organizations and repositories. Use v2 for full restore including jobs.

### .EXAMPLE

```powershell
# Basic restore on the local VB365 server
.\Import-VB365Config_v2.ps1 `
    -ImportPath "C:\VB365_Backup\VB365_Export_20260630_120000" `
    -CertificatePassword (Read-Host -AsSecureString "PFX password")

# Dry run — see what would happen without making changes
.\Import-VB365Config_v2.ps1 `
    -ImportPath "C:\VB365_Backup\VB365_Export_20260630_120000" `
    -CertificatePassword (Read-Host -AsSecureString "PFX password") `
    -WhatIf
```

---

## Requirements

- **Veeam Backup for Microsoft 365** v8 or later
- **PowerShell** 5.1 or later
- `Veeam.Archiver.PowerShell` module (installed automatically with VB365)
- Scripts must run on the VB365 server, or with network access to a remote VB365 server
- For certificate export: the backup application PFX must be present in the **local Windows certificate store** of the machine running the export script

## Limitations

- Cloud account secret keys, encryption key material, and user passwords are **never exported** — they must be re-entered manually
- Proxy pool assignments are not restored — repositories are added to the default proxy only
- On-premises hybrid organization components are not covered
- RBAC role assignments and federated authority configuration are exported for reference but not automatically restored by the import scripts
