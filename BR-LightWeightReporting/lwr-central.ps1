[cmdletbinding()]
param(
$lwrpath="c:\veeamlwr",
$uniqueidfilter="",
$runtime=(get-date),
$startinterval=$runtime.AddDays(-1),
$stopinterval=$runtime,
[ValidateSet("licensequery","jobquery","rporuntime")]$mode="rporuntime",
$zip=$true,
$rpodays=1,
$recursivefilelist=$true
)



Function Convert-FromUnixDate ($UnixDate) {
   return [DateTimeOffset]::FromUnixTimeSeconds($UnixDate).LocalDateTime
}

class LightWeightReportingFile {
    [string]$fullpath
    [string]$name
    [string]$uniqueid
    [datetime]$date
    LightWeightReportingFile($fullpath,$name,$uniqueid,$date) {
        $this.fullpath = $fullpath
        $this.name = $name
        $this.uniqueid = $uniqueid
        $this.date = $date
    }
}



if (-not (Test-Path -Path $lwrpath -PathType Container)) {
    Write-Verbose "$lwrpath does not exist, creating, no data yet"
    New-Item -Path $lwrpath -ItemType Directory | out-null
} else {
    Write-Verbose "$lwrpath exists, looking for files"
    Write-Verbose "start time $startinterval"
    Write-Verbose "stop time $stopinterval"

    $getfilelist = @{
      Path = $lwrpath
      Filter = "*.lwr"
    }
    if ($recursivefilelist) {
        $getfilelist["recurse"] = $true
    }
    $files = Get-ChildItem @getfilelist

    $parsedFiles = @()
    foreach ($file in $files) {
        if ($file.name -match "^(.*)_([0-9]+).lwr$") {
            $uid = $Matches[1]
            $date = (Convert-FromUnixDate $Matches[2])
            $parsedFiles += [LightWeightReportingFile]::new($file.FullName,$file.Name,$uid,$date)
        }
    }
    if ($uniqueidfilter -ne "") {
        $parsedFiles = $parsedFiles | where { $_.uniqueid -eq $uniqueidfilter}
    }
    $groups = $parsedFiles | Sort-Object -Property date | Group-Object -Property uniqueid

    $targetfiles = @()
    foreach($uidgroup in $groups) {
        Write-Verbose ("Identified with {0}" -f $uidgroup.Name)
        $sorted = $uidgroup.Group | Sort-Object -Descending -Property date
        $selected = $sorted[0]

        $datefiltered = $sorted | ? { $_.date -gt  $startinterval -and $_.date -lt $stopinterval }
        if ($datefiltered.Count -gt 0) {
            $selected = $datefiltered[0]
        } else {
            Write-host -ForegroundColor Red ("Selecting most recent for {0} due to no version in the interval ({1})" -f $uidgroup.Name,$selected.date)
        }
        $targetfiles += $selected
    }

    $parsedDataSet = @() 
    foreach($tf in $targetfiles) {
        if ($zip) {
            $data = ""
            $fr = [System.IO.File]::Open($tf.fullpath,[System.IO.FileMode]::Open)
            $gstreamread = [System.IO.Compression.GZipStream]::new($fr,[System.IO.Compression.CompressionMode]::Decompress)
            $reader = [System.IO.StreamReader]::new($gstreamread,[System.Text.UTF8Encoding])
            $data = $reader.ReadToEnd()
            $fr.close()
            $parsedData = $data | ConvertFrom-Json
            $parsedDataSet += $parsedData

            Write-Verbose $data
        } else {
            $parsedData = get-content $tf.fullpath | ConvertFrom-Json
            $parsedDataSet += $parsedData
        }
      
    }

    switch($mode) {
        "licensequery" {
            $table = $parsedDataSet | select @{n="Date";e={(Convert-FromUnixDate $_.date)}},sitename,socketsused,socketsinstalled,instanceused,instanceinstalled
            $table | ft
        }
        "jobquery" {
            $jobtab = @()
            foreach($pd in $parsedDataSet) {
               $jobtab += $pd.jobs | select @{n="Site";e={$pd.sitename}},@{n="UpdateStatus";e={(Convert-FromUnixDate $pd.date)}},jobname,currentstatus,@{n="Lastrun";e={(Convert-FromUnixDate $_.lastrun)}},laststatus
            }
            $jobtab | ft
        }
        "rporuntime" {
            $rpo = $runtime.adddays(-$rpodays)

            foreach($pd in $parsedDataSet) {
                $pddate = (Convert-FromUnixDate $pd.date)
                
                if ($pddate -lt $rpo) {
                    write-host -ForegroundColor Red ("Attention : Site {0,-20} : old data {1}" -f $pd.sitename,$pddate)
                }
                foreach ($job in $pd.jobs) {
                    $lrc = (Convert-FromUnixDate $job.lastrun)
                    if ($job.laststatus -ne "Success") {
                        write-host -ForegroundColor Red ("Job Failed : Site {0,-20} : {1,-20} - {3,-20} - {2}" -f $pd.sitename,$job.jobname,$job.laststatus,$lrc)
                    } else {
                        if ($lrc -lt $rpo) {
                            write-host -ForegroundColor yellow ("RPO Breach : Site {0,-20} : {1,-20} - {3,-20} - {2}" -f $pd.sitename,$job.jobname,$job.laststatus,$lrc)
                        } else {
                            write-host ("Job OK     : Site {0,-20} : {1,-20} - {3,-20} - {2}" -f $pd.sitename,$job.jobname,$job.laststatus,$lrc)
                        }
                    }
                }
               
            }
        }
        
    }
    
}