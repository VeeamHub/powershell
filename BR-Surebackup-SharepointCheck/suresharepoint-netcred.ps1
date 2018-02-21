<# 
   .Synopsis 
    Allows you to verifiy if Sharepoint is succesfully working in your Virtual Lab (Surebackup)
   .Example 
	Schedule the script via the Application Group or via the "Surebackup" job > "Linked Job" section. Configure credentials in the application group. Use the -server parameter to pass the ip of the server
   .Notes 
    NAME: Surebackup Sharepoint Check
    AUTHOR: Timothy Dewin, Veeam
    LASTEDIT: 01-07-2016 
    KEYWORDS: Surebackup, Sharepoint, Veeam
 #> 
param(
    $server = "sqlandsp",
    $path = "/Shared%20Documents/contenttest.txt",
    $content = "sharepoint is working succesfully",
    [bool]$https = $false
)
Write-host ("Running as {0}" -f (whoami))

if($path.Length -eq 0 -or $path[0] -ne "/") {
 $path = ("/{0}" -f $path)
}
$sec = ""
if($https) { $sec = "s" }


$dlstring = ("http{2}://{0}{1}" -f $server,$path,$sec)

$web = New-Object Net.WebClient
$failure = 1
try {
    $web.UseDefaultCredentials = $true
    $contentread = $web.DownloadString($dlstring)
    if($contentread -eq $content ) {
        write-host ("Got match ""{0}"" in {1}" -f $content,$dlstring)
        $failure = 0
    }
    else {
        write-host ("No match ""{0}"" on {1} != ""{2}""" -f $contentread,$dlstring,$content)
        $failure = 1
    }
} catch {
    write-host $Error[0].Exception.Message
    $failure = 1
}
exit $failure