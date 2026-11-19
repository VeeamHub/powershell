# Veeam Plug-in for Nutanix AHV - Configuration & Session Report

## Author
---
Jason Berry ([jason.berry@veeam.com](mailto:jason.berry@veeam.com)) Written with assistance from Claude (Anthropic); reviewed and tested by the author.

## Function:
---
Builds a single, self-contained HTML report for Veeam Plug-in for Nutanix AHV from the plug-in REST API. It is **read-only** and makes no configuration changes. The report covers:

|Section|What it shows|
|---|---|
|Summary|Worker count, total concurrent tasks, jobs, sessions, failures, warnings, rate-limited sessions, mean per-VM duration, top bottleneck|
|API rate-limit analysis|Sessions that hit Prism `TooManyRequests` / `API rate limit exceeded` / HTTP 429, by day and by session|
|Workers|Max concurrent tasks, vCPU, memory, cluster, status, IP, host affinity and the host the worker is pinned to; concurrency totals per cluster|
|Job settings|Schedule, retries, retention, GFS, active / synthetic full, health check, compression, block size, repository|
|Per-VM duration|Median, mean, P90, P95 and max per VM backup run, with a backup-window projection and a plain-language guide to the figures|
|Bottleneck analysis|Limiting stage (Source / Proxy / Network / Target) parsed from session events|
|Per-job rollup|Success / warning / failure / rate-limited counts per job|
|Session detail|Every session in the window, with result, duration, throughput, bottleneck and error text; downloadable as CSV|

Sections are collapsible (Expand all / Collapse all), and the console prints a timing and API call summary at the end of each run.

**Example output:** [`Example`](https://htmlpreview.github.io/?https://github.com/VeeamHub/powershell/blob/master/BR-NutanixAHV-Report/example/VeeamAhvReport_example.html)

## Version
---
**Current version:** 1.10.1 (2026-10-26)

The script prints its version when it starts and in the footer of every report, so you can tell which version produced a given report. The full change history is in the `.NOTES` section at the top of `New-VeeamAhvReport.ps1`.

|Version|Date|Changes|
|---|---|---|
|1.10.1|2026-10-26|Fixed `CertificatePolicy` error on PowerShell 7.|
|1.10.0|2026-10-26|PR review fixes: certificate policy restored after run (PS 5.1), run stops if workers / jobs / sessions cannot be retrieved, CSV formula protection, stricter 429 match, duration display, consistent output folder.|
|1.9.x|2026-10-21|Session detail errors reported (with traceId), fail fast on DNS / connection errors, prepared for publication.|
|1.9.0|2026-10-13|Rescan sessions hidden by default (`-IncludeRescans`).|
|1.8.x|2026-10-13|Per-VM window sizing counts backup runs only and projects on distinct VMs; plain-language guide to P90 / P95.|
|1.7.x|2026-10-09|Collapsible sections, CSV export, run-time diagnostics.|
|1.6.0|2026-10-09|Rescan filtering.|
|1.5.x|2026-10-07|Worker host affinity; `Error` results counted as failed.|
|1.4.0|2026-09-30|Bottleneck capture and per-VM duration statistics.|
|1.3.0|2026-09-15|VBR 12.x support via the AHV backup appliance.|
|1.0.0 - 1.2.1|2026-09|Initial release, API discovery, null-safe collection handling.|

## Known Issues:
---
- **VBR 12.x / AHV plug-in v7 or earlier:** network access to the AHV backup appliance and an appliance administrator account (use `-ApplianceServer`). -- _this has only been tested against the API spec not on a live system_

## Requirements:
---
- PowerShell 5.1 or 7.x. No additional modules.
- **VBR v13 / AHV plug-in v8 or later:** network access to the VBR REST API (port 443 and/or 9419) and a VBR account with rights to read the AHV plug-in configuration.
- **VBR 12.x / AHV plug-in v7 or earlier:** network access to the AHV backup appliance and an appliance administrator account (use `-ApplianceServer`). -- _this has only been tested against the API spec not on a live system_

## Usage:
---
```
# VBR v13 - prompts for credentials
.\New-VeeamAhvReport.ps1 -VbrServer vbr01.example.local -SkipCertificateCheck

# Full detail for every session, plus a CSV of all session fields, then open the report
.\New-VeeamAhvReport.ps1 -VbrServer vbr01.example.local -DeepScanAllSessions -ExportCsv -Show

# VBR 12.x - credentials are the AHV appliance account, not a VBR account
.\New-VeeamAhvReport.ps1 -VbrServer vbr12.example.local -ApplianceServer 192.0.2.40 -SkipCertificateCheck
```

The report is written to `.\VeeamAhvReport_<server>_<timestamp>.html` unless `-OutputPath` is given. The script also returns an object (`Workers`, `Jobs`, `Sessions`, `JobRollup`, `Timings`, `ApiStats`, ...) for use in your own scripts.

**Parameters:**

|Parameter|Description|
|---|---|
|`-VbrServer`|**Required.** FQDN or IP of the VBR server.|
|`-ApplianceServer`|VBR 12.x only. Address of the AHV backup appliance; `-Credential` then becomes the appliance account.|
|`-Credential`|PSCredential. Prompted for if omitted.|
|`-DaysBack`|Session history window in days (1-365). Default `7`.|
|`-OutputPath`|Path for the HTML file.|
|`-RestPort`|VBR REST API port. Default `9419`.|
|`-DeepScanAllSessions`|Fetch detail for every session, not just non-successful ones. Needed for meaningful bottleneck and per-VM duration figures. Successful rescans are still skipped.|
|`-ExportCsv`|Also write `<report name>_sessions.csv` with every collected session field.|
|`-IncludeRescans`|Show infrastructure rescan sessions. They are hidden by default because the plug-in rescans every few minutes and they can outnumber backup sessions hundreds to one. Use this when investigating rate limits or Prism connectivity.|
|`-BackupTypePattern`|Optional. Regex for backup session types. Default `backup`.|
|`-RescanPattern`|Optional. Regex for rescan session names. Default `^Rescan`.|
|`-Show`|Open the report when finished.|
|`-SkipCertificateCheck`|Accept self-signed certificates.|

**Troubleshooting:**

- **"Could not reach the Veeam Plug-in for Nutanix AHV REST API"** after authentication succeeds: on VBR 12.x the API lives on the AHV appliance, so re-run with `-ApplianceServer`. Otherwise check the plug-in is installed and try the FQDN rather than the IP. The error lists every URL that was tried.
- **HTTP 400 at login on VBR 12.x:** the script negotiates the `x-api-version` header automatically; the error shows each version it tried.
- **Slow runs:** check the timing summary at the end of the console output. Almost all time is normally in _Session detail_, which is one API call per session scanned. Reduce `-DaysBack` or drop `-DeepScanAllSessions`. Add `-Verbose` to log every API call with its duration.
- **No bottleneck or per-VM figures:** run with `-DeepScanAllSessions`. The figures come from session detail, which by default is only fetched for non-successful sessions.
- **Per-VM section empty with deep scan on:** check the "Included session types" note in that section. If your plug-in reports per-VM backup sessions under a type that does not contain "backup", set `-BackupTypePattern`.
- **Affinity host shows "(host not reported)":** run with `-Verbose` to print the raw affinity settings returned by the API for that worker.