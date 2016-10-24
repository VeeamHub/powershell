param(
 [string]$JobName=$null,
 [string]$JobType="Backup",
 [int]$Max=0,
 $date=(get-date),
 [string]$File=("mr_{0,4:D4}{1,2:D2}{2,2:D2}-{3,2:D2}{4,2:D2}{5,2:D2}_{6}.html" -f $date.Year,$date.Month,$date.Day,$date.Hour,$date.Minute,$date.Second,($jobname -replace [regex]"[^a-zA-Z0-9]+","_")),
 $RPOHours=(24*365*100)
)

$defrpo = (24*365*100)

#uncomment for smaller names or replace the param structure
#$file = ("{0}.html" -f ($jobname -replace [regex]"[^a-zA-Z0-9]+","_"))

Add-PSSnapin VeeamPSSnapin

function write-reportmimicheader {
 param([System.Text.StringBuilder]$stringbuilder)
 [void]$stringbuilder.Append(@"
<?xml version="1.0" encoding="utf-16"?>
<html>
	<head>
		<META http-equiv="Content-Type" content="text/html; charset=utf-8" />
	</head>
	<body>
"@)
}

function write-reportmimicheadertable {
 param([System.Text.StringBuilder]$stringbuilder)
 [void]$stringbuilder.Append(@"
		<table cellspacing="0" cellpadding="0" width="100%" border="0" style="border-collapse: collapse;">
"@)
}

function write-reportmimicfootertable {
 param([System.Text.StringBuilder]$stringbuilder,$server)
 [void]$stringbuilder.Append(@"
			<tr>
				<td style="font-size:12px;color:#626365;padding: 2px 3px 2px 3px;vertical-align: top;font-family: Tahoma;">
"@)
 [void]$stringbuilder.Append($server)
 [void]$stringbuilder.Append(@"
                   <br>Generated with Report Mimic</td>
			</tr>
		</table>
"@)
}

function write-reportmimicfooter {
 param([System.Text.StringBuilder]$stringbuilder)
 [void]$stringbuilder.Append(@"
	</body>
</html>
"@)
}


function write-reportmimicrecordheader {
 param([System.Text.StringBuilder]$stringbuilder,$job,$session,$calcs)


 [void]$stringbuilder.Append(@"
 <tr><td style="border:none; padding: 0px;font-family: Tahoma;font-size: 12px;"><table cellspacing="0" cellpadding="0" width="100%" border="0" style="border-collapse: collapse;">
"@)

if (((get-member -InputObject $calcs -Name "RPOColor") -ne $null) -and $calcs.RPOColor -ne $null) {
     [void]$stringbuilder.Append(@" 
            <tr style="height:16px"><td style="width: 80%;border: none;background-color: 
"@)
 [void]$stringbuilder.Append($calcs.RPOColor)
      [void]$stringbuilder.Append(@" 
            ;"><td style="width: 20%;border: none;background-color: 
"@)
 [void]$stringbuilder.Append($calcs.RPOColor)
     [void]$stringbuilder.Append(@" 
            ;color: White;font-family: Tahoma;font-size: 12px;padding: 0 15px 0px 15px;">
"@)
 [void]$stringbuilder.Append($calcs.RPOText)
     [void]$stringbuilder.Append(@"
</td></tr>
"@)
} else {

}

 [void]$stringbuilder.Append(@" 
 <tr style="height:70px"><td style="width: 80%;border: none;background-color: 
"@)
 [void]$stringbuilder.Append($calcs.Color)
 [void]$stringbuilder.Append(@"
;color: White;font-weight: bold;font-size: 16px;height: 70px;vertical-align: bottom;padding: 0 0 17px 15px;font-family: Tahoma;">
"@)
 [void]$stringbuilder.Append($calcs.Jobtype)
 [void]$stringbuilder.Append(" job: ")
 [void]$stringbuilder.Append($calcs.Jobname)

 [void]$stringbuilder.Append(@"
 <div class="jobDescription" style="margin-top: 5px;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($calcs.Jobdescription)
 [void]$stringbuilder.Append(@"
</div></td><td style="border: none;padding: 0px;font-family: Tahoma;font-size: 12px;background-color:
"@)
 [void]$stringbuilder.Append($calcs.Color)
 [void]$stringbuilder.Append(@"
;color: White;font-weight: bold;font-size: 16px;height: 70px;vertical-align: bottom;padding: 0 0 17px 15px;font-family: Tahoma;">
"@)
 [void]$stringbuilder.Append($calcs.Status)
 [void]$stringbuilder.Append(@"
<div class="jobDescription" style="margin-top: 5px;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($calcs.ProcessedObjects)
 [void]$stringbuilder.Append(" of ")
 [void]$stringbuilder.Append($calcs.TotalObjects)
 [void]$stringbuilder.Append(@"
 VMs processed</div></td></tr><tr><td colspan="2" style="border: none; padding: 0px;font-family: Tahoma;font-size: 12px;"><table width="100%" cellspacing="0" cellpadding="0" class="inner" border="0" style="margin: 0px;border-collapse: collapse;"><tr style="height: 17px;">
<td colspan="9" class="sessionDetails" style="border-style: solid; border-color:#a7a9ac; border-width: 1px 1px 0 1px;height: 35px;background-color: #f3f4f4;font-size: 16px;vertical-align: middle;padding: 5px 0 0 15px;color: #626365; font-family: Tahoma;"><span>
"@)
 [void]$stringbuilder.Append($calcs.LongStartDateTime)
 [void]$stringbuilder.Append(@"
 </span> </td>
									</tr>
									<tr style="height: 17px;">
										<td nowrap="" style="width: 1%;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
											<b>Success</b>
										</td>
										<td nowrap="" style="width:85px;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($calcs.Success)
 [void]$stringbuilder.Append(@"
</td>
										<td nowrap="" style="width:85px;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
											<b>Start time</b>
										</td>
										<td nowrap="" style="width:85px;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($calcs.LongCreationTime)
 [void]$stringbuilder.Append(@"
</td>
										<td nowrap="" style="width:85px;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
											<b>Total size</b>
										</td>
										<td nowrap="" style="width:85px;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($calcs.TotalSize)
 [void]$stringbuilder.Append(@"
</td>
										<td nowrap="" style="width:85px;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
											<b>Backup size</b>
										</td>
										<td nowrap="" style="width:85px;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($calcs.BackupSize)
 [void]$stringbuilder.Append(@"
</td>
										<td rowspan="3" style="border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;vertical-align: top;">
											<span class="small_label" style="font-size: 10px;">
"@)
 [void]$stringbuilder.Append($calcs.Details)
 [void]$stringbuilder.Append(@"
</span>
										</td>
									</tr>
									<tr style="height: 17px;">
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
											<b>Warning</b>
										</td>
										<td style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($calcs.Warning)
 [void]$stringbuilder.Append(@"
</td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
											<b>End time</b>
										</td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($calcs.LongEndTime)
 [void]$stringbuilder.Append(@"
</td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
											<b>Data read</b>
										</td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($calcs.DataRead)
 [void]$stringbuilder.Append(@"
</td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
											<b>Dedupe</b>
										</td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($calcs.Dedupe)
 [void]$stringbuilder.Append(@"
</td>
									</tr>
									<tr style="height: 17px;">
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
											<b>Error</b>
										</td>
										<td style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($calcs.Failed)
 [void]$stringbuilder.Append(@"
</td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
											<b>Duration</b>
										</td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)

 [void]$stringbuilder.Append($calcs.Duration)
 [void]$stringbuilder.Append(@"

										</td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
											<b>Transferred</b>
										</td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($calcs.TransferSize)
 [void]$stringbuilder.Append(@"
</td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
											<b>Compression</b>
										</td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($calcs.Compression)
 [void]$stringbuilder.Append(@"
</td>
									</tr>
									<tr style="height: 17px;">
										<td colspan="9" nowrap="" style="height: 35px;background-color: #f3f4f4;font-size: 16px;vertical-align: middle;padding: 5px 0 0 15px;color: #626365; font-family: Tahoma;border: 1px solid #a7a9ac;">
                            Details
										</td>
									</tr>
									<tr class="processObjectsHeader" style="height: 23px">
										<td nowrap="" style="background-color: #e3e3e3;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;border-top: none;font-family: Tahoma;font-size: 12px;">
											<b>Name</b>
										</td>
										<td nowrap="" style="background-color: #e3e3e3;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;border-top: none;font-family: Tahoma;font-size: 12px;">
											<b>Status</b>
										</td>
										<td nowrap="" style="background-color: #e3e3e3;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;border-top: none;font-family: Tahoma;font-size: 12px;">
											<b>Start time</b>
										</td>
										<td nowrap="" style="background-color: #e3e3e3;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;border-top: none;font-family: Tahoma;font-size: 12px;">
											<b>End time</b>
										</td>
										<td nowrap="" style="background-color: #e3e3e3;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;border-top: none;font-family: Tahoma;font-size: 12px;">
											<b>Size</b>
										</td>
										<td nowrap="" style="background-color: #e3e3e3;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;border-top: none;font-family: Tahoma;font-size: 12px;">
											<b>Read</b>
										</td>
										<td nowrap="" style="width:1%;background-color: #e3e3e3;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;border-top: none;font-family: Tahoma;font-size: 12px;">
											<b>Transferred</b>
										</td>
										<td nowrap="" style="background-color: #e3e3e3;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;border-top: none;font-family: Tahoma;font-size: 12px;">
											<b>Duration</b>
										</td>
										<td style="background-color: #e3e3e3;padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;border-top: none;font-family: Tahoma;font-size: 12px;">
											<b>Details</b>
										</td>
									</tr>

"@)
}
function write-reportmimicrecordvm {
 param([System.Text.StringBuilder]$stringbuilder,$vm)
 [void]$stringbuilder.Append(@"
									<tr style="height: 17px;">
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($vm.Name)
 [void]$stringbuilder.Append(@"
 </td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
											<span style="color: 
"@)
 [void]$stringbuilder.Append($vm.Color)
 [void]$stringbuilder.Append(@"
;">
"@)
 [void]$stringbuilder.Append($vm.Status)
 [void]$stringbuilder.Append(@"
 </span>
										</td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($vm.StartTime)
 [void]$stringbuilder.Append(@"
 </td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($vm.EndTime)
 [void]$stringbuilder.Append(@"
 </td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($vm.Size)
 [void]$stringbuilder.Append(@"
 </td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($vm.Read)
 [void]$stringbuilder.Append(@"
 </td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($vm.Transferred)
 [void]$stringbuilder.Append(@"
 </td>
										<td nowrap="" style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
"@)
 [void]$stringbuilder.Append($vm.Duration)
 [void]$stringbuilder.Append(@"
 
										</td>
										<td style="padding: 2px 3px 2px 3px;vertical-align: top;border: 1px solid #a7a9ac;font-family: Tahoma;font-size: 12px;">
											<span class="small_label" style="font-size: 10px;">
"@)
 [void]$stringbuilder.Append($vm.Details)
 [void]$stringbuilder.Append(@"
 </span>
										</td>
									</tr>

"@)
}
function write-reportmimicrecordfooter {
 param([System.Text.StringBuilder]$stringbuilder)
  [void]$stringbuilder.Append(@"
								</table>
							</td>
						</tr>
					</table>
				</td>
			</tr>
			<tr>
				<td> </td>
			</tr>
"@)
}


function write-reportmimicrecord {
 param([System.Text.StringBuilder]$stringbuilder,$job,$session,$rpo,$rpodate,$rpohours)

 $calcs = calculate-job -session $session -job $job -rpo $rpo -rpodate $rpodate  -rpohours $rpohours

 write-reportmimicrecordheader -stringbuilder $stringbuilder -job $job -session $session -calcs $calcs 
 foreach ($vm in $calcs.vms) {
    write-reportmimicrecordvm -stringbuilder $stringbuilder -vm $vm
 }

 write-reportmimicrecordfooter -stringbuilder $stringbuilder
}

function write-reportmimicrecordempty {
 param([System.Text.StringBuilder]$stringbuilder,$job)
 [void]$stringbuilder.Append(@"
 <tr><td style="border:none; padding: 0px;font-family: Tahoma;font-size: 12px;"><table cellspacing="0" cellpadding="0" width="100%" border="0" style="border-collapse: collapse;">
"@)

 [void]$stringbuilder.Append(@" 
            <tr style="height:16px"><td colspan=2 style="width: 100%;border: none;background-color:#fb9895 ;color: White;font-family: Tahoma;font-size: 18px;padding: 17px 0px 17px 15px;">Could not find any session for: 
"@)
 [void]$stringbuilder.Append(("{0}<br>({1})" -f $job.Name,$job.description))
     [void]$stringbuilder.Append(@"
</td></tr><tr><td> </td></tr>
"@)
}




function get-humanreadable {
 param([double]$numc)

 $num = $numc+0

 $trailing= "","K","M","G","T","P","E"
 $i=0

 while($num -gt 1024 -and $i -lt 6) {
  $num= $num/1024
  $i++
 }

 return ("{0:f1} {1}B" -f $num,$trailing[$i])
}

function get-rpmcolor {
 param($text,[bool]$isbg=$true) 
 
 $prefix = "text"
 if ($isbg) { $prefix = "" }
 $colors = @{green="#00B050";textgreen="#00B050";orange="#ffd96c";textorange="#E0A251";red="#fb9895";textred="#ff0000"}
 if ($text -ieq "success") {
   return $colors[("{0}green" -f $prefix)]
 } elseif ($text -ieq "warning" -or $text -ieq "none" -or $text -ieq "pending") {
   return $colors[("{0}orange" -f $prefix)]
 } 
 
 return $colors[("{0}red" -f $prefix)]
}

function get-diffstring {
    param([System.TimeSpan]$diff)
    
    if ($diff -ne $null) {
        $days = ""
        if($diff.days -gt 0) {
         $days = ("{0}." -f $diff.Days)
        }

        return ("{3}{0}:{1,2:D2}:{2,2:D2}" -f $diff.Hours,$diff.Minutes,$diff.Seconds,$days);
    } else {
        Write-Error "Null diff"
    }
}

function get-timestring {
    param([System.DateTime]$time,$prev=$null)
    
    if ($time -ne $null) {
        $days = ""

        if(($prev -ne $null) -and ($time -gt $prev)) {
         $diff = ($time - $prev)
         $daysnum = $diff.Days

         $nextdaytest = $time.AddDays(-$daysnum)
         if ($nextdaytest.DayOfYear -ne $prev.DayOfYear) {
            $daysnum += 1
         }

         if ($daysnum -gt 0) {
            $days = (" (+{0}) " -f $daysnum)
         }
        }

        return ("{0,2:D2}:{1,2:D2}:{2,2:D2}{3}" -f $time.Hour,$time.Minute,$time.Second,$days);
    } else {
        Write-Error "Null diff"
    }
}

function translate-status {
     param($text) 
 

     if ($text -ieq "success") {
       return "Success"
     } elseif ($text -ieq "warning" -or $text -ieq "none") {
       return "Warning"
     } elseif ($text -ieq "pending") {
       return "Pending"
     }
     return "Error"
}

function calculate-vms {
    param($session)
    $tasks = $session.GetTaskSessions()

    $success = 0;
    $failed = 0;
    $warning = 0;
    $allvms = @()
    $glerr = "ERRSTR";
	
    foreach($task in $tasks) {
         $text = $task.Status;
         $diff= $task.Progress.Duration;


         $vm = New-Object -TypeName psobject -Property @{"Name"=$task.Name;
            "Status"=(translate-status -text $text);
            "Color"=(get-rpmcolor -text $text -isbg $false);
            "StartTime"=(get-timestring -time $task.Progress.StartTime);
            "EndTime"=(get-timestring -time $task.Progress.StopTime -prev $task.Progress.StartTime);
            "Size"=(get-humanreadable -num $task.Progress.ProcessedSize);
            "Read"=(get-humanreadable -num $task.Progress.ReadSize);
            "Transferred"=(get-humanreadable -num $task.Progress.TransferedSize);
            "Duration"=(get-diffstring -diff $task.Progress.Duration);
            "Details"=$task.GetDetails()
}

         if ($text -ieq "success") {
           $success = $success +1 
         } elseif ($text -ieq "warning" -or $text -ieq "pending" -or $text -ieq "none") {
           $warning = $warning +1
         } else {
           
           $failed = $failed +1
         }
        $allvms += $vm
        $glerr += $messages
    }
    return New-Object -TypeName psobject -Property @{vms=$allvms;failed=$failed;success=$success;warning=$warning;glerr=$glerr}
    
}
function get-veeamserver {
    $versionstring = "Unknown Version"

    $pssversion = (Get-PSSnapin VeeamPSSnapin -ErrorAction SilentlyContinue)
    if ($pssversion -ne $null) {
        $versionstring = ("{0}.{1}" -f $pssversion.Version.Major,$pssversion.Version.Minor)
    }

    

   
    $corePath = Get-ItemProperty -Path "HKLM:\Software\Veeam\Veeam Backup and Replication\" -Name "CorePath" -ErrorAction SilentlyContinue
    if ($corePath -ne $null) {
        $depDLLPath = Join-Path -Path $corePath.CorePath -ChildPath "Packages\VeeamDeploymentDll.dll" -Resolve -ErrorAction SilentlyContinue
        if ($depDLLPath -ne $null -and (Test-Path -Path $depDLLPath)) {
            $file = Get-Item -Path $depDLLPath -ErrorAction SilentlyContinue
            if ($file -ne $null) {
                $versionstring = $file.VersionInfo.ProductVersion
            }
        }
    }

    $servsession = Get-VBRServerSession
    $str = ("Server {0} : Veeam Backup & Replication {1}" -f $servsession.server,$versionstring)

    return $str
}
function calculate-job {
     param($session,$job,$rpo,$rpodate,$rpohours)

     
     

     
    
     $obj = New-Object -TypeName psobject -Property @{Jobname=$session.Name;
        Jobtype=$session.JobType;
        Jobdescription=$job.Description;
        Status=(translate-status -text $session.Result);
        Color=(get-rpmcolor -text $session.Result);

        "CreationTime"=$session.CreationTime;
        "EndTime"=$session.EndTime;

        "LongStartDateTime"=($session.CreationTime.ToLongDateString()+" "+$session.CreationTime.ToLongTimeString())
        "ProcessedObjects"=$session.Progress.ProcessedObjects;
        "TotalObjects"=$session.Progress.TotalObjects;
        "TotalSize"=(get-humanreadable -num $session.Progress.TotalSize);
        "BackupSize"=(get-humanreadable -num $session.BackupStats.BackupSize);
        "LongCreationTime"=(get-timestring -time $session.CreationTime);
        "LongEndTime"=(get-timestring -time $session.EndTime -prev $session.CreationTime);
        "DataRead"=(get-humanreadable -num $session.Progress.ReadSize);
        "Dedupe"=("{0:N1}x" -f $session.BackupStats.GetDedupeX());
        "Duration"=(get-diffstring -diff $session.Progress.Duration);
        "TransferSize"=(get-humanreadable -num $Session.Progress.TransferedSize);
        "Compression"=("{0:N1}x" -f $session.BackupStats.GetCompressX());
        "Details"=$session.GetDetails();
        
    }

    if($rpo -ne $null) {
        $rpocolor = "#fb9895"
        $rpodiff = ($rpodate - $session.CreationTime)
        $rpodiffhours = ("{0,2:D2}h{1,2:D2}" -f [int]([Math]::Floor($rpodiff.TotalHours)),$rpodiff.minutes)

        $rpotext = ""
        if ($rpo -lt $session.CreationTime) {
            $rpocolor = "#00B050"
            $rpotext = ("Session started {0} ago (Valid RPO {1}h) " -f $rpodiffhours,$rpohours)
        } else {
            $rpotext = ("Session started {0} ago (Breaks RPO {1}h) " -f $rpodiffhours,$rpohours)
        }
        $obj | Add-Member -Name "RPOColor" -Value $rpocolor -MemberType NoteProperty 
        $obj | Add-Member -Name "RPOText" -Value $rpotext -MemberType NoteProperty 

    }

    #bug where GetTaskSessions() modifies TotalSize (doubles the number)
    #still need to report
    #fix by calling the method after 
    $calcs = calculate-vms -session $session
    $obj | Add-Member -Name Failed -Value $calcs.failed -MemberType NoteProperty
    $obj | Add-Member -Name Warning -Value $calcs.warning -MemberType NoteProperty
    $obj | Add-Member -Name Success -Value $calcs.success -MemberType NoteProperty
    $obj | Add-Member -Name Vms -Value $calcs.vms -MemberType NoteProperty


    if ($session.Result -eq "None" -and $session.JobType -eq "BackupSync") {
        if($lastsession.State -eq "Idle" -and $calcs.failed -eq 0 -and $calcs.warning -eq 0 -and $calcs.glerr -eq "ERRSTR" -and $obj.Details -eq "" ) {
            if ($session.Progress.Percents -eq 100) {
                $obj.Status=(translate-status -text "Success");
                $obj.Color=(get-rpmcolor -text "Success");
            } 
        } 
    }

    return $obj
}

<#
            #for manual testing, you can run the following lines. You can then use $job & $session (if there is a session to run the functions above)
            $job = get-vbrjob -name "Backup Job 1"
            $sessions = Get-VBRBackupSession -Name ("{0}*" -f $Job.Name) | ? { $_.jobname -eq $Job.Name } 
            $orderdedsess = $sessions | Sort-Object -Property CreationTimeUTC -Descending
            $session = $orderdedsess[0]
#>

$wrotesessions = $false;
$sb = New-Object -TypeName "System.Text.StringBuilder";
write-reportmimicheader $sb
write-reportmimicheadertable $sb

if ($JobName -ne $null -and $JobName -ne "") {
    $Jobs = @(Get-VBRJob -Name $JobName)
    if ($Jobs.Count -gt 0) {
        $Job = $Jobs[0];
        $jt = $job.JobType;

        if ($jt -eq "Backup" -or $jt -eq "Replication" -or $jt -eq "BackupSync") {
            

            $sessions = Get-VBRBackupSession -Name ("{0}*" -f $Job.Name) | ? { $_.jobname -eq $Job.Name } 
            $orderdedsess = $sessions | Sort-Object -Property CreationTimeUTC -Descending


            if ($Max -gt 0 -and $Max -lt $orderdedsess.Count) {
                $orderdedsess = $orderdedsess | select -First $Max
            }

            
            $rpo = $null
            if ($RPOHours -ne $defrpo) {
                $rpo = $date.AddHours(-$RPOHours)
            }

            foreach($sess in $orderdedsess) {
                write-reportmimicrecord -stringbuilder $sb -job $Job -session $sess -rpo $rpo -rpodate $date -rpohours $RPOHours
                
            }
            $wrotesessions = $true;

        } else {
          Write-Error "Job can only be backup, backup copy or replication job. Cannot be $jt"  
        }
    } else {
       Write-Error "Can not find Job with name $JobName"
    }
} else {
  if ($jobtype -ieq "Backup" -or $jobtype -ieq "Replication" -or $jobtype -ieq "BackupSync") {
      $Jobs = @(Get-VBRJob | ? { $_.JobType -ieq $jobtype }) | Sort-Object -Property Name
      if ($Jobs.Count -ne 0) {
            $wrotesessions = $true;
            $allsessions = Get-VBRBackupSession | ? { $_.jobtype -ieq $JobType } 
            $allorderdedsess = $allsessions | Sort-Object -Property CreationTimeUTC -Descending  
 
            $rpo = $null
            if ($RPOHours -ne $defrpo) {
                $rpo = $date.AddHours(-$RPOHours)
            }
            
            foreach ($Job in $Jobs) {
                $lastsession = $allorderdedsess | ? { $_.jobname -eq $Job.Name } | select -First 1
                if ($lastsession -ne $null) {
                   write-reportmimicrecord -stringbuilder $sb -job $Job -session $lastsession -rpo $rpo  -rpodate $date  -rpohours $RPOHours
                } else {
                   write-reportmimicrecordempty -stringbuilder $sb  -job $Job
                }
            }      
      } else {
       Write-Error "Can not find Jobs with type $jobtype"
      }
  } else {
        Write-Error "Job can only be backup (Backup), backup copy (BackupSync) or replication job (Replica). Cannot be $jt"  
  }
}

if ($wrotesessions) {
    write-reportmimicfootertable $sb -server (get-veeamserver)
    write-reportmimicfooter $sb

    #If you want to send the html as an email, you can use $content = $sb.ToString() to put the content in a variable. You should be able to use Send-MailMessage -BodyAsHtml -Body $content to actually send the message
    $sb.ToString() | Out-File -FilePath $File
} else {
    "<html><head><title>Error!</title></head><body><span style='font-size:40px;color:red;'>Something went wrong<br> Report has not been made</span><br>Error var<br><pre>($error)</pre></body>"  | Out-File -FilePath $File
    Write-Error "Did not write anything"
}