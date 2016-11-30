asnp veeampssnapin

$dumpfile = ("{0}\README.md" -f [Environment]::GetFolderPath("Desktop"))

function Dump-VBRObject {
    param($object,[int]$level=0,[string]$header="",$prefix="$opt.",[System.Text.StringBuilder]$sb,[System.Text.StringBuilder]$issue,[String[]]$blacklist,[String[]]$blacklisttype,$func=$false,$emitval=$false)
    if ($level -eq 0) {
        
        [void]$sb.AppendLine(("## Dump of '{0}'" -f $header))
    }
    if ($level -gt 5) {
        [void]$issue.AppendLine("Detected to deep level with $prefix")
        return

        #don't hang forever
    }
    
    if ($object -ne $null) {
        $ident = ""
        for ($i=0;$i -lt $level;$i++) { $ident = $ident + "  " }

        if ($func) {
            $funcs = $object | gm -MemberType Method
            foreach ($f in $funcs) {
                if ($f.Name -notin $blacklist -and -not ($f.Name -match "^To")) {
                   [void]$sb.AppendLine(("{0}* Funccall : {1}.{2}()  Def : {3}" -f $ident,$prefix,$f.Name,$f.Definition )) 
                }
            }
        }

        $members = $object | gm -MemberType Property  | % { $_.Name }


        foreach ($member in $members)
        {
            
                $memreal = $null

                $t = "`$null"
                try {
                    $t = ""+$object.$member.GetType().Fullname
                } catch {}

                $memreal = $($object."$member")
                if($memreal) {
                    [void]$sb.AppendLine(("{0}* {1}.{2} [{3}]" -f $ident,$prefix,$member,$t ))
                    if($emitval) { [void]$sb.AppendLine(("{0}  * Live Value : {1}" -f $ident,$memreal)) }

                    if ($member -notin $blacklist -and $t -notin $blacklisttype) {
                         Dump-VBRObject -object $memreal -level $($level+1) -prefix ("{0}.{1}" -f $prefix,$member) -sb $sb -issue $issue -blacklist $blacklist  -func $func -emitval $emitval -blacklisttype $blacklisttype
                    }
                    
                } else {
         
                    [void]$sb.AppendLine(("{0}* {1}.{2} [{3}] (`$null)" -f $ident,$prefix,$member,$t))
                    if($emitval) { [void]$sb.AppendLine(("{0}  * Live Value : `$null" -f $ident)) }
                }
            
              
        }
    } else {
        [void]$issue.AppendLine(("Error with $prefix at level $level "))
        
    }
    if($level -eq 0) { [void]$sb.AppendLine("");[void]$sb.AppendLine("")}
}

$sb = New-Object -TypeName "System.Text.StringBuilder";
[void]$sb.AppendLine((@"
# Dumper script as quick powershell reference
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 
## Distributed under MIT license
Copyright (c) 2016 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Timothy Dewin @tdewin

**Function:** Dumps all methods/properties for joboptions and backups

**Requires:** VBR 9.x

**Usage:** Dump-VBRObjects.ps1

**Parameters:** Not Applicable

**Result:** Is actually this file

## Actual Dump
Updated on {0}

"@ -f (get-date -UFormat "+%y/%m/%d - %H:%M:%S")))



$job = @(Get-VBRJob | where { $_.JobType -eq "Backup" })[0]



$issue = New-Object -TypeName "System.Text.StringBuilder";

$blacklist = @("Date","Length","Equals","GetHashCode","GetTypeCode","GetType","ToString","CompareTo","value__","HasFlag")
$blacklisttype = @("System.String","System.String[]","System.TimeSpan","System.Date","System.DateTime","System.Xml.XmlElement")

$VBRJobOptions  = Get-VBRJobOptions -job $job
Dump-VBRObject -object $VBRJobOptions  -header '$VBRJobOptions  = Get-VBRJobOptions -job $job' -prefix ' $VBRJobOptions' -sb $sb -issue $issue -blacklist $blacklist -func $true -blacklisttype $blacklisttype

$VBRJobScheduleOptions = Get-VBRJobScheduleOptions -job $job
Dump-VBRObject -object $VBRJobScheduleOptions -header '$VBRJobScheduleOptions = Get-VBRJobScheduleOptions -job $job' -prefix '$VBRJobScheduleOptions' -sb $sb -issue $issue -blacklist $blacklist -func $true -blacklisttype $blacklisttype

$VBRJobVSSOptions = Get-VBRJobVSSOptions -job $job
Dump-VBRObject -object $VBRJobVSSOptions -header '$VBRJobVSSOptions = Get-VBRJobVSSOptions -job $job' -prefix '$VBRJobVSSOptions' -sb $sb -issue $issue -blacklist $blacklist -func $true -blacklisttype $blacklisttype

$JobObject = @(Get-VBRJobObject -job $Job)[0]
$VBRJobObjectVssOptions = Get-VBRJobObjectVssOptions -ObjectInJob $JobObject 
Dump-VBRObject -object $VBRJobObjectVssOptions -header '$VBRJobObjectVssOptions = Get-VBRJobObjectVssOptions -ObjectInJob $JobObject ' -prefix '$VBRJobObjectVssOptions' -sb $sb -issue $issue -blacklist $blacklist -func $true -blacklisttype $blacklisttype

$VBRBackup = @(Get-VBRBackup)[0]
Dump-VBRObject -object $VBRBackup -header '$VBRBackup = @(Get-VBRBackup)[0]' -prefix '$VBRBackup' -sb $sb -issue $issue -blacklist $blacklist -func $true -blacklisttype $blacklisttype

$sb.ToString() | out-file -FilePath $dumpfile
write-host $issue.ToString()