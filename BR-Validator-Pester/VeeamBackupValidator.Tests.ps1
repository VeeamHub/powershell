<#
    .EXAMPLE
    Invoke-Pester -Script @{ Path = "D:\VeeamBackupValidator.Tests.ps1"; Parameters = @{ BRHost="localhost"} }
#>

$BRHost = $Parameters.Get_Item("BRHost")

Describe "Veeam Backup Validator" {

    Add-PsSnapin -Name VeeamPSSnapIn
    $OpenConnection = (Get-VBRServerSession).Server
    if($OpenConnection -eq $BRHost) {
        } elseif ($OpenConnection -eq $null ) {
            Connect-VBRServer -Server $BRHost
            } else {
                Disconnect-VBRServer
                Connect-VBRServer -Server $BRHost
                }

    $Jobs = Get-VBRBackup

    $testCase = $Jobs | Foreach-Object {@{Job = $_.name}}
    It "Backup File for Job '<Job>' should be valid " -TestCases $testCase {
        param($Job)

        [String] $Report = $PSScriptRoot + $Job + ".xml"
        $EXEPath = $env:ProgramFiles + "\Veeam\Backup and Replication\Backup\veeam.backup.validator.exe"
        Start-Process $EXEPath  " /silence /format:xml /report:`"$Report`" /backup:`"$Job`" " -Wait
        $Report | Should Exist
        $XMLContent = [XML] (Get-Content $report )
        (($XMLContent.Report.Statistics.Parameter | Where-Object {$_.Name -eq "Failed VM count:"})."#text") | Should Be 0
        Remove-Item $Report -Force
    }

    $Backups = Get-ChildItem $PSScriptRoot -Include *.vbm -Recurse
    $testCase = $Backups | Foreach-Object {@{file = $_}}
    It "Backup File  '<file>' should be valid" -TestCases $testCase {
        param($File)

        [String] $Report = $PSScriptRoot + $File.name + ".xml"
        $EXEPath = $env:ProgramFiles + "\Veeam\Backup and Replication\Backup\veeam.backup.validator.exe"
        Start-Process $EXEPath  " /silence /format:xml /report:`"$Report`" /file:`"$File`" " -Wait
        $Report | Should Exist
        $XMLContent = [XML] (Get-Content $Report )
        (($XMLContent.Report.Statistics.Parameter | Where-Object {$_.Name -eq "Failed backup files count:"})."#text") | Should Be 0
        Remove-Item $Report -Force
    }

}