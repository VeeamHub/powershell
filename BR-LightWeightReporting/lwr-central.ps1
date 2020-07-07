[cmdletbinding()]
param(
$lwrpath="c:\veeamlwr",
$uniqueidfilter="",
$runtime=(get-date),
$startinterval=$runtime.AddDays(-1),
$stopinterval=$runtime,
[ValidateSet("licensequery","jobquery")]$mode="jobquery",
$zip=$true
)

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
    $files = Get-ChildItem -Filter "*.lwr" -Path $lwrpath
    $parsedFiles = @()
    foreach ($file in $files) {
        if ($file.name -match "^(.*)_([0-9]+_[0-9]+).lwr$") {
            $uid = $Matches[1]
            $date = [System.DateTime]::ParseExact($Matches[2],"yyyyMMdd_HHmmss",$null)
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
        } else {
            $parsedData = get-content $tf.fullpath | ConvertFrom-Json
            $parsedDataSet += $parsedData
        }
      
    }

    switch($mode) {
        "licensequery" {
            $table = $parsedDataSet | select date,sitename,socketsused,socketsinstalled,instanceused,instanceinstalled
            $table | ft
        }
        "jobquery" {
            $jobtab = @()
            foreach($pd in $parsedDataSet) {
               $jobtab += $pd.jobs | select @{n="Site";e={$pd.sitename}},@{n="UpdateStatus";e={$pd.date}},jobname,currentstatus,lastrun,laststatus
            }
            $jobtab | ft
        }
        
    }
    
}