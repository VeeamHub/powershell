#lightweight reporting

[cmdletbinding()]
param(
$lwrpath="c:\veeamlwr",
$uniqueid="99570f44-c050-11ea-b3de-0242ac13000x",
$sitename="Main Data Center",
$zip=$true
)


<#
 Class definitions
#>
class LightWeightJob 
{
    [string]$jobname
    [string]$currentstatus
    [string]$jobtype
    [string]$sourcetype
    [datetime]$lastrun
    [string]$laststatus

    LightWeightJob() {}
    LightWeightJob($jobname,$currentstatus,$jobtype,$sourcetype,$lastrun,$laststatus) {
        $this.jobname = $jobname
        $this.currentstatus = $currentstatus
        $this.jobtype = $jobtype
        $this.sourcetype = $sourcetype
        $this.lastrun = $lastrun
        $this.laststatus = $laststatus
    }
}
Class LightWeightReport
{
    [DateTime]$date
    [string]$uniqueid
    [string]$sitename
    [int]$socketsinstalled
    [int]$socketsused
    [int]$instanceinstalled
    [int]$instanceused
    [LightWeightJob[]]$jobs

    LightWeightReport() {
        $this.jobs = @()
    }
    LightWeightReport([DateTime]$date,[string]$uniqueid,[string]$sitename,[int]$socketsinstalled,[int]$socketsused,[int]$instanceinstalled,[int]$instanceused) {
     $this.date = $date
     $this.uniqueid = $uniqueid
     $this.sitename = $sitename
     $this.socketsinstalled = $socketsinstalled
     $this.socketsused = $socketsused
     $this.instanceinstalled = $instanceinstalled
     $this.instanceused = $instanceused
     $this.jobs = @()
    }
}

Add-PSSnapin VeeamPSSnapin

if (-not (Test-Path -Path $lwrpath -PathType Container)) {
    Write-Verbose "$lwrpath does not exist, creating"
    New-Item -Path $lwrpath -ItemType Directory | out-null
}


#use now to have a consistent time over the script
$now = (Get-Date)
#use 
$collectpath = Join-Path -Path $lwrpath -ChildPath ("{0}_{1}.lwr" -f $uniqueid,$now.ToString("yyyyMMdd_HHmmss"))


$license = Get-VBRInstalledLicense
[int]$socketsinstalled = 0
[int]$socketsused = 0
[int]$instanceinstalled = 0
[int]$instanceused = 0

foreach ($sl in $license.SocketLicenseSummary) {
    $socketsinstalled += $sl.LicensedSocketsNumber
    $socketsused += $sl.UsedSocketsNumber
}

foreach ($il in $license.InstanceLicenseSummary) {
    $instanceinstalled += $il.LicensedInstancesNumber
    $instanceused += $il.UsedInstancesNumber
}

$lwr = [LightWeightReport]::new($now,$uniqueid,$sitename,$socketsinstalled,$socketsused,$instanceinstalled,$instanceused)


foreach($job in (get-vbrjob)) {
    $ls = $job.FindLastSession()
    $lwr.jobs += [LightWeightJob]::new($job.Name,$job.GetLastState(),$job.JobType,$job.SourceType,$ls.EndTimeUTC,$ls.Result)
}

Write-Verbose "Creating $collectpath"
$json = $lwr | ConvertTo-Json
if ($zip) {
    $data = [Text.Encoding]::UTF8.GetBytes($json)
    $fr = [System.IO.File]::Open($collectpath,[System.IO.FileMode]::CreateNew)
    $gstream = [System.IO.Compression.GZipStream]::new($fr,[System.IO.Compression.CompressionMode]::Compress)
    $gstream.Write($data,0,$data.Length)
    $gstream.Close()
    $fr.close()
} else {
    $json | Out-File -FilePath $collectpath
}




