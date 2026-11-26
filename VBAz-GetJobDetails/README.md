# Get VBAz Job Details
PowerShell script that connects to a Veeam Backup for Microsoft Azure (VBAz) appliance through the REST API and exports the configuration of all backup policies (jobs): retention settings, protected regions and target repositories. Results go to the console, a CSV file and raw JSON files.

## Important note
Please be aware that the provided code is only an example and is not officially tested or supported by Veeam or Microsoft. Use it at your own risk and test it in a lab environment first.

> This script was created with the assistance of an AI coding tool (Claude/Anthropic).
> Review and test it in a lab environment before relying on it in production. It is provided as-is, with no warranty.

## Features
- Signs in to the appliance with `https://<appliance>/api/oauth2/token` (password grant).
- Finds the newest working REST API version (`v8` down to `v4`) automatically, or uses the version you pass with `-ApiVersion`.
- Reads the policies of all supported workload types:
  - Virtual machines
  - SQL
  - File shares
  - Cosmos DB
  - PostgreSQL
  - MySQL

  Workload types that the appliance or API version does not support are skipped.
- Handles paging (`offset`/`limit`) and loads the full object of every policy.
- Resolves repository IDs to repository name, storage account, region and storage tier.
- Collects retention and repository settings generically, so the script keeps working when the schema changes a little between VBAz versions:
  - **Retention:** every value inside a `*Schedule` object whose name contains `retention` or `ToKeep`, or ends with `Count`, `Duration` or `Type`.
  - **Repositories:** every property whose name ends with `RepositoryId`.
  - **Regions:** every property whose name contains `region`.
- Writes warnings when it cannot find a region or storage account. Each warning lists the property names that are available, so you can adjust the mapping.

## Output
Folder: `vbaz-export_<yyyyMMdd-HHmmss>` next to the script (change it with `-OutDir`).

| File | Content |
|---|---|
| `policies-retention.csv` | One row per policy, with the columns listed below |
| `policies.raw.json` | Full policy objects from the API, grouped by workload type |
| `repositories.raw.json` | Full repository objects from the API |

Use the raw JSON files to check the values in the CSV, or to find properties that the script does not map yet.

### CSV columns
| Column | Description | Example |
|---|---|---|
| Policy | Policy name | `VM-Daily-Prod` |
| Type | Workload type | `VirtualMachine`, `SQL`, `FileShare` |
| Enabled | Whether the policy is enabled | `True` |
| Regions | Protected Azure regions | `westeurope; northeurope` |
| `<Schedule>_Repository` | Target repository name(s) for the schedule | `repo-hot-weu` |
| `<Schedule>_StorageAccount` | Storage account of the repository | `stvbazbackup01` |
| `<Schedule>_Region` | Region of the repository | `westeurope` |
| `<Schedule>_Type` | Storage tier of the repository | `Hot`, `Cool`, `Archive` |
| `<schedule>.<setting>` | One column per retention setting found | `dailySchedule.retention.timeRetentionDuration` = `14` |

`<Schedule>` is `Daily`, `Weekly`, `Monthly` or `Yearly`. Repositories that are referenced outside these schedules go to the `Other_*` columns. Multiple values in one cell are separated by `; `.

The CSV contains all columns found across all policies. A cell stays empty when a policy does not have that setting.

### Console
- One line per policy with its regions, retention and repositories
- A table of all repositories (name, region, tier, ID)

## Requirements
- PowerShell 7 or later (the script uses the `??` operator)
- Network access to the VBAz appliance over HTTPS (port 443)
- A VBAz user account **without MFA**. The password grant does not work with MFA, so use a dedicated service or API account.

## Usage
```powershell
# Prompts for the appliance credentials
./VBAz-GetJobDetails.ps1 -Server vbaz.contoso.com

# Credentials, API version and output folder given explicitly
./VBAz-GetJobDetails.ps1 -Server 10.0.0.4 -Credential (Get-Credential) -ApiVersion v8 -OutDir ./out

# Show which workload types were skipped and why
./VBAz-GetJobDetails.ps1 -Server vbaz.contoso.com -Verbose
```

### Parameters
| Parameter | Required | Description |
|---|---|---|
| `-Server` | Yes | FQDN or IP address of the VBAz appliance |
| `-Credential` | No | Appliance credentials. If you do not pass them, the script asks for them. |
| `-ApiVersion` | No | REST API version, for example `v8`. If you do not pass it, the script detects it. |
| `-OutDir` | No | Output folder. Default: `vbaz-export_<timestamp>` next to the script. |
| `-NoSkipCertificateCheck` | No | Validate the TLS certificate of the appliance. By default the check is skipped, because appliances often use a self-signed certificate. |

## Troubleshooting
| Message | Cause and fix |
|---|---|
| `No access_token returned` | Wrong credentials, or MFA is enabled for the account. Use an account without MFA. |
| `Could not detect a working API version` | The appliance cannot be reached, or none of `v4`–`v8` responds. Check the network connection, or pass `-ApiVersion`. |
| `Repository '...': storage account or region not found` | The repository object uses different property names. Check the listed properties and `repositories.raw.json`, and extend `Get-RepoAccount` / `Get-RepoRegion` in the script. |
| `Policy '...': no regions found` | The policy stores regions under a property name the script does not know. Check `policies.raw.json`. |
| A workload type is missing | The API returned an error for that endpoint. Run the script with `-Verbose` to see the reason. |

## License

MIT License

Copyright (c) 2026 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
