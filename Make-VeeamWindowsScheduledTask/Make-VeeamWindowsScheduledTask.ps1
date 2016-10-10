[CmdletBinding(PositionalBinding=$false)]
param(
    [Parameter(Mandatory=$true)][string]$jobname,
    [System.DateTime]$At=(get-date),
    [System.DayOfWeek[]]$days=@(),
    [string]$scriptpath=("{0}\Veeam\ScheduleScripts" -f $(Get-Item -Path Env:\ProgramData).Value),
    [string]$scriptfile=("{0}.ps1" -f ($jobname -replace [regex]"[^a-zA-Z0-9]+","_")),
    [string]$schedulename=("VeeamSchedule_{0}" -f ($jobname -replace [regex]"[^a-zA-Z0-9]+","_")),
    [string]$schedulepath="\VeeamSchedules\",
    [System.Management.Automation.PSCredential]$cred = (Get-Credential -Message "Task Credentials" -username $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)),
    [switch]$force=$false
    
)



function Make-Scheduler {
    [CmdletBinding(PositionalBinding=$false)]
    param(
        [string]$jobname,
        [System.DateTime]$at,
        [System.DayOfWeek[]]$days,
        [string]$scriptpath=("{0}\Veeam\ScheduleScripts" -f $(Get-Item -Path Env:\ProgramData).Value),
        [string]$scriptfile=("{0}.ps1" -f ($jobname -replace [regex]"[^a-zA-Z0-9]+","_")),
        [string]$schedulename=("veeamsched_{0}" -f ($jobname -replace [regex]"[^a-zA-Z0-9]+","_")),
        [string]$schedulepath="\VeeamSchedules\",
        [boolean]$force=$false,
        [System.Management.Automation.PSCredential]$cred
    )

    #making a directory for holding scripts
    if (-not (Test-Path -Path $scriptpath)) {
        $dir = New-Item -Path $scriptpath -ItemType Directory -ErrorAction SilentlyContinue
        if( -not (Test-Path -Path $scriptpath)) {
            throw "Subdir creation failed"
        } else {
            Write-Verbose "Made Directory $dir"
        }
 
    } elseif ((Test-Path -Path $scriptpath -PathType Leaf)) {
        throw "Script dir is already a file"
    } 

    #check if file already exists
    $fullscriptpath = Join-Path -Path $scriptpath -ChildPath $scriptfile

    if((Test-path -path $fullscriptpath)) {
        if (-not $force) {
            throw "File already exists $fullscriptpath"
        } 
    }



    #check if schedule already exists
    $schedtest = $(Get-ScheduledTask -TaskName $schedulename -TaskPath $schedulepath -ErrorAction SilentlyContinue)
    if(($schedtest -ne $null)) {
        if (-not $force) {
            throw "Schedule already exists $schedulename"
        } else {
            $schedtest | Unregister-ScheduledTask -Confirm:$False
            Write-Verbose "Removed $schedulename"
        }
    }

    $trigger = $null

    if($days.Count -gt 0) {
        $trigger = New-ScheduledTaskTrigger -At $at -DaysOfWeek $days -Weekly
    } else {
        $trigger = New-ScheduledTaskTrigger -Daily -At $at
    }

    $task = New-ScheduledTaskAction -Execute (Get-Command "powershell").Source -Argument "-NonInteractive -File ""$fullscriptpath"""
    
    $sb = New-Object -TypeName "System.Text.StringBuilder"
    [void]$sb.Append(@"
#
# Generated Script
# 
Add-PSSnapin Veeampssnapin
`$jobname = "
"@)
    [void]$sb.Append($jobname)
    [void]$sb.Append(@"
"

# Edit below if you want even more control
`$sess = Get-VBRJob -Name `$jobname | Start-VBRJob -RunAsync
"@)

    $sb.ToString() | Out-File -FilePath $fullscriptpath -Force
    Write-Verbose "Made Script File : $fullscriptpath"
    

    $schedtask = Register-ScheduledTask -Action $task -TaskName $schedulename -TaskPath $schedulepath -Trigger $trigger -RunLevel Highest -User $cred.UserName -Password ($cred.GetNetworkCredential().Password)
    Write-Verbose ("Made task {0}" -f $schedtask.TaskName)
    
}

Add-PSSnapin Veeampssnapin
$j = Get-VBRJob -Name $jobname -ErrorAction SilentlyContinue
if ($j -eq $null) {
    throw "Job not found or snapin not loaded"
}

Make-Scheduler -jobname $jobname -At $at -Days $days -scriptpath $scriptpath -scriptfile $scriptfile -schedulename $schedulename  -schedulepath $schedulepath -force $force -cred $cred

<#
 # Mass Clean-Up

 #Default Directory
 $scriptpath=("{0}\Veeam\ScheduleScripts" -f $(Get-Item -Path Env:\ProgramData).Value)
 Remove-Item -Recurse -Confirm:$True ("{0}\*" -f $scriptpath)
 

 #Deleting default schedules
 [string]$schedulepre=("VeeamSchedule_{0}")
 [string]$schedulepath="\VeeamSchedules\"
 $tasks = @(Get-ScheduledTask -TaskPath $schedulepath -ErrorAction SilentlyContinue | ? { $_.TaskName -match $schedulepre })
 if ($tasks.Count -gt 0) {
  $tasks | Unregister-ScheduledTask -Confirm:$True
 }
#>