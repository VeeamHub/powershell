<#
.SYNOPSIS
Assigns hosted VBR server backup jobs to a VSPC Company

.DESCRIPTION
This script assigns hosted Veeam Backup & Replication (VBR) server backup jobs to a Veeam Service Provider Console (VSPC) Company. It first identifies VMware Cloud Director (VCD) backup jobs on the specified VBR server. Then, it ensures the job protects a single VCD Organization. Finally, it assigns the job to a VSPC Company.

Mappings are stored in a CSV file and can be generated automatically using the Sync-VcdOrganizationMapping.ps1 cmdlet.

.PARAMETER VSPC
VSPC Server IP or FQDN

.PARAMETER VspcUser
VSPC Portal Administrator account username

.PARAMETER VspcPass
VSPC Portal Administrator account password

.PARAMETER VspcCredential
VSPC Portal Administrator account PS Credential Object

.PARAMETER VspcPort
VSPC Rest API port

.PARAMETER VBR
VBR Server IP or FQDN

.PARAMETER VbrUser
VBR Backup Administrator account username

.PARAMETER VbrPass
VBR Backup Administrator account password

.PARAMETER VbrCredential
VBR Backup Administrator account PS Credential Object

.PARAMETER VbrPort
VBR Rest API port

.PARAMETER IncludeAssigned
Flag to include already assigned jobs in the output

.PARAMETER AllowSelfSignedCerts
Flag allowing self-signed certificates (insecure)

.OUTPUTS
Set-HostedVbrJobAssignment.ps1 returns a PowerShell Object containing all data

.EXAMPLE
Set-HostedVbrJobAssignment.ps1 -VSPC "vspc.contoso.local" -VspcUser "contoso\jsmith" -VspcPass "password" -VBR "vbr.contoso.local" -VbrUser "contoso\jsmith" -VbrPass "password"

Description
-----------
Connect to the specified VSPC & VBR server using a username/password and attempt to assign a VCD backup job to a VSPC Company

.EXAMPLE
Set-HostedVbrJobAssignment.ps1 -VSPC "vspc.contoso.local" -VspcCredential (Get-Credential) -VBR "vbr.contoso.local" -VbrCredential (Get-Credential)

Description
-----------
PowerShell credentials object is supported

.EXAMPLE
Set-HostedVbrJobAssignment.ps1 -VSPC "vspc.contoso.local" -VspcPort 9999 -VspcUser "contoso\jsmith" -VspcPass "password" -VBR "vbr.contoso.local" -VbrPort 9999 -VbrUser "contoso\jsmith" -VbrPass "password"

Description
-----------
Connecting to a VSPC and/or VBR server using a non-standard API port

.EXAMPLE
Set-HostedVbrJobAssignment.ps1 -VSPC "vspc.contoso.local" -VspcUser "contoso\jsmith" -VspcPass "password" -VBR "vbr.contoso.local" -VbrUser "contoso\jsmith" -VbrPass "password" -AllowSelfSignedCerts

Description
-----------
Connecting to a VSPC and/or VBR server that uses Self-Signed Certificates (insecure)

.EXAMPLE
Set-HostedVbrJobAssignment.ps1 -VSPC "vspc.contoso.local" -VspcUser "contoso\jsmith" -VspcPass "password" -VBR "vbr.contoso.local" -VbrUser "contoso\jsmith" -VbrPass "password" -IncludeAssigned

Description
-----------
Include already assigned jobs in the output results

.NOTES
NAME:  Set-HostedVbrJobAssignment.ps1
VERSION: 1.1
AUTHOR: Chris Arceneaux
TWITTER: @chris_arceneaux
GITHUB: https://github.com/carceneaux

.LINK
https://arsano.ninja/

.LINK
https://helpcenter.veeam.com/docs/backup/vbr_rest/overview.html?ver=120

.LINK
https://helpcenter.veeam.com/docs/vac/rest/about_rest.html?ver=80

#>
#Requires -Version 6.2
[CmdletBinding(DefaultParametersetName = "UsePass")]
param(
    [Parameter(Mandatory = $true)]
    [string] $VSPC,
    [Parameter(Mandatory = $true, ParameterSetName = "UsePass")]
    [string] $VspcUser,
    [Parameter(Mandatory = $false, ParameterSetName = "UsePass")]
    [string] $VspcPass = $true,
    [Parameter(Mandatory = $true, ParameterSetName = "UseCred")]
    [System.Management.Automation.PSCredential]$VspcCredential,
    [Parameter(Mandatory = $false)]
    [Int] $VspcPort = 1280,
    [Parameter(Mandatory = $true)]
    [string] $VBR,
    [Parameter(Mandatory = $true, ParameterSetName = "UsePass")]
    [string] $VbrUser,
    [Parameter(Mandatory = $false, ParameterSetName = "UsePass")]
    [string] $VbrPass = $true,
    [Parameter(Mandatory = $true, ParameterSetName = "UseCred")]
    [System.Management.Automation.PSCredential]$VbrCredential,
    [Parameter(Mandatory = $false)]
    [Int] $VbrPort = 9419,
    [Parameter(Mandatory = $false)]
    [Switch] $IncludeAssigned,
    [Parameter(Mandatory = $false)]
    [Switch] $AllowSelfSignedCerts
)

Function Get-AsyncAction {
    param(
        [string] $ActionId,
        [System.Collections.Generic.Dictionary[[string], [string]]] $Headers
    )

    # Removing x-request-id header as it's not needed
    $Headers.Remove("x-request-id")

    # GET - /api/v3/asyncActions/{actionId} - Retrieve Async Action
    [string] $url = $vspcBaseUrl + "/api/v3/asyncActions/" + $actionId
    Write-Verbose "GET - $url"

    :loop while ($true) {
        $response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts
        switch ($response.data.status) {
            "running" {
                Start-Sleep -Seconds 10
                break
            }
            "succeed" {
                break loop
            }
            "canceled" {
                throw "Async Action ID (" + $actionId + ") was cancelled."
            }
            "failed" {
                throw "Async Action ID (" + $actionId + ") failed with the following error message(s): " + $response.errors.message
            }
            Default	{ throw "An unknown Async Action response was detected." }
        }
    }

    # Action complete...obtaining result...
    [string] $url = $vspcBaseUrl + "/api/v3/asyncActions/" + $actionId + "/result"
    Write-Verbose "GET - $url"
    $response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts

    return $response
    # End Retrieve Async Action
}

Function Get-VspcPaginatedResults {
    param(
        [string] $URL,
        [System.Collections.Generic.Dictionary[[string], [string]]] $Headers,
        [PSCustomObject] $Response
    )

    # Initializing API object
    $results = [System.Collections.ArrayList]::new()
    [ref] $null = $results.Add($Response.data)

    # Determine page count
    $pageTotal = [math]::ceiling($response.meta.pagingInfo.total / $response.meta.pagingInfo.count)
    Write-Verbose "Total Pages: $pageTotal"

    # Retrieving remaining results
    $page = 0
    while ($page -ne $pageTotal) {
        # Setting offset variable
        $page++
        $offset = $page * 500  # 500 is limit
        Write-Verbose ("GET - {0}&offset={1}" -f $URL, $offset)

        # Updating x-request-id
        $guid = (New-Guid).Guid
        $Headers."x-request-id" = $guid
        Write-Verbose "x-request-id: $guid"

        $response = Invoke-RestMethod ("{0}&offset={1}" -f $URL, $offset) -Method 'GET' -Headers $Headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts -StatusCodeVariable responseCode
        if (202 -eq $responseCode) {
            # retrieve async action response
            $response = Get-AsyncAction -ActionId $guid -Headers $headers
        }
        [ref] $null = $results.Add($response.data)
    }

    return $results
}

Function Get-VspcApiResult {
    param(
        [string] $URL,
        [string] $Token,
        [string] $Type
    )

    try {
        # Initializing API object
        $result = [System.Collections.ArrayList]::new()

        # Setting headers
        $headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
        $headers.Add("Authorization", "Bearer $Token")
        $guid = (New-Guid).Guid
        $headers.Add("x-request-id", $guid)
        $headers.Add("x-client-version", $vspcApiVersion)  # API versioning for backwards compatibility

        # Making API call
        Write-Verbose "GET - $URL"
        Write-Verbose "x-request-id: $guid"
        $response = Invoke-RestMethod $URL -Method 'GET' -Headers $headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts -StatusCodeVariable responseCode
        if ($null -eq $response) { return $null }  # return empty response
        if (202 -eq $responseCode) {
            # retrieve async action response
            $response = Get-AsyncAction -ActionId $guid -Headers $headers
        }

        # Is there more than 1 page of results?
        if ($response.meta.pagingInfo.count -lt $response.meta.pagingInfo.total) {
            $result = Get-VspcPaginatedResults -URL $URL -Response $response -Headers $headers
        }
        else {
            [ref] $null = $result.Add($response.data)
        }

        return $result
    }
    catch {
        Write-Error "ERROR: Retrieving $Type Failed!"
        throw
    }
}

# Initializing global variables
[string] $vbrBaseUrl = "https://" + $VBR + ":" + $VbrPort
[string] $vbrApiVersion = "1.1-rev1"
[string] $vspcBaseUrl = "https://" + $VSPC + ":" + $VspcPort
[string] $vspcApiVersion = "3.4"

# Import VCD Organization mapping file.
try {
    $file = "$PSScriptRoot\VcdOrganizationMapping.csv"
    if (Test-Path -Path $file) {
        $mapping = Import-Csv -Path $file
        Write-Verbose "CSV found & imported: $file"
    }
    else {
        throw "CSV not found ($file). This is required to map a VCD Organization to a VSPC Company."
    }
}
catch {
    Write-Error "ERROR: Importing CSV mappings file failed! This is required to map a VCD Organization to a VSPC Company."
    throw
}

### VBR API authentication

# Processing VBR credentials
if ($VbrCredential) {
    $VbrUser = $VbrCredential.GetNetworkCredential().Username
    $VbrPass = $VbrCredential.GetNetworkCredential().Password
}
else {
    if ($VbrPass -eq $true) {
        [securestring] $secureString = Read-Host "Enter password for '$($VbrUser)'" -AsSecureString
        [string] $VbrPass = [System.Net.NetworkCredential]::new("", $secureString).Password
    }
}

# Logging into VBR API
[string] $url = $vbrBaseUrl + "/api/oauth2/token"
Write-Verbose "POST - $url"
$headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
$headers.Add("Content-Type", "application/x-www-form-urlencoded")
$headers.Add("x-api-version", $vbrApiVersion)  # API versioning for backwards compatibility
$body = "grant_type=password&username=$VbrUser&password=$VbrPass"
try {
    $response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $body -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts
    [string] $vbrToken = $response.access_token
}
catch {
    Write-Error "ERROR: VBR Authorization Failed! Make sure the correct server and port were specified."
    throw
}

### End - VBR API authentication

### VSPC API authentication

# Processing VSPC credentials
if ($VspcCredential) {
    $VspcUser = $VspcCredential.GetNetworkCredential().Username
    $VspcPass = $VspcCredential.GetNetworkCredential().Password
}
else {
    if ($VspcPass -eq $true) {
        [securestring] $secureString = Read-Host "Enter password for '$($VspcUser)'" -AsSecureString
        [string] $VspcPass = [System.Net.NetworkCredential]::new("", $secureString).Password
    }
}

# Logging into VSPC API
[string] $url = $vspcBaseUrl + "/api/v3/token"
Write-Verbose "POST - $url"
$headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
$headers.Add("Content-Type", "application/x-www-form-urlencoded")
$headers.Add("x-client-version", $vspcApiVersion)  # API versioning for backwards compatibility
$body = "grant_type=password&username=$VspcUser&password=$VspcPass"
try {
    $response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $body -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts
    [string] $vspcToken = $response.access_token
}
catch {
    Write-Error "ERROR: VSPC Authorization Failed! Make sure the correct server and port were specified."
    throw
}

### End - VSPC API authentication

### Pre-check validation

# Retrieve VBR server info
[string] $url = $vbrBaseUrl + "/api/v1/serverInfo"
Write-Verbose "GET - $url"
$headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
$headers.Add("Content-Type", "application/json")
$headers.Add("Authorization", "bearer $vbrToken")
$headers.Add("x-api-version", $vbrApiVersion)  # API versioning for backwards compatibility
try {
    $vbrServerInfo = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts
}
catch {
    Write-Error "ERROR: Retrieving VBR server info failed!"
    throw
}

# Retrieve VBR server info from VSPC
[string] $url = $vspcBaseUrl + "/api/v3/infrastructure/backupServers?filter=[{""property"":""installationUid"",""operation"":""equals"",""collation"":""ignorecase"",""value"":""$($vbrServerInfo.vbrId)""}]"
$vspcServerInfo = Get-VspcApiResult -URL $url -Type "VBR server info from VSPC" -Token $vspcToken

# Is VSPC managing the specified VBR server?
if ($null -eq $vspcServerInfo) {
    throw "VSPC is not managing the specified VBR server. As such, no mappings can be determined."
} # Is VBR server a hosted VBR server? 
elseif ("Hosted" -ne $vspcServerInfo.backupServerRoleType) {
    throw "VBR server specified is not hosted. See Veeam documentation on how to add a Hosted VBR server to VSPC: https://helpcenter.veeam.com/docs/vac/provider_admin/connect_backup_servers.html?ver=80#hosted"
}

### End - Pre-check validation

### VSPC API interaction

# Retrieve Companies
[string] $url = $vspcBaseUrl + "/api/v3/organizations/companies?expand=Organization&limit=500"
$companies = Get-VspcApiResult -URL $url -Type "Companies" -Token $vspcToken

# Retrieve VCD backup jobs belonging to specified server
[string] $url = $vspcBaseUrl + "/api/v3/infrastructure/backupServers/$($vspcServerInfo.instanceUid)/jobs/backupVmJobs?expand=BackupServerJob&filter=[{""property"":""subtype"",""operation"":""equals"",""collation"":""ignorecase"",""value"":""vcd""}]&limit=500"
$vspcJobs = Get-VspcApiResult -URL $url -Type "VCD Backup Jobs" -Token $vspcToken

# Are VCD backup jobs present?
if ($null -eq $vspcJobs) {
    Write-Warning "No VCD backup jobs were found on the specified VSPC server. Exiting script now..."
    Exit
}

### End - VSPC API interaction

### VBR API interaction

# Retrieve VCD backup jobs
[string] $url = $vbrBaseUrl + "/api/v1/jobs?typeFilter=CloudDirectorBackup"
Write-Verbose "GET - $url"
$headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
$headers.Add("Content-Type", "application/json")
$headers.Add("Authorization", "bearer $vbrToken")
$headers.Add("x-api-version", $vbrApiVersion)  # API versioning for backwards compatibility
try {
    $response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts
}
catch {
    Write-Error "ERROR: Retrieving VCD backup jobs failed!"
    throw
}

# Are VCD backup jobs present?
if ($null -eq $response.data) {
    Write-Warning "No VCD backup jobs were found on the specified VBR server. Exiting script now..."
    Exit
}

# Initializing output object
$output = [System.Collections.ArrayList]::new() # This object will contain job assignments

# Loop through each backup job
$jobs = [System.Collections.ArrayList]::new() # This object will contain jobs awaiting assignment
foreach ($job in $response.data) {
    Write-Verbose "Analyzing job: $($job.name) ($($job.id))"
	
    # Matching up VBR backup job with VSPC backup job
    $vspcJob = $vspcJobs | Where-Object { $_.instanceUid -eq $job.id }
    if ($vspcJob) {
        Write-Verbose "VSPC Job has been found."
        $vspcOrgId = $vspcJob._embedded.backupServerJob.organizationUid
        $vspcMappedOrgId = $vspcJob._embedded.backupServerJob.mappedOrganizationUid

        # Has job already been assigned to a company? If these two IDs differ, the job has already been assigned.
        if ($vspcOrgId -ne $vspcMappedOrgId) {
            Write-Verbose "Job ($($job.name)) has already been assigned."
        
            # Including already mapped objects in the output
            if ($IncludeAssigned) {
                Write-Verbose "Adding already assigned job ($($job.name)) to output."
                $object = [PSCustomObject] @{
                    Assignment      = "SUCCESS"
                    Job_Name        = $job.name
                    Job_Id          = $job.id
                    VSPC_Company_Id = $vspcMappedOrgId
                    Message         = "Imported from VSPC"
                }
                [ref] $null = $output.Add($object)
                Clear-Variable -Name object
            }
            
            # Skip to next organization in loop
            Continue
        }
    }
    else {
        Write-Warning "Unable to match VBR job $($job.name) ($($job.id)) with a VSPC job. If this does not resolve itself within the hour, this indicates a VSPC synchronization issue."

        # Skip to next organization in loop
        Continue
    }
    
    # Is job protecting workloads from multiple VCD environments?
    $vcd = $job.virtualMachines.includes.hostName | Select-Object -Unique
    if ($vcd.count -gt 1) {
        Write-Verbose "Job is protecting more than 1 VCD environment."
        $object = [PSCustomObject] @{
            Assignment      = "ERROR"
            Job_Name        = $job.name
            Job_Id          = $job.id
            VSPC_Company_Id = $null
            Message         = "Unable to be assigned as job is protecting multiple VCD environments. Please limit the job to a single VCD Organization."
        }
        [ref] $null = $output.Add($object)
        Clear-Variable -Name object

        # Skip to next organization in loop
        Continue
    }

    $includes = $job.virtualMachines.includes
    if (($includes.count -eq 1) -and ($includes.type -eq "Organization")) {
        Write-Verbose "Job is protecting a single VCD Organization."
        $uid = $includes.objectId -replace "urn:vcloud:org:", ""
        $object = [PSCustomObject] @{
            Job_Name            = $job.name
            Job_Id              = $job.id
            VCD_Organization_Id = $uid
        }
        [ref] $null = $jobs.Add($object)
        Clear-Variable -Name object
        
        # Skip to next organization in loop
        Continue
    }
    else {
        Write-Verbose "Job is protecting multiple workloads."
        # Generating API call filter to identify workloads protected by job
        $body = @"
{
"pagination": {
	"skip": 0,
	"limit": 5000
},
"filter": {
	"type": "GroupExpression",
	"operation": "or",
	"items": [
"@

        $includes | ForEach-Object {
            $body += @"

{
	"type": "PredicateExpression",
	"property": "objectId",
	"operation": "equals",
	"value": "$($_.objectId)"
},
"@
        }
        $body += "]}}"
        $body = $body -replace "},]", "}]"
	
        # Identify VCD Organization(s) protected by backup job
        [string] $url = $vbrBaseUrl + "/api/v1/inventory/$vcd"
        Write-Verbose "POST - $url"
        $headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
        $headers.Add("Content-Type", "application/json")
        $headers.Add("Authorization", "bearer $vbrToken")
        $headers.Add("x-api-version", $vbrApiVersion)  # API versioning for backwards compatibility
        try {
            $response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $body -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts

            if ($null -eq $response.data) { break }  # empty response. skipping loop iteration
        }
        catch {
            Write-Error "ERROR: Retrieving VCD Organizations failed!"
            throw
        }

        # Is job protecting workloads from multiple VCD Organizations?
        $uid = $null
        $urns = $response.data.urn
        :loop foreach ($urn in $urns) {
            # Extracting organization vCloud URN
            $null = $urn -match "(?<=org:).*(?=;vdc)" # regex to extract VCD Organization UID

            # Comparing UIDs
            switch ($uid) {
                $null {
                    $uid = $Matches[0]
                    Write-Verbose "vCloud Org URN is null. Setting URN: $uid"
                    break
                }
                $Matches[0] {
                    Write-Verbose "vCloud Org URN matches: $uid"
                    break
                }
                default {
                    Write-Verbose "vCloud Org URN does not match: $($Matches[0])"
                    $uid = $false
                    break loop
                }
            }
        }

        if ($uid) {
            Write-Verbose "Job is protecting a single VCD Organization."
            $object = [PSCustomObject] @{
                Job_Name            = $job.name
                Job_Id              = $job.id
                VCD_Organization_Id = $uid
            }
            [ref] $null = $jobs.Add($object)
            Clear-Variable -Name object
        }
        else {
            Write-Verbose "Job is protecting multiple VCD Organizations."
            $object = [PSCustomObject] @{
                Assignment      = "ERROR"
                Job_Name        = $job.name
                Job_Id          = $job.id
                VSPC_Company_Id = $null
                Message         = "Unable to be assigned as job is protecting workloads of multiple VCD Organizations. Please limit the job to a single VCD Organization."
            }
            [ref] $null = $output.Add($object)
            Clear-Variable -Name object
        }
    }
}

### End - VBR API interaction

### Assigning jobs to a VSPC Company

# Loop through each job awaiting assignment
foreach ($job in $jobs) {
    Write-Verbose "Analyzing job: $($job.Job_Name) ($($job.Job_Id))"

    # Has VCD Organization been mapped?
    $map = $mapping | Where-Object { $_.VCD_Organization_Id -eq $job.VCD_Organization_Id }
    if ($null -eq $map) {
        Write-Verbose "VCD Organization ($($job.VCD_Organization_Id)) is not currently mapped to a VSPC Company."
        $object = [PSCustomObject] @{
            Assignment      = "INCOMPLETE"
            Job_Name        = $job.Job_Name
            Job_Id          = $job.Job_Id
            VSPC_Company_Id = $null
            Message         = "VCD Organization ($($job.VCD_Organization_Id)) is not currently mapped to a VSPC Company. Please add a corresponding mapping to the CSV file (VcdOrganizationMapping.csv)."
        }
        [ref] $null = $output.Add($object)
        Clear-Variable -Name object

        # Skip to next organization in loop
        Continue
    }
    else {
        Write-Verbose "VCD Organization ($($job.VCD_Organization_Id)) mapping has been found!"
    }

    try {
        # Setting headers
        $headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
        $headers.Add("Authorization", "Bearer $vspcToken")
        $guid = (New-Guid).Guid
        $headers.Add("x-request-id", $guid)
        $headers.Add("x-client-version", $vspcApiVersion)  # API versioning for backwards compatibility

        # Making API call - Assigning job
        [string] $url = $vspcBaseUrl + "/api/v3/infrastructure/backupServers/jobs/$($job.Job_Id)/assign?companyUid=$($map.VSPC_Organization_Id)"
        Write-Verbose "POST - $URL"
        Write-Verbose "x-request-id: $guid"
        $response = Invoke-RestMethod $URL -Method 'POST' -Headers $headers -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts -StatusCodeVariable responseCode
        if (202 -eq $responseCode) {
            # retrieve async action response
            $response = Get-AsyncAction -ActionId $guid -Headers $headers
        }

        Write-Verbose "Job $($job.Job_Name) ($($job.Job_Id)) has been successfully assigned to a VSPC Company ($($map.VSPC_Organization_Id))"
        $object = [PSCustomObject] @{
            Assignment      = "SUCCESS"
            Job_Name        = $job.Job_Name
            Job_Id          = $job.Job_Id
            VSPC_Company_Id = $map.VSPC_Organization_Id
            Message         = "Assigned using mapping from CSV file."
        }
        [ref] $null = $output.Add($object)
        Clear-Variable -Name object
    }
    catch {
        Write-Verbose "An error occurred during job assignment"
        throw
    }

    Clear-Variable -Name map
}

### End - Assigning jobs to a VSPC Company

return $output
