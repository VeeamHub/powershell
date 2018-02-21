#
# Veeam-Verify
#
# Based on http://www.virtualtothecore.com/en/backups-vms-2016-edition/
#
# Original license/description follows:
#
####################################################################
#
# Verify protected VM's
#
####################################################################
#
# MIT License
#
#Copyright (c) 2016 Tom Sightler
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
####################################################################
#
# Run the script against vCenter and Veeam server and checks which VM's
# have been protected in the last 23 hours, and which are not protected

Add-PSSnapin "VeeamPSSnapIn" -ErrorAction SilentlyContinue

####################################################################
# Configuration
#
# To exclude VMs from report add VM names to be excluded as follows
# simple wildcards are supported:
# $excludevms=@("vm1","vm2", "*_replica")
$excludeVMs = @("")
# Exclude VMs in the following vCenter folder(s) (does not exclude sub-folders)
# $excludeFolder =  = @("folder1","folder2","*_testonly")
$excludeFolder = @("")
# Exclude VMs in the following vCenter datacenter(s)
# $excludeDC =  = @("dc1","dc2","dc*")
$excludeDC = @("")#
# This variable sets the number of hours of session history to
# search for a successul backup of a VM before considering a VM
# "Unprotected".  For example, the default of "24" tells the script
# to search for all successful/warning session in the last 24 hours
# and if a VM is not found then assume that VM is "unprotected".
$HourstoCheck = 24
####################################################################

# Convert exclusion list to simple regular expression
$excludevms_regex = ('(?i)^(' + (($excludeVMs | ForEach {[regex]::escape($_)}) -join "|") + ')$') -replace "\\\*", ".*"
$excludefolder_regex = ('(?i)^(' + (($excludeFolder | ForEach {[regex]::escape($_)}) -join "|") + ')$') -replace "\\\*", ".*"
$excludedc_regex = ('(?i)^(' + (($excludeDC | ForEach {[regex]::escape($_)}) -join "|") + ')$') -replace "\\\*", ".*"

$vms=@{}

# Build a hash table of all VMs.  Key is either Job Object Id (for any VM ever in a Veeam job) or vCenter ID+MoRef
# Assume unprotected (!), and populate Cluster, DataCenter, and Name fields for hash key value
Find-VBRViEntity |
    Where-Object {$_.Type -eq "Vm" -and $_.VmFolderName -notmatch $excludefolder_regex} |
    Where-Object {$_.Name -notmatch $excludevms_regex} |
    Where-Object {$_.Path.Split("\")[1] -notmatch $excludedc_regex} |
    ForEach {$vms.Add(($_.FindObject().Id, $_.Id -ne $null)[0], @("!", $_.Path.Split("\")[1], $_.Path.Split("\")[2], $_.Name))}

Find-VBRViEntity -VMsandTemplates |
    Where-Object {$_.Type -eq "Vm" -and $_.IsTemplate -eq "True" -and $_.VmFolderName -notmatch $excludefolder_regex} |
    Where-Object {$_.Name -notmatch $excludevms_regex} |
    Where-Object {$_.Path.Split("\")[1] -notmatch $excludedc_regex} |
    ForEach {$vms.Add(($_.FindObject().Id, $_.Id -ne $null)[0], @("!", $_.Path.Split("\")[1], $_.VmHostName, $_.Name))}

# Find all backup task sessions that have ended in the last x hours and not ending in Failure
$vbrtasksessions = (Get-VBRBackupSession |
    Where-Object {$_.JobType -eq "Backup" -and $_.EndTime -ge (Get-Date).addhours(-$HourstoCheck)}) |
    Get-VBRTaskSession | Where-Object {$_.Status -ne "Failed"}

# Compare VM list to session list and update found VMs status to "Protected"
If ($vbrtasksessions) {
    Foreach ($vmtask in $vbrtasksessions) {
        If($vms.ContainsKey($vmtask.Info.ObjectId)) {
            $vms[$vmtask.Info.ObjectId][0]=$vmtask.JobName
        }
    }
}

$vms = $vms.GetEnumerator() | Sort-Object Value

# Output VMs in color coded format based on status
# VM's with a job name of "!" were not found in any job
foreach ($vm in $vms) {
    if ($vm.Value[0] -ne "!") {
        write-host -foregroundcolor green (($vm.Value[1]) + "\" + ($vm.Value[2]) + "\" + ($vm.Value[3])) "is backed up in job:" $vm.Value[0]
    } else {
        write-host -foregroundcolor red (($vm.Value[1]) + "\" + ($vm.Value[2]) + "\" + ($vm.Value[3])) "is not found in any backup session in the last" $HourstoCheck "hours"
    }
}
