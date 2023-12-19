<#
.SYNOPSIS
Maps a VSPC Company to a VCD Organization

.DESCRIPTION
This script identifies VMware Cloud Director (VCD) Organizations using the specified Veeam Backup & Replication (VBR) server and then attempts to map each Organization to a Veeam Service Provider Console (VSPC) Company. Mappings are stored in a csv file. Organizations that cannot be mapped will be identified in the output.

Four different methods of mapping are available:

1. VCD-backed Cloud Connect Tenants
2. Identical names (VCD Organization/VSPC Company)
3. Mapping from already existing mappings (different VSPC servers)
4. Manual (outside of script)

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

.PARAMETER IncludeMapped
Flag to include already mapped objects in the output

.PARAMETER AllowSelfSignedCerts
Flag allowing self-signed certificates (insecure)

.OUTPUTS
Sync-VcdOrganizationMapping.ps1 generates/updates a csv file and returns a PowerShell Object containing all data

.EXAMPLE
Sync-VcdOrganizationMapping.ps1 -VSPC "vspc.contoso.local" -VspcUser "contoso\jsmith" -VspcPass "password" -VBR "vbr.contoso.local" -VbrUser "contoso\jsmith" -VbrPass "password"

Description
-----------
Connect to the specified VSPC & VBR server using a username/password and attempt to map a VCD Organization to a VSPC Company

.EXAMPLE
Sync-VcdOrganizationMapping.ps1 -VSPC "vspc.contoso.local" -VspcCredential (Get-Credential) -VBR "vbr.contoso.local" -VbrCredential (Get-Credential)

Description
-----------
PowerShell credentials object is supported

.EXAMPLE
Sync-VcdOrganizationMapping.ps1 -VSPC "vspc.contoso.local" -VspcPort 9999 -VspcUser "contoso\jsmith" -VspcPass "password" -VBR "vbr.contoso.local" -VbrPort 9999 -VbrUser "contoso\jsmith" -VbrPass "password"

Description
-----------
Connecting to a VSPC and/or VBR server using a non-standard API port

.EXAMPLE
Sync-VcdOrganizationMapping.ps1 -VSPC "vspc.contoso.local" -VspcUser "contoso\jsmith" -VspcPass "password" -VBR "vbr.contoso.local" -VbrUser "contoso\jsmith" -VbrPass "password" -AllowSelfSignedCerts

Description
-----------
Connecting to a VSPC and/or VBR server that uses Self-Signed Certificates (insecure)

.EXAMPLE
Sync-VcdOrganizationMapping.ps1 -VSPC "vspc.contoso.local" -VspcUser "contoso\jsmith" -VspcPass "password" -VBR "vbr.contoso.local" -VbrUser "contoso\jsmith" -VbrPass "password" -IncludeMapped

Description
-----------
Include already mapped organizations in the output results

.NOTES
NAME:  Sync-VcdOrganizationMapping.ps1
VERSION: 1.0
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
    [Switch] $IncludeMapped,
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

Function Confirm-Mapping {
    param(
        [System.Collections.ArrayList] $obj,
        [string] $id
    )

    # Is object empty?
    if ($null -eq $obj) {
        # No mappings found.
        return $false
    }

    # If mapping already exists, return true.
    if ($obj.VCD_Organization_Id -contains $id) {
        return $true
    }
    else {
        # Otherwise, return false.
        return $false
    }
}

Function New-Mapping {
    param(
        [System.Collections.ArrayList] $map,
        [System.Collections.ArrayList] $out,
        [string] $vcdHostname,
        [string] $vcdOrgName,
        [string] $vcdOrgId,
        [string] $vspcOrgName,
        [string] $vspcOrgId,
        [string] $method        
    )

    # Create mapping
    $object = [PSCustomObject] @{
        VCD_Organization_Name = $vcdOrgName
        VSPC_Company_Name     = $vspcOrgName
        VCD_Organization_Id   = $vcdOrgId
        VSPC_Organization_Id  = $vspcOrgId
        VCD_Hostname          = $vcdHostname
        VSPC_Hostname         = $VSPC
        Mapping_Method        = $method
    }
    [ref] $null = $map.Add($object)
    Clear-Variable -Name object

    # Create output
    $object = [PSCustomObject] @{
        Mapping               = "SUCCESS"
        VCD_Organization_Name = $vcdOrgName
        VSPC_Company_Name     = $vspcOrgName
        Mapping_Method        = $method
    }
    [ref] $null = $out.Add($object)
    Clear-Variable -Name object

    return $map, $out
}

# Initializing global variables
[string] $vbrBaseUrl = "https://" + $VBR + ":" + $VbrPort
[string] $vbrApiVersion = "1.1-rev1"
[string] $vspcBaseUrl = "https://" + $VSPC + ":" + $VspcPort
[string] $vspcApiVersion = "3.4"

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
}

### End - Pre-check validation

### VBR API interaction

# Retrieve VCD servers
[string] $url = $vbrBaseUrl + "/api/v1/inventory"
Write-Verbose "POST - $url"
$headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
$headers.Add("Content-Type", "application/json")
$headers.Add("Authorization", "bearer $vbrToken")
$headers.Add("x-api-version", $vbrApiVersion)  # API versioning for backwards compatibility
$body = @"
{
    "pagination": {
        "skip": 0,
        "limit": 500
    },
    "filter": {
        "type": "PredicateExpression",
        "property": "type",
        "operation": "equals",
        "value": "CloudDirectorServer"
    }
}
"@
try {
    $response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $body -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts
}
catch {
    Write-Error "ERROR: Retrieving VCD servers failed!"
    throw
}

# Are VCD servers present?
if ($null -eq $response.data) {
    Write-Warning "No VCD servers were found on the specified VBR server. Exiting script now..."
    Exit
}

# Loop through each VCD server
$organizations = [System.Collections.ArrayList]::new()
foreach ($vcd in $response.data.hostName) {	
    # Retrieve VCD Organizations
    [string] $url = $vbrBaseUrl + "/api/v1/inventory/$vcd"
    Write-Verbose "POST - $url"
    $headers = New-Object "System.Collections.Generic.Dictionary[[string],[string]]"
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Authorization", "bearer $vbrToken")
    $headers.Add("x-api-version", $vbrApiVersion)  # API versioning for backwards compatibility
    $body = @"
{
    "pagination": {
        "skip": 0,
        "limit": 5000
    },
    "filter": {
        "type": "PredicateExpression",
        "property": "type",
        "operation": "equals",
        "value": "Organization"
    }
}
"@
    try {
        $response = Invoke-RestMethod $url -Method 'POST' -Headers $headers -Body $body -ErrorAction Stop -SkipCertificateCheck:$AllowSelfSignedCerts

        if ($null -eq $response.data) { break }  # empty response. skipping loop iteration
    }
    catch {
        Write-Error "ERROR: Retrieving VCD Organizations failed!"
        throw
    }

    $response.data | ForEach-Object {
        [ref] $null = $organizations.Add($_)
    }    
}

# Are VCD Organizations present?
if ($null -eq $organizations.name) {
    Write-Warning "No VCD Organizations were found on the specified VBR server. Exiting script now..."
    Exit
}

### End - VBR API interaction

### VSPC API interaction

# Retrieve Companies
[string] $url = $vspcBaseUrl + "/api/v3/organizations/companies?expand=Organization&limit=500"
$companies = Get-VspcApiResult -URL $url -Type "Companies" -Token $vspcToken

# Retrieve Site Resources (VCD Cloud Connect Tenants)
[string] $url = $vspcBaseUrl + "/api/v3/organizations/companies/sites?filter=[{""property"":""cloudTenantType"",""operation"":""equals"",""collation"":""ignorecase"",""value"":""VCD""}]&limit=500"
$sites = Get-VspcApiResult -URL $url -Type "VCD Site Resources" -Token $vspcToken

### End - VSPC API interaction

### Mapping each VCD Organization to a VSPC Company

# Initializing output objects
$mapping = [System.Collections.ArrayList]::new()
$output = [System.Collections.ArrayList]::new()

# Import mappings file
try {
    $file = "$PSScriptRoot\VcdOrganizationMapping.csv"
    if (Test-Path -Path $file) {
        $csv = Import-Csv -Path $file
        Write-Verbose "CSV found & imported: $file"

        $csv | ForEach-Object {
            [ref] $null = $mapping.Add($_)
        }
    }
    else {
        Write-Verbose "CSV not found. New CSV will be created: $file"
    }
}
catch {
    Write-Error "ERROR: Importing CSV mappings failed!"
    throw
}

# Mapping each VCD Organization
foreach ($org in $organizations) {
    Write-Verbose "Mapping $($org.name) ($($org.objectId))"
    
    # Reducing organization vCloud URN to UID
    $uid = $org.objectId -replace "urn:vcloud:org:", ""
	
    # Has organization already been mapped?
    if (Confirm-Mapping -obj $mapping -id $uid) {
        Write-Verbose "Organization ($($org.name)) has already been mapped."
        
        # Including already mapped objects in the output
        if ($IncludeMapped) {
            Write-Verbose "Adding already mapped Organization ($($org.name)) to output."
            $match = $mapping | Where-Object { $_.VCD_Organization_Id -eq $uid }
            $object = [PSCustomObject] @{
                Mapping               = "SUCCESS"
                VCD_Organization_Name = $match.VCD_Organization_Name
                VSPC_Company_Name     = $match.VSPC_Company_Name
                Mapping_Method        = $match.Mapping_Method
            }

            [ref] $null = $output.Add($object)
            Clear-Variable -Name match, object
        }
        
        # Skip to next organization in loop
        Continue
    }

    ### Mapping criteria - VCD-backed Cloud Connect Tenants
    # Look for matching VCD-backed Cloud Connect Tenant
    $match = $sites | Where-Object { $_.vCloudOrganizationUid -eq $uid }
    if ($match) {
        Write-Verbose "VCD-backed Cloud Connect Tenant found!"
		
        # Identify VSPC Company associated with tenant
        $company = $companies | Where-Object { $_.instanceUid -eq $match.companyUid }

        # Mapping
        $mapping, $output = New-Mapping `
            -map $mapping `
            -out $output `
            -vcdHostname $org.hostName `
            -vcdOrgName $org.name `
            -vcdOrgId $uid `
            -vspcOrgName $company.name `
            -vspcOrgId $company.instanceUid `
            -method "cloud_connect"
        
        # Skip to next organization in loop
        Continue
    }
    Clear-Variable -Name match

    ### Mapping criteria - Identical name for VCD Organization & VSPC Company
    # Look for matching names
    $match = $companies | Where-Object { $_.name -eq $org.name }
    if ($match) {
        Write-Verbose "Matching name found!"
		
        # Mapping
        $mapping, $output = New-Mapping `
            -map $mapping `
            -out $output `
            -vcdHostname $org.hostName `
            -vcdOrgName $org.name `
            -vcdOrgId $uid `
            -vspcOrgName $match.name `
            -vspcOrgId $match.instanceUid `
            -method "name"
        
        # Skip to next organization in loop
        Continue
    }
    Clear-Variable -Name match

    ### Mapping criteria - Already existing mappings (different VSPC servers)
    # Look for matching VCD Organization name
    $match = $mapping | Where-Object { $_.VCD_Organization_Name -eq $org.name }
    if ($match) {
        Write-Verbose "A similar mapping has been found!"
		
        # Is there a VSPC Company with the same name?
        $match2 = $companies | Where-Object { $_.name -eq $match.VSPC_Company_Name }
        if ($match2) {
            Write-Verbose "A VSPC Company with the same name ($($company.name)) has been found!"

            # Mapping
            $mapping, $output = New-Mapping `
                -map $mapping `
                -out $output `
                -vcdHostname $org.hostName `
                -vcdOrgName $org.name `
                -vcdOrgId $uid `
                -vspcOrgName $match2.name `
                -vspcOrgId $match2.instanceUid `
                -method "different_vspc"
        }
        Clear-Variable -Name match2
        
        # Skip to next organization in loop
        Continue
    }
    Clear-Variable -Name match

    # Unable to find match
    Write-Verbose "Unable to find match for the $($org.name) organization."
    $object = [PSCustomObject] @{
        Mapping               = "INCOMPLETE"
        VCD_Organization_Name = $org.name
        VSPC_Company_Name     = $null
        Mapping_Method        = $null
    }
    [ref] $null = $output.Add($object)
    Clear-Variable -Name object
}

# Creating/Updating CSV mapping file
try {
    if ($mapping) {
        $mapping | Export-Csv -Path $file
        Write-Verbose "CSV mapping file updated: $file"
    }
}
catch {
    Write-Error "ERROR: Updating CSV mapping file failed!"
    throw
}

### End - Mapping each VCD Organization to a VSPC Company

return $output
