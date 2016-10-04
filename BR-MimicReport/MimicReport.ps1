param(
 [Parameter(Mandatory=$true)][string]$JobName=$null,
 [int]$Max=0,
 $date=(get-date),
 [string]$File=("mr_{0,4:D4}{1,2:D2}{2,2:D2}-{3,2:D2}{4,2:D2}{5,2:D2}_{6}.html" -f $date.Year,$date.Month,$date.Day,$date.Hour,$date.Minute,$date.Second,($jobname -replace [regex]"[^a-zA-Z0-9]+","_"))
)

#uncomment for smaller names
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
 param([System.Text.StringBuilder]$stringbuilder)
 [void]$stringbuilder.Append(@"
			<tr>
				<td style="font-size:12px;color:#626365;padding: 2px 3px 2px 3px;vertical-align: top;font-family: Tahoma;">
                  Generated with Report Mimic</td>
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
 <tr><td style="border:none; padding: 0px;font-family: Tahoma;font-size: 12px;"><table cellspacing="0" cellpadding="0" width="100%" border="0" style="border-collapse: collapse;"><tr style="height:70px"><td style="width: 80%;border: none;background-color: 
"@)
 [void]$stringbuilder.Append($calcs.Color)
 [void]$stringbuilder.Append(@"
;color: White;font-weight: bold;font-size: 16px;height: 70px;vertical-align: bottom;padding: 0 0 17px 15px;font-family: Tahoma;">
"@)
 [void]$stringbuilder.Append($calcs.Jobtype)
 [void]$stringbuilder.Append(" Job : ")
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
</div></td></tr><tr><td colspan="2" style="border: none; padding: 0px;font-family: Tahoma;font-size: 12px;"><table width="100%" cellspacing="0" cellpadding="0" class="inner" border="0" style="margin: 0px;border-collapse: collapse;"><tr style="height: 17px;">
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
 param([System.Text.StringBuilder]$stringbuilder,$job,$session)

 $calcs = calculate-job -session $session -job $job

 write-reportmimicrecordheader -stringbuilder $stringbuilder -job $job -session $session -calcs $calcs
 foreach ($vm in $calcs.vms) {
    write-reportmimicrecordvm -stringbuilder $stringbuilder -vm $vm
 }

 write-reportmimicrecordfooter -stringbuilder $stringbuilder
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

 return ("{0:N1} {1}B" -f $num,$trailing[$i])
}

function get-rpmcolor {
 param($text,[bool]$isbg=$true) 
 
 $prefix = "text"
 if ($isbg) { $prefix = "" }
 $colors = @{green="#00B050";textgreen="#00B050";orange="#E0A251";textorange="#E0A251";red="#fb9895";textred="#ff0000"}

 if ($text -ieq "success") {
   return $colors[("{0}green" -f $prefix)]
 } elseif ($text -ieq "warning") {
   return $colors[("{0}orange" -f $prefix)]
 } 
 return $colors[("{0}red" -f $prefix)]
}

function calculate-vms {
    param($session)
    $tasks = $session.GetTaskSessions()

    $success = 0;
    $failed = 0;
    $warning = 0;
    $allvms = @()

    foreach($task in $tasks) {
         $text = $task.Status;
         $diff= $task.Progress.Duration;


         $vm = New-Object -TypeName psobject -Property @{"Name"=$task.Name;
            "Status"=$text;
            "Color"=(get-rpmcolor -text $text -isbg $false);
            "StartTime"=$task.Progress.StartTime.ToLongTimeString();
            "EndTime"=$task.Progress.StopTime.ToLongTimeString();
            "Size"=(get-humanreadable -num $task.Progress.ProcessedSize);
            "Read"=(get-humanreadable -num $task.Progress.ReadSize);
            "Transferred"=(get-humanreadable -num $task.Progress.TransferedSize);
            "Duration"=("{0,2:D2}:{1,2:D2}:{2,2:D2}" -f [long]($diff.TotalHours),$diff.Minutes,$diff.Seconds);
            "Details"=$task.GetDetails()
}

         if ($text -ieq "success") {
           $success = $success +1 
         } elseif ($text -ieq "warning") {
           $warning = $warning +1
         } else {
           
           $failed = $failed +1
         }
        $allvms += $vm
    }
    return New-Object -TypeName psobject -Property @{vms=$allvms;failed=$failed;success=$success;warning=$warning}

    
}
function calculate-job {
     param($session,$job)

     
     
     $diff= $session.Progress.Duration;
     
    
     $obj = New-Object -TypeName psobject -Property @{Jobname=$session.Name;
        Jobtype=$session.JobType;
        Jobdescription=$job.Description;
        Status=$session.Result;
        Color=(get-rpmcolor -text $session.Result);

        "CreationTime"=$session.CreationTime;
        "EndTime"=$session.EndTime;

        "LongStartDateTime"=($session.CreationTime.ToLongDateString()+" "+$session.CreationTime.ToLongTimeString())
        "ProcessedObjects"=$session.Progress.ProcessedObjects;
        "TotalObjects"=$session.Progress.TotalObjects;
        "TotalSize"=(get-humanreadable -num $session.Progress.TotalSize);
        "BackupSize"=(get-humanreadable -num $session.BackupStats.BackupSize);
        "LongCreationTime"=$session.CreationTime.ToLongTimeString();
        "LongEndTime"=$session.EndTime.ToLongTimeString();
        "DataRead"=(get-humanreadable -num $session.Progress.ReadSize);
        "Dedupe"=("{0:N1}x" -f $session.BackupStats.GetDedupeX())
        "Duration"=("{0,2:D2}:{1,2:D2}:{2,2:D2}" -f [long]($diff.TotalHours),$diff.Minutes,$diff.Seconds);
        "TransferSize"=(get-humanreadable -num $Session.Progress.TransferedSize);
        "Compression"=("{0:N1}x" -f $session.BackupStats.GetCompressX());
        "Details"=$session.GetDetails()
    }

    #bug where GetTaskSessions() modifies TotalSize (doubles the number)
    #still need to report
    #fix by calling the method after 
    $calcs = calculate-vms -session $session
    $obj | Add-Member -Name Failed -Value $calcs.failed -MemberType NoteProperty
    $obj | Add-Member -Name Warning -Value $calcs.warning -MemberType NoteProperty
    $obj | Add-Member -Name Success -Value $calcs.success -MemberType NoteProperty
    $obj | Add-Member -Name Vms -Value $calcs.vms -MemberType NoteProperty

    return $obj
}



if ($JobName -ne $null) {
    $Jobs = @(Get-VBRJob -Name $JobName)
    if ($Jobs.Count -gt 0) {
        $Job = $Jobs[0];
        $jt = $job.JobType;

        if ($jt -eq "Backup" -or $jt -eq "Replication" -or $jt -eq "BackupSync") {
            $sb = New-Object -TypeName "System.Text.StringBuilder";
            write-reportmimicheader $sb
            write-reportmimicheadertable $sb

            $sessions = Get-VBRBackupSession -Name ("{0}*" -f $Job.Name) | ? { $_.jobname -eq $Job.Name } 
            $orderdedsess = $sessions | Sort-Object -Property CreationTimeUTC -Descending
            #$session = $orderdedsess[0]

            if ($Max -gt 0 -and $Max -lt $orderdedsess.Count) {
                $orderdedsess = $orderdedsess | select -First $Max
            }

            foreach($sess in $orderdedsess) {
                #write-host ("start {0}" -f ([long]($sess.Progress.TotalSize)))
                write-reportmimicrecord -stringbuilder $sb -job $Job -session $sess
                #write-host ("stop {0}" -f ([long]($sess.Progress.TotalSize)))
                
            }
            write-reportmimicfootertable $sb
            write-reportmimicfooter $sb

            $sb.ToString() | Out-File -FilePath $File
        } else {
          Write-Error "Job can only be backup, backup copy or replication job. Cannot be $jt"  
        }
    } else {
       Write-Error "Can not find Job with name $JobName"
    }
} else {
  Write-Error "JobName is null"
}

