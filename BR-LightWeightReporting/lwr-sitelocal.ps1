﻿#lightweight reporting

[cmdletbinding()]
param(
$lwrpath="c:\veeamlwr",
$uniqueid="99570f44-c050-11ea-b3de-0242ac13000x",
$sitename="Main Data Center",
$zip=$true,
[ValidateSet("run")]$mode="run",
$autopurgedays=30,
$makesubdir=$true,
$server="localhost"
)


Function Convert-FromUnixDate ($UnixDate) {
   return [DateTimeOffset]::FromUnixTimeSeconds($UnixDate).LocalDateTime
}
Function Convert-ToUnixDate($DateTime) {
   return [DateTimeOffset]::new($DateTime).ToUnixTimeSeconds()
}

<#
 Class definitions
#>
class LightWeightJob 
{
    [string]$jobname
    [string]$currentstatus
    [string]$jobtype
    [string]$sourcetype
    [int64]$lastrun
    [string]$laststatus

    LightWeightJob() {}
    LightWeightJob($jobname,$currentstatus,$jobtype,$sourcetype,$lastrun,$laststatus) {
        $this.jobname = $jobname
        $this.currentstatus = $currentstatus
        $this.jobtype = $jobtype
        $this.sourcetype = $sourcetype
        $this.lastrun = (Convert-ToUnixDate $lastrun)
        $this.laststatus = $laststatus
    }
}
Class LightWeightReport
{
    [int64]$date
    [string]$uniqueid
    [string]$sitename
    [string]$server
    [int]$socketsinstalled
    [int]$socketsused
    [int]$instanceinstalled
    [int]$instanceused
    [LightWeightJob[]]$jobs
    [string[]]$error

    LightWeightReport() {
        $this.jobs = @()
        $this.error = @()
    }
    LightWeightReport([DateTime]$date,[string]$uniqueid,[string]$sitename,[int]$socketsinstalled,[int]$socketsused,[int]$instanceinstalled,[int]$instanceused) {
        $this.date = (Convert-ToUnixDate $date)
        $this.uniqueid = $uniqueid
        $this.sitename = $sitename
        $this.socketsinstalled = $socketsinstalled
        $this.socketsused = $socketsused
        $this.instanceinstalled = $instanceinstalled
        $this.instanceused = $instanceused
        $this.jobs = @()
        $this.error = @()
    }

     LightWeightReport([DateTime]$date,[string]$uniqueid,[string]$sitename) {
        $this.date = (Convert-ToUnixDate $date)
        $this.uniqueid = $uniqueid
        $this.sitename = $sitename
        $this.jobs = @()
        $this.error = @()
    }

    
}

Add-PSSnapin VeeamPSSnapin



if (-not (Test-Path -Path $lwrpath -PathType Container)) {
    Write-Verbose "$lwrpath does not exist, creating"
    New-Item -Path $lwrpath -ItemType Directory | out-null
}

if ( $makesubdir ) {
    Write-Verbose "Using subdir to group data"
    $lwrpath = Join-Path -Path $lwrpath -ChildPath $uniqueid
    if (-not (Test-Path -Path $lwrpath -PathType Container)) {
        Write-Verbose "$lwrpath does not exist, creating"
        New-Item -Path $lwrpath -ItemType Directory | out-null
    }
}

#use now to have a consistent time over the script
$now = (Get-Date)
#use 
$collectpath = Join-Path -Path $lwrpath -ChildPath ("{0}_{1}.lwr" -f $uniqueid,(Convert-ToUnixDate $now))



$lwr = [LightWeightReport]::new($now,$uniqueid,$sitename)
try {
    Connect-VBRServer -Server $server
} catch {
    $lwr.error += $_
}


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

$lwr.instanceused = $instanceused
$lwr.instanceinstalled = $instanceinstalled
$lwr.socketsinstalled = $socketsinstalled
$lwr.socketsused = $socketsused
$lwr.server = (Get-VBRServerSession).server


foreach($job in (get-vbrjob)) {
    $ls = $job.FindLastSession()
    $lwr.jobs += [LightWeightJob]::new($job.Name,$job.GetLastState(),$job.JobType,$job.SourceType,$ls.EndTimeUTC.ToUniversalTime(),$ls.Result)
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

if ($autopurgedays -gt 0) {

    $getfilelist = @{
      Path = $lwrpath
      Filter = "*.lwr"
      Recurse = $true
    }
    $files = Get-ChildItem @getfilelist
    $purgedate = ($now).AddDays(-$autopurgedays)
    #for dev
    #$purgedate = ($now).AddSeconds(-$autopurgedays)
    Write-Verbose "Autopurging older than $purgedate "

    foreach ($file in $files) { 
        if ($file.name -match "^(.*)_([0-9]+).lwr$") {
            $uid = $Matches[1]
            $date = (Convert-FromUnixDate $Matches[2])
            #check if is our files
            if ($uid -eq $uniqueid) {
                if ($date -lt $purgedate) {
                    Write-Verbose "Ready to purge $file $purgedate lt $date"
                    Remove-Item $file.fullname
                } else {
                    Write-Verbose "Active $file $purgedate lt $date"
                }
            } 
        }
    }
}





