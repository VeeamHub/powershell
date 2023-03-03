asnp veeampssnapin

#alter function if you want different location
function mdfile {
    param($name)
    return ("{0}\{1}.md" -f [Environment]::GetFolderPath("Desktop"),$name)
}
$dumpfile = (mdfile -name "README")

function Dump-VBRObject {
    param($object,[int]$level=0,[string]$header="",[String[]]$objectcode=@(),$prefix="$opt.",[System.Text.StringBuilder]$sb,[System.Text.StringBuilder]$issue,[String[]]$blacklist,[String[]]$blacklisttype,$func=$false,$emitval=$false)
    if ($level -eq 0) {
        
        [void]$sb.AppendLine(("# {0}" -f $header))
        if ($objectcode.Length -gt 0) {
            [void]$sb.AppendLine(('``` powershell'))
            foreach($c in $objectcode) {
                [void]$sb.AppendLine(("{0}" -f $c))
            }
            [void]$sb.AppendLine(('```'))
        }
    }
    if ($level -gt 6) {
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
                   [void]$sb.AppendLine(("* {1}.{2}()  Def [{3}]" -f $ident,$prefix,$f.Name,$f.Definition )) 
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
                    [void]$sb.AppendLine(("* {1}.{2} \[{3}\]" -f $ident,$prefix,$member,$t ))
                    if($emitval) { [void]$sb.AppendLine(("  * Live Value : {1}" -f $ident,$memreal)) }

                    if ($member -notin $blacklist -and $t -notin $blacklisttype) {
                         Dump-VBRObject -object $memreal -level $($level+1) -prefix ("{0}.{1}" -f $prefix,$member) -sb $sb -issue $issue -blacklist $blacklist  -func $func -emitval $emitval -blacklisttype $blacklisttype
                    }
                    
                } else {
         
                    [void]$sb.AppendLine(("* {1}.{2} \[{3}\] \(`$null\)" -f $ident,$prefix,$member,$t))
                    if($emitval) { [void]$sb.AppendLine(("  * Live Value : `$null" -f $ident)) }
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

## QA

**What is this strange syntax @(..)[0]**

The code inside is executed and expected to return an array. For analysis, we only need one object thus we force the return value to be an array and take the first object.

This does mean that you need to have actually one Job defined and have one Backup etc..

# Actual Dump
Using VeeamPSSnapIn {0}

"@ -f ((Get-PSSnapin -Name VeeamPSSnapin).PSVersion.ToString())))




$issue = New-Object -TypeName "System.Text.StringBuilder";
$blacklist = @("Date","Length","Equals","GetHashCode","GetTypeCode","GetType","ToString","CompareTo","value__","HasFlag")
$blacklisttype = @("System.String","System.String[]","System.TimeSpan","System.Date","System.DateTime","System.Xml.XmlElement")



$dumps = @()
$dumps += New-Object -TypeName psobject -Property @{
    Prefix="VBRJob";
    ObjectCode=@('$VBRJob = @(Get-VBRJob)[0]');
}
$dumps += New-Object -TypeName psobject -Property @{
    Prefix="VBRJobObject";
    ObjectCode=@('$job = @(Get-VBRJob | where { $_.JobType -eq "Backup" })[0]','$VBRJobObject  = Get-VBRJobObject -job $job');
}
$dumps += New-Object -TypeName psobject -Property @{
    Prefix="VBRJobOptions";
    ObjectCode=@('$job = @(Get-VBRJob | where { $_.JobType -eq "Backup" })[0]','$VBRJobOptions  = Get-VBRJobOptions -job $job');
}
$dumps += New-Object -TypeName psobject -Property @{
    Prefix="VBRJobScheduleOptions";
    ObjectCode=@('$job = @(Get-VBRJob | where { $_.JobType -eq "Backup" })[0]','$VBRJobScheduleOptions = Get-VBRJobScheduleOptions -job $job');
}
$dumps += New-Object -TypeName psobject -Property @{
    Prefix="VBRJobVSSOptions";
    ObjectCode=@('$job = @(Get-VBRJob | where { $_.JobType -eq "Backup" })[0]','$VBRJobVSSOptions = Get-VBRJobVSSOptions -job $job');
}
$dumps += New-Object -TypeName psobject -Property @{
    Prefix="VBRJobObjectVssOptions";
    ObjectCode=@('$job = @(Get-VBRJob | where { $_.JobType -eq "Backup" })[0]','$JobObject = @(Get-VBRJobObject -job $Job)[0]','$VBRJobObjectVssOptions = Get-VBRJobObjectVssOptions -ObjectInJob $JobObject');
}
$dumps += New-Object -TypeName psobject -Property @{
    Prefix="VBRBackup";
    ObjectCode=@('$VBRBackup = @(Get-VBRBackup)[0]');
}
$dumps += New-Object -TypeName psobject -Property @{
    Prefix="VBRBackupStorage";
    ObjectCode=@('$VBRBackup = @(Get-VBRBackup)[0]','$VBRBackupStorage = @($VBRBackup.GetAllStorages())[0]');
}
$dumps += New-Object -TypeName psobject -Property @{
    Prefix="VBRBackupPoint";
    ObjectCode=@('$VBRBackup = @(Get-VBRBackup)[0]','$VBRBackupPoint = @($VBRBackup.GetPoints())[0]');
}
$dumps += New-Object -TypeName psobject -Property @{
    Prefix="VBRRestorePoint";
    ObjectCode=@('$VBRBackup = @(Get-VBRBackup)[0]','$VBRRestorePoint = @($VBRBackup | Get-VBRRestorePoint )[0]');
}
$dumps += New-Object -TypeName psobject -Property @{
    Prefix="VBRBackupSession";
    ObjectCode=@('$VBRBackupSession = @(Get-VBRBackupSession | ? {$_.JobType -eq "Backup"})[0]');
}
$dumps += New-Object -TypeName psobject -Property @{
    Prefix="VBRBackupSessionTaskSession";
    ObjectCode=@('$VBRBackupSession = @(Get-VBRBackupSession | ? {$_.JobType -eq "Backup"})[0]','$VBRBackupSessionTaskSession = @($VBRBackupSession.GetTaskSessions())[0]');
}



foreach ($dump in $dumps | Sort Prefix) {
    $sbfile = New-Object -TypeName "System.Text.StringBuilder";
    $dump.ObjectCode | % {
     invoke-expression $_
    }
    Invoke-Expression ('$o = ${0}' -f $dump.Prefix)

    if ($o -ne $null) {
        Dump-VBRObject -object $o -header ("{0} [{1}]" -f $dump.Prefix,$o.GetType().Fullname) -objectcode $dump.ObjectCode -prefix ("`${0}" -f $dump.Prefix) -sb $sbfile -issue $issue -blacklist $blacklist -func $true -blacklisttype $blacklisttype

        $fname =  (mdfile -name $dump.Prefix)
        $sbfile.ToString() | Out-File -FilePath $fname -Encoding utf8

        [void]$sb.AppendLine(("* [{0}](./{1}.md)" -f $dump.Prefix,$dump.Prefix))
    } else {
        write-host "No object was really made for "$dump.Prefix
    }
}


$sb.ToString() | Out-File -FilePath $dumpfile -Encoding utf8
