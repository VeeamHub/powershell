#Edit the param section below only.
param(
$server = "myvcenter.domain.com",
$username = "username@domain.com",
$password = "MyPassword"
)

$exit = 1
try {
Connect-VIServer $server -username $username -password $password
$vms = Get-VM
    if ($vms.Count -gt 3){
        Write-Output "There were VMs returned."
        }
    else {
        Write-Output "No VMs were returned, so something is wrong."
        $exit = 1}
$tags = Get-Tag
    if ($tags.Count -gt 0){
        Write-Output "There were some tags returned."
        }
    else {
        Write-Output "No tags were returned, so it's possible the inventory service is not functioning."
        $exit = 1}
$storagepolicies = Get-SpbmStoragePolicy
    if ($storagepolicies.Count -gt 0){
        Write-Output "There were some storage policies returned."
        }
    else {
        Write-Output "No storage policies were returned, so the profile-driven storage service might be malfunctioning or unavailable."
        $exit = 1}
$exit = 0
        
    }
catch {
    Write-Host $Error[0].Exception.Message
    $exit = 1
    }
Write-Host "The exit code from this session will be $exit."
exit $exit
