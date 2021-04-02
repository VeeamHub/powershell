<#
.SYNOPSIS
	Veeam backup usage for VMware Cloud Director Organizations

.DESCRIPTION
    The script retrieves Veeam backup usage for VMware Cloud Director (VCD) Organizations. The usage data can be aggregated on the Organization-level or the Org VDC-level.
	
.PARAMETER AggregateByOrgVdc
	Used to enable data aggregation on the Organization VDC-level. Useful when backups for different Org VDCs are billed differently. If not specified, script will aggregate at the Organization-level.

.PARAMETER IncludeAllVcdBackups
	Used to include usage statistics for all VCD backups. If not specified, usage will be limited to self-service backups, created by the [Veeam Self-Service Portal (VSSP) for VCD](https://helpcenter.veeam.com/docs/backup/em/em_managing_vms_in_vcd_org.html?ver=110).

.OUTPUTS
	Get-VcdOrgUsage returns a PowerShell Object containing all data

.EXAMPLE
	Get-VcdOrgUsage.ps1

	Description
	-----------
	Returns usage information for all backups created/managed by the VSSP aggregated by VCD Organization

.EXAMPLE
	Get-VcdOrgUsage.ps1 -AggregateByOrgVdc

	Description
	-----------
	Returns usage information for all backups created/managed by the VSSP aggregated by VCD Organization VDC

.EXAMPLE
	Get-VcdOrgUsage.ps1 -IncludeAllVcdBackups

	Description
	-----------
	Returns usage information for all VCD backups whether created by the VSSP or directly on the backup server by the provider aggregated by VCD Organization

.EXAMPLE
	Get-VcdOrgUsage.ps1 -AggregateByOrgVdc -IncludeAllVcdBackups

	Description
	-----------
	Returns usage information for all VCD backups whether created by the VSSP or directly on the backup server by the provider aggregated by VCD Organization VDC

.EXAMPLE
	Get-VcdOrgUsage.ps1 -Verbose

	Description
	-----------
	Verbose output is supported

.NOTES
	NAME:  Get-VcdOrgUsage.ps1
	VERSION: 1.2
	AUTHOR: Chris Arceneaux
	TWITTER: @chris_arceneaux
	GITHUB: https://github.com/carceneaux

    A big thanks to Yuri Sukhov ([@wombatairlines](https://twitter.com/wombatairlines))! I used his [code](https://github.com/wombatonfire/veeam-powershell/tree/master/New-OrgBackupReport) as a starting point for this project.

.LINK
	https://arsano.ninja/

#>
[CmdletBinding()]
param(
    [switch]$AggregateByOrgVdc,
    [switch]$IncludeAllVcdBackups
)

# All VCD VMs exist beneath a vApp. This function returns the source vApp location for the vApp/VM specified.
function Get-VcdVAppLocation {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [Veeam.Backup.Core.CBackup]
        $Backup,

        [Parameter(Mandatory = $true,
            ParameterSetName = "VM")]
        [guid]
        $VMObjectId,

        [Parameter(Mandatory = $true,
            ParameterSetName = "vApp")]
        [guid]
        $VAppObjectId
    )

    if ($PSCmdlet.ParameterSetName -eq "VM") {
        $vmOib = $Backup.FindLastOib($VMObjectId)
        $vAppOib = $vmOib.FindParent()
    }
    elseif ($PSCmdlet.ParameterSetName -eq "vApp") {
        $vAppOib = $Backup.FindLastOib($VAppObjectId)
    }

    return $vAppOib.AuxData.OrigVApp.VCloudVAppLocation
}

# Initializing variables
if ($IncludeAllVcdBackups) {
    $selfServiceBackupIds = New-Object -TypeName System.Collections.Generic.List[guid]
}
$orgReports = @{}
$knownVmIds = New-Object -TypeName System.Collections.Generic.List[guid]

# Retrieving all required VCD items from Veeam
$vcdItems = Find-VBRvCloudEntity
$vcdOrgItems = $vcdItems | Where-Object { $_.Type -eq "Organization" }
Write-Verbose "Retrieved $($vcdOrgItems.count) Organizations from Veeam"

# Retrieving all Veeam repositories
$repos = Get-VBRBackupRepository
$repos += Get-VBRBackupRepository -ScaleOut
Write-Verbose "Retrieved $($repos.count) Repositories from Veeam"

# Retrieving VSSP backups usage :: Looping through all VCD Organizations
foreach ($item in $vcdOrgItems) {
    Write-Verbose "$($item.Name): Retrieving VSSP Backups for Organization"
    # Creating CVcdOrganization object. Required for subsequent API call.
    $vcdOrg = New-Object -TypeName Veeam.Backup.Model.CVcdOrganization `
        -ArgumentList $item.VcdId, $item.VcdRef, $item.Name
    
    # Looping through all Veeam repositories
    foreach ($repo in $repos) {
        Write-Verbose "$($item.Name): Searching '$($repo.Name)' for VSSP quota..."
        # Retrieving VSSP quota if exists
        $orgQuota = [Veeam.Backup.Core.CJobQuota]::FindByOrganization($vcdOrg, $repo.Id.Guid)
        $orgQuotaId = $orgQuota.Id

        # If VSSP quota exists
        if ($orgQuotaId) {
            Write-Verbose "$($item.Name): VSSP quota found: $orgQuotaId"
            $orgBackupIds = [Veeam.Backup.DBManager.CDBManager]::Instance.Backups.FindBackupsByQuotaIds($orgQuotaId).Id
            # Aggregate by Org VDC
            if ($AggregateByOrgVdc) {
                Write-Verbose "$($item.Name): Aggregating by Org VDC..."
                # Looping through backups
                foreach ($backupId in $orgBackupIds) {
                    if ($IncludeAllVcdBackups) {
                        $selfServiceBackupIds.Add($backupId)
                    }

                    # Retrieving backup using backup ID
                    $backup = [Veeam.Backup.Core.CBackup]::Get($backupId)
                    
                    # Retrieving backup files
                    $storages = $backup.GetAllStorages()

                    # Looping through backup objects
                    foreach ($object in $backup.GetObjects()) {
                        if ($object.Type -eq "VM") {
                            $vcdVAppLocation = Get-VcdVAppLocation -Backup $backup -VMObjectId $object.Id
                        }
                        elseif ($object.Type -eq "NfcDir") {
                            $vcdVAppLocation = Get-VcdVAppLocation -Backup $backup -VAppObjectId $object.Id
                        }
                        $orgVdcName = $vcdVAppLocation.OrgVdcName
                        if (!$orgReports.Contains($vcdOrg.OrgName)) {
                            $orgReports[$vcdOrg.OrgName] = @{}
                        }
                        if (!$orgReports[$vcdOrg.OrgName].Contains($orgVdcName)) {
                            $orgReports[$vcdOrg.OrgName][$orgVdcName] = [PSCustomObject]@{
                                vcdId            = $vcdOrg.HostId;
                                vcdName          = ($vcdItems | Where-Object { $_.Id -eq $vcdOrg.HostId }).Name;
                                organizationRef  = $vcdOrg.OrgRef;
                                organizationName = $vcdOrg.OrgName;
                                orgVdcRef        = $vcdVAppLocation.OrgVdcRef;
                                orgVdcName       = $orgVdcName;
                                repositoryId     = $repo.Id;
                                repositoryName   = $repo.Name;
                                protectedVms     = 0;
                                quotaId          = $orgQuotaId;
                                quotaGb          = $orgQuota.QuotaSize.InGigabytes;
                                usedSpace        = 0
                            }
                        }
                        if ($object.Type -eq "VM") {
                            if ($object.Id -notin $knownVmIds) {
                                $orgReports[$vcdOrg.OrgName][$orgVdcName].protectedVms += 1
                                $knownVmIds.Add($object.Id)
                            }
                        }
                        # Retrieving size for all backup files
                        $sizePerObjectStorage = ($storages | Where-Object -FilterScript { $_.ObjectId -eq $object.Id }).Stats.BackupSize
                        # Summing up size for all backup files per object
                        foreach ($size in $sizePerObjectStorage) {
                            $orgReports[$vcdOrg.OrgName][$orgVdcName].usedSpace += $size
                        }
                    }
                }
            }
            # Aggregate by VCD Organization
            else {
                Write-Verbose "$($item.Name): Aggregating by Organization..."
                
                # Looping through backups
                foreach ($backupId in $orgBackupIds) {
                    if ($IncludeAllVcdBackups) {
                        $selfServiceBackupIds.Add($backupId)
                    }
                    # Retrieving backup using backup ID
                    $backup = [Veeam.Backup.Core.CBackup]::Get($backupId)
                    if (!$orgReports.Contains($vcdOrg.OrgName)) {
                        $orgReports[$vcdOrg.OrgName] = [PSCustomObject]@{
                            vcdId            = $vcdOrg.HostId;
                            vcdName          = ($vcdItems | Where-Object { $_.Id -eq $vcdOrg.HostId }).Name;
                            organizationRef  = $vcdOrg.OrgRef;
                            organizationName = $vcdOrg.OrgName;
                            repositoryId     = $repo.Id;
                            repositoryName   = $repo.Name;
                            protectedVms     = 0;
                            quotaId          = $orgQuotaId;
                            quotaGb          = $orgQuota.QuotaSize.InGigabytes;
                            usedSpace        = 0
                        }
                    }
                    # Looping through backup objects
                    foreach ($object in $backup.GetObjects() | Where-Object -FilterScript { $_.Type -eq "VM" }) {
                        if ($object.Id -notin $knownVmIds) {
                            $orgReports[$vcdOrg.OrgName].protectedVms += 1
                            $knownVmIds.Add($object.Id)
                        }
                    }
                    # Retrieving size for all backup files
                    $sizePerStorage = $backup.GetAllStorages().Stats.BackupSize
                    # Summing up size for all backup files per object
                    foreach ($size in $sizePerStorage) {
                        $orgReports[$vcdOrg.OrgName].usedSpace += $size
                    }
                }
            }
        }
    }
}

# Retrieving ALL VCD backups usage (if specified). Not just VSSP backups.
if ($IncludeAllVcdBackups) {
    Write-Verbose "Flag specified...including usage for Non-VSSP Backups as well..."
    # Retrieving all VCD backups
    $allVcdBackups = [Veeam.Backup.Core.CBackup]::GetAll() | Where-Object -FilterScript { $_.BackupPlatform.ToString() -eq "EVcd" }
    
    # Separating out VSSP backups vs backups created directly on the backup server by the provider
    $nonSelfServiceVcdBackups = $allVcdBackups | Where-Object -FilterScript { $_.Id -notin $selfServiceBackupIds }
    Write-Verbose "Non-VSSP Backups found: $($nonSelfServiceVcdBackups.count)"

    # Looping through Non-VSSP backups
    foreach ($backup in $nonSelfServiceVcdBackups) {
        # Retrieving backup files
        $storages = $backup.GetAllStorages()
        # Looping through backup objects
        foreach ($object in $backup.GetObjects()) {
            if ($object.Type -eq "VM") {
                $vcdVAppLocation = Get-VcdVAppLocation -Backup $backup -VMObjectId $object.Id
            }
            elseif ($object.Type -eq "NfcDir") {
                $vcdVAppLocation = Get-VcdVAppLocation -Backup $backup -VAppObjectId $object.Id
            }
            $orgName = $vcdVAppLocation.OrgName
            # Aggregate by Org VDC
            if ($AggregateByOrgVdc) {
                $orgVdcName = $vcdVAppLocation.OrgVdcName
                if (!$orgReports.Contains($orgName)) {
                    $orgReports[$orgName] = @{}
                }
                if (!$orgReports[$orgName].Contains($orgVdcName)) {
                    $orgReports[$orgName][$orgVdcName] = [PSCustomObject]@{
                        vcdId            = $vcdVAppLocation.VcdInstanceDbId;
                        vcdName          = ($vcdItems | Where-Object { $_.Id -eq $vcdVAppLocation.VcdInstanceDbId}).Name;
                        organizationRef  = $vcdVAppLocation.OrgRef;
                        organizationName = $orgName;
                        orgVdcRef        = $vcdVAppLocation.OrgVdcRef;
                        orgVdcName       = $orgVdcName;
                        repositoryId     = $null;
                        repositoryName   = $null;
                        protectedVms     = 0;
                        quotaId          = $null;
                        quotaGb          = $null;
                        usedSpace        = 0
                    }
                }
                # Nulling Backup Repository as it might not match VSSP backups
                else {
                    $orgReports[$orgName][$orgVdcName].repositoryId = $null
                    $orgReports[$orgName][$orgVdcName].repositoryName = $null
                }
                if ($object.Type -eq "VM") {
                    if ($object.Id -notin $knownVmIds) {
                        $orgReports[$orgName][$orgVdcName].protectedVms += 1
                        $knownVmIds.Add($object.Id)
                    }
                }
                # Retrieving size for all backup files
                $sizePerObjectStorage = ($storages | Where-Object -FilterScript { $_.ObjectId -eq $object.Id }).Stats.BackupSize
                # Summing up size for all backup files per object
                foreach ($size in $sizePerObjectStorage) {
                    $orgReports[$orgName][$orgVdcName].usedSpace += $size
                }
            }
            # Aggregate by VCD Organization
            else {
                if (!$orgReports.Contains($orgName)) {
                    $orgReports[$orgName] = [PSCustomObject]@{
                        vcdId            = $vcdVAppLocation.VcdInstanceDbId;
                        vcdName          = ($vcdItems | Where-Object { $_.Id -eq $vcdVAppLocation.VcdInstanceDbId}).Name;
                        organizationRef  = $vcdVAppLocation.OrgRef;
                        organizationName = $orgName;
                        repositoryId     = $repo.Id;
                        repositoryName   = $repo.Name;
                        protectedVms     = 0;
                        quotaId          = $null;
                        quotaGb          = $null;
                        usedSpace        = 0
                    }
                }
                # Nulling Backup Repository as it might not match VSSP backups
                else {
                    $orgReports[$orgName].repositoryId = $null
                    $orgReports[$orgName].repositoryName = $null
                }

                if ($object.Type -eq "VM") {
                    if ($object.Id -notin $knownVmIds) {
                        $orgReports[$orgName].protectedVms += 1
                        $knownVmIds.Add($object.Id)
                    }
                }
                # Retrieving size for all backup files
                $sizePerObjectStorage = ($storages | Where-Object -FilterScript { $_.ObjectId -eq $object.Id }).Stats.BackupSize
                # Summing up size for all backup files per object
                foreach ($size in $sizePerObjectStorage) {
                    $orgReports[$orgName].usedSpace += $size
                }
            }
        }
    }
}

# Initializing output object
$usage = New-Object -TypeName System.Collections.Generic.List[PSCustomObject]

# Per-Org VDC: Populating output object with usage statistics
Write-Verbose "Preparing usage for output..."
if ($AggregateByOrgVdc) {
    foreach ($orgReportEntry in $orgReports.GetEnumerator()) {
        foreach ($orgVdcReportEntry in $orgReportEntry.Value.GetEnumerator()) {
            $usage.Add([PSCustomObject]@{
                    #VcdId        = $orgVdcReportEntry.Value.vcdId;
                    VCD          = $orgVdcReportEntry.Value.vcdName;
                    #OrganizationRef = $orgVdcReportEntry.Value.organizationRef;
                    Organization = $orgReportEntry.Key;
                    #OrgVdcRef    = $orgVdcReportEntry.Value.orgVdcRef
                    OrgVDC       = $orgVdcReportEntry.Key;
                    #RepositoryId = $orgVdcReportEntry.Value.repositoryId;
                    Repository   = $orgVdcReportEntry.Value.repositoryName;
                    ProtectedVMs = $orgVdcReportEntry.Value.protectedVms;
                    #QuotaId      = $orgVdcReportEntry.Value.quotaId;
                    QuotaGB      = $orgVdcReportEntry.Value.quotaGb;
                    UsedSpaceGB  = [math]::round($orgVdcReportEntry.Value.usedSpace / 1Gb, 2) #convert bytes to GB
                })
        }
    }
}
# Per-Organization: Populating output object with usage statistics
else {
    foreach ($orgReportEntry in $orgReports.GetEnumerator()) {
        $usage.Add([PSCustomObject]@{
                #VcdId        = $orgReportEntry.Value.vcdId;
                VCD          = $orgReportEntry.Value.vcdName;
                #OrganizationRef = $orgReportEntry.Value.organizationRef;
                Organization = $orgReportEntry.Key;
                #RepositoryId = $orgReportEntry.Value.repositoryId;
                Repository   = $orgReportEntry.Value.repositoryName;
                ProtectedVMs = $orgReportEntry.Value.protectedVms;
                #QuotaId      = $orgReportEntry.Value.quotaId;
                QuotaGB      = $orgReportEntry.Value.quotaGb;
                UsedSpaceGB  = [math]::round($orgReportEntry.Value.usedSpace / 1Gb, 2) #convert bytes to GB
            })
    }
}

# Outputting usage statistics
return $usage
