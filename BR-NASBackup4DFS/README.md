=Welcome in this folder, but for what can I use this scripts?=

==Add-DFSTargetsAsJobs.ps1==
This script grabs all shares from DFS tree and create for every share an own backup job.
Die Backup Job will be cloned from an existing "Template file backup job"

==Add-DFSTargetToNASBackupJob.ps1==
This script grabs all shares from DFS tree and only add the shares to VBR inventory.
Optional you can update a job with all shares, which are in this DFS tree.