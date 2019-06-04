function create_cc_tenant
{
### Create new VCC tenant
# Ask tenant account name
$tenant_account = Read-Host -Prompt 'Input tenant name '
# Password is randomly generated
$asci = [char[]]([char]33..[char]95) + ([char[]]([char]97..[char]126))
$tenant_pwd = (1..$(Get-Random -Minimum 9 -Maximum 14) | % {$asci | get-random}) -join “”
 
# Create the tenant
 
try
{
    Add-VBRCloudTenant -Name $tenant_account -Password $tenant_pwd -Description $tenant_account
    Write-Host "New tenant $tenant_account has been created, please save the password: $tenant_pwd "
}
 
catch
{
    Write-Output "User creation failed, see errors below."
    throw
}

 ### Assign Backup Resources
 $tenant = Get-VBRCloudTenant -Name $tenant_account
 $repository = Get-VBRBackupRepository -ScaleOut -Name SOBR-REFS
 $repository_name = $tenant_account + "_repository"
 $cloudrepo = New-VBRCloudTenantResource -Quota 200 -Repository $repository -RepositoryFriendlyName $repository_name
 # List available Gateway pools to be used
 $cgpool = Get-VBRCloudGatewayPool | Format-List -Property Name
 Write-Host "Avaiable Gateway pools to be assigned are:"
 Echo $cgpool
 $selected_cgpool = Read-Host -Prompt 'Write the desired Gateway pool '
 $tenant_cgpool = Get-VBRCloudGatewayPool -Name $selected_cgpool
 Set-VBRCloudTenant -CloudTenant $tenant -EnableResources -Resources $cloudrepo -EnableBackupProtection -BackupProtectionPeriod 14 -GatewayPool $tenant_cgpool -GatewaySelectionType GatewayPool -EnableGatewayFailover -MaxConcurrentTask 1
}