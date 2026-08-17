<#
   .Synopsis
    Maintainer's test harness for Collect-GuestLogs.ps1. Not for customers.

    Validates the parts of the collection script that silently decide what data gets OMITTED from a
    support bundle -- primarily Get-LogFamilyKey, the function that groups rotated Veeam log files
    into "families" so only the newest N of each are collected.
   .Description
    Runs three checks:
      1. Parse check   -- the script must parse cleanly under the current PowerShell engine.
      2. Unit tests    -- known filenames (the "rotation scheme zoo" below) are run through the REAL
                          Get-LogFamilyKey (extracted from the script via AST, never a copy) and
                          compared to their expected family keys.
      3. Dry run       -- optional (-DryRunPath): groups a live Veeam log directory the same way the
                          collection script would and reports what would be kept vs. dropped.
                          Read-only; nothing is copied or modified.

    THE ROTATION SCHEME ZOO -- naming schemes Veeam has been observed to use for rotated logs.
    When a new Veeam version invents a new scheme: add example filename(s) + expected family to the
    $testCases list below, extend Get-LogFamilyKey in Collect-GuestLogs.ps1, and re-run this script
    (under BOTH Windows PowerShell 5.1 and PowerShell 7) until everything passes.
      1. Trailing index:        Svc.VeeamBackup.1.log                          (all versions)
      2. Compressed rotation:   Svc.VeeamTransport.10.log.gz                   (v13+)
      3. Leading-date archive:  2026-07-19_Svc.VeeamBackup.zip                 (v13+)
      4. Per-day date suffix:   VeeamGuestHelper_18.02.2026.log                (guest helper style)
      5. Per-start timestamp:   Veeam.StandBy.Service_2026_08_03_05_33_09.log  (Explorer/plugin
                                services; also seen dot-dashed: _2026.08.03_05_33_45; may also be
                                zipped: Veeam.StandBy.Service_2026_07_23_10_27_13.zip)
   .Parameter ScriptPath
    Path to Collect-GuestLogs.ps1. Defaults to the copy in the same folder as this test script.
   .Parameter DryRunPath
    Optional path to a live Veeam log directory (e.g. C:\ProgramData\Veeam\Backup). When provided,
    prints how many files the rotation filter would keep and the largest families it would trim.
   .Parameter RotationsToKeep
    Rotations per family assumed by the dry run. Default 3, matching the collection script's default.
   .Example
    .\Test-CollectGuestLogs.ps1
    .\Test-CollectGuestLogs.ps1 -DryRunPath "$env:ProgramData\Veeam\Backup"
    powershell.exe -File .\Test-CollectGuestLogs.ps1   # re-run under Windows PowerShell 5.1
   .Notes
    NAME: Test-CollectGuestLogs.ps1
    AUTHOR: Chris Evans, Veeam Software
    REQUIREMENTS: Same floor as the main script (Windows PowerShell 4.0+; also runs under PS 7.x).
    Exit code = number of failed checks (0 = all passed), so it can gate automation.
#>
#Requires -Version 4.0
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive developer tool; colored console output is the intended UI.')]
param (
    [string] $ScriptPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "Collect-GuestLogs.ps1"),
    [string] $DryRunPath,
    [int] $RotationsToKeep = 3
)

$failures = 0

#--- 1. Parse check -----------------------------------------------------------------------------
if (!(Test-Path -LiteralPath $ScriptPath)) {
    Write-Host "Collect-GuestLogs.ps1 not found at: $ScriptPath" -ForegroundColor Red
    Exit 1
}
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors) {
    Write-Host "PARSE ERRORS in $ScriptPath :" -ForegroundColor Red
    foreach ($parseError in $parseErrors) {
        Write-Host ("  Line {0}: {1}" -f $parseError.Extent.StartLineNumber, $parseError.Message) -ForegroundColor Red
    }
    Exit 1
}
Write-Host "Parse check : OK (PowerShell $($PSVersionTable.PSVersion))" -ForegroundColor Green

#--- 2. Unit tests against the real Get-LogFamilyKey --------------------------------------------
#Extract the function from the script's AST so the tests always exercise the shipped code.
$funcAst = $ast.FindAll({ param($node)
        ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and ($node.Name -eq 'Get-LogFamilyKey')
    }, $true) | Select-Object -First 1
if (-not $funcAst) {
    Write-Host "Get-LogFamilyKey was not found in $ScriptPath -- has it been renamed?" -ForegroundColor Red
    Exit 1
}
. ([scriptblock]::Create($funcAst.Extent.Text))

#One entry per known naming scheme (and a few guard cases that must NOT be grouped).
$testCases = @(
    #Scheme 1: trailing index
    @{ In = 'Svc.VeeamBackup.log';                                       Expect = 'svc.veeambackup' }
    @{ In = 'Svc.VeeamBackup.1.log';                                     Expect = 'svc.veeambackup' }
    @{ In = 'VeeamBackupManager.9.log';                                  Expect = 'veeambackupmanager' }
    @{ In = 'Task.Transform.b9bb9f06-b77b-4890-894d-ec2fa9b201e4.1.log'; Expect = 'task.transform.b9bb9f06-b77b-4890-894d-ec2fa9b201e4' }
    @{ In = 'Task.Transform.Chris_PC_Backup.3.log';                      Expect = 'task.transform.chris_pc_backup' }
    #Scheme 2: compressed rotations
    @{ In = 'Svc.VeeamTransport.10.log.gz';                              Expect = 'svc.veeamtransport' }
    @{ In = 'Svc.VeeamInstaller.log.gz';                                 Expect = 'svc.veeaminstaller' }
    @{ In = 'Agent.Foreign_transform.Target.1.log.gz';                   Expect = 'agent.foreign_transform.target' }
    #Scheme 3: leading-date archives (v13+)
    @{ In = '2026-07-19_Svc.VeeamBackup.zip';                            Expect = 'svc.veeambackup' }
    @{ In = '2026-08-01_Job.BestPracticesAnalyzer.zip';                  Expect = 'job.bestpracticesanalyzer' }
    @{ In = 'Job.BestPracticesAnalyzer.log';                             Expect = 'job.bestpracticesanalyzer' }
    #Scheme 4: per-day date suffix (guest helper style)
    @{ In = 'VeeamGuestHelper_18.02.2026.log';                           Expect = 'veeamguesthelper' }
    #Scheme 5: per-start timestamps (Explorer/plugin services)
    @{ In = 'Veeam.StandBy.Service_2026_08_03_05_33_09.log';             Expect = 'veeam.standby.service' }
    @{ In = 'Veeam.StandBy.Service_2026_07_23_10_27_13.zip';             Expect = 'veeam.standby.service' }
    @{ In = 'Veeam.Azure.PlatformSvc_2026.08.03_05_33_45.log';           Expect = 'veeam.azure.platformsvc' }
    @{ In = 'SomeLog-2026-02-18.log';                                    Expect = 'somelog' }
    #Guard cases: names that merely CONTAIN digits must keep their identity (never over-group).
    @{ In = 'ServerPrefetchFiles.store';                                 Expect = 'serverprefetchfiles.store' }
    @{ In = 'Veeam Backup and Replication.log';                         Expect = 'veeam backup and replication' }
    @{ In = 'Config_2026_10.log';                                        Expect = 'config_2026_10' }
)
$testFailures = 0
foreach ($case in $testCases) {
    $actual = Get-LogFamilyKey $case.In
    if ($actual -ne $case.Expect) {
        Write-Host ("  FAIL: '{0}' -> '{1}' (expected '{2}')" -f $case.In, $actual, $case.Expect) -ForegroundColor Red
        $testFailures++
    }
}
if ($testFailures -eq 0) {
    Write-Host "Unit tests  : $($testCases.Count)/$($testCases.Count) passed" -ForegroundColor Green
}
else {
    Write-Host "Unit tests  : $($testCases.Count - $testFailures)/$($testCases.Count) passed" -ForegroundColor Red
    $failures += $testFailures
}

#--- 3. Optional read-only dry run against a live Veeam log directory ---------------------------
if ($DryRunPath) {
    if (!(Test-Path -LiteralPath $DryRunPath)) {
        Write-Host "Dry run     : path not found: $DryRunPath" -ForegroundColor Red
        $failures++
    }
    else {
        $allFiles = @(Get-ChildItem -LiteralPath $DryRunPath -Recurse -File -Force -ErrorAction SilentlyContinue)
        $groups = $allFiles | Group-Object -Property { $_.DirectoryName + '|' + (Get-LogFamilyKey $_.Name) }
        $keptCount = 0
        $keptBytes = 0
        foreach ($group in $groups) {
            $kept = @($group.Group | Sort-Object LastWriteTime -Descending | Select-Object -First $RotationsToKeep)
            $keptCount += $kept.Count
            $keptBytes += ($kept | Measure-Object Length -Sum).Sum
        }
        $totalBytes = ($allFiles | Measure-Object Length -Sum).Sum
        Write-Host ("Dry run     : would keep {0} of {1} files ({2:N1} MB of {3:N1} MB) at {4} rotation(s) per family" -f `
            $keptCount, $allFiles.Count, ($keptBytes / 1MB), ($totalBytes / 1MB), $RotationsToKeep) -ForegroundColor Green
        Write-Host "Largest families trimmed:"
        $groups | Where-Object { $_.Count -gt $RotationsToKeep } | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object {
            Write-Host ("  {0,-60} {1,4} files -> {2}" -f $_.Name.Split('|')[1], $_.Count, $RotationsToKeep)
        }
    }
}

Exit $failures
