# Instant NAS Recovery Extension for DFS

This cmdlet is getting all shares from a Veeam File Job and checks if this share exists
in a DFS. All shares from this job will be started via Instant NAS Recovery and the DFS
reparse points will be changed from the existing target to the mount server path.

## Parameters
`-DfsRoot` - With this parameter you specify the UNC path to scan e.g. "\\fileserver\dfs". *REQUIRED* \
`-VBRJobName` - Name of the NAS backup job. which should be recovered. *REQUIRED* \
`-ScanDepth` - How deep in the subfolder structure should be scan for reparse points?. *REQUIRED* \

## Usage

Start all shares from Job "DFS NAS Test" and scan the DFS root "\\homelab\dfs" in the top 3 levels for these shares: 
`.\Involve-NASInstantDFSRecovery.ps1 -DfsRoot "\\homelab\dfs" -ScanDepth 3 -VBRJobName "DFS NAS Test" -Owner "HOMELAB\Administrator"`
