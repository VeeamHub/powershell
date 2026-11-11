[cmdletbinding()]
param(
$lwrpath="c:\veeamlwr",
$ftphost="127.0.0.1",
$username="lwr",
$password="password")

if (-not (Test-Path -Path $lwrpath -PathType Container)) {
    Write-Verbose "$lwrpath does not exist, creating"
    New-Item -Path $lwrpath -ItemType Directory | out-null
}



<#
# You need to preinstall winscp binaries under c:\winscp or change the code to get this to work
#https://winscp.net/eng/docs/library_session_synchronizedirectories#powershell
#https://winscp.net/eng/docs/message_net_operation_not_supported
#>

Add-Type -Path "C:\winscp\WinSCPnet.dll"

$sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol = [WinSCP.Protocol]::Ftp
        HostName = $ftphost
        UserName = $username
        Password = $password
}
 
$session = New-Object WinSCP.Session
try {
    $session.Open($sessionOptions)

    $session.add_FileTransferred( { write-verbose "uploaded $($_.FileName)" } )
    

    $synchronizationResult = $session.SynchronizeDirectories(
    [WinSCP.SynchronizationMode]::Remote, $lwrpath, "./", $False)
 
    # Throw on any error
    $synchronizationResult.Check()
} catch {
    write-error $_
}
finally
{
    # Disconnect, clean up
    $session.Dispose()
}