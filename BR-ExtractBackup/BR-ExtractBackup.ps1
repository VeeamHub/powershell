<#
 
.SYNOPSIS
Starts the Veeam Backup Transport Service (VeeamAgent.exe) and instructs it to restore data based on extension from VBK, VIB and VRB files specified. This can either be a folder or an individual file.

.NOTES
  Version: 0.1
  Author: Johan Huttenga
  License: MIT
  Created: 2018-03-13

.EXAMPLE
ExtractBackup.ps1 -Folder E:\ -Extension ".xml" -Destination E:\Restored\

#>

param(
    [string] $folder,
    [string] $file,
    [string] $extension = ".xml",
    [string] $destination
)

$VeeamAgentServerUri = ""
$VeeamAgentServerUser = "usr"
$VeeamAgentServerPassword = "pw"

function Get-VeeamAgentPath() {
    $VeeamAgentPathX64 = "${Env:ProgramFiles(x86)}\Veeam\Backup Transport\x64\VeeamAgent.exe"
    $VeeamAgentPathX86 = "${Env:ProgramFiles(x86)}\Veeam\Backup Transport\x86\VeeamAgent.exe"
    if ((Test-Path "$($VeeamAgentPathX64)"))
    {
        return $VeeamAgentPathX64
    }
    elseif ((Test-Path "$($VeeamAgentPathX64)"))
    {
        return $VeeamAgentPathX86
    }
    else { 
        Write-Host "Veeam Backup Transport Service (VeeamAgent.exe) not found. Please make sure this is installed before continuing."
        return $null
    }
}

function Read-AgentOutputBuffer($agent) {
    for ($i = 0; $i -lt $agent.Output.Length; $i++)
    {
        $c = $agent.Output[$i]
        if (([byte][char]$c -eq '13') -or ($i -eq $agent.Output.Length)) {
            $val = $agent.Output.ToString(0, $i)
            $agent.Output = $agent.Output.Remove(0,$i+2)
            return $val;
        }
    }
}

function Read-VeeamAgentBufferProperty($agent, $value) {
    $line = Read-AgentOutputBuffer -Agent $agent
    if ($line -match $value) {
        return $line.Replace($value, [string]::Empty).Trim()
    }
    else {
        return $null
    }
}

function Send-VeeamAgentCommand($agent, $value)
{
    $agent.process.StandardInput.WriteLine($value)
}

class VeeamAgent {
    [String]$Executable
    [String]$Args
    [System.Diagnostics.Process]$Process
    [System.Guid]$Guid
    [int]$Id
    [int]$Port
    [System.Text.StringBuilder]$Output
    [System.Text.StringBuilder]$Errors
}

class VeeamObjectInBackup {
    [String]$Parent
    [long]$Size
    [System.Guid]$Guid
    [String]$Uri
}

function New-VeeamAgentProcess() {
    $psi = New-Object System.Diagnostics.ProcessStartInfo;
    $psi.Filename = $(Get-VeeamAgentPath)
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardError = $true
    $p = New-Object -TypeName System.Diagnostics.Process
    $p.StartInfo = $psi
    $guid = [System.Guid]::NewGuid()
    $agent = New-Object VeeamAgent
    $agent.Executable = $psi.Filename
    $agent.Args = $psi.Arguments
    $agent.Process = $p
    $agent.Guid = $guid

    $agent.Output = New-Object -TypeName System.Text.StringBuilder
    $agent.Errors = New-Object -TypeName System.Text.StringBuilder

    $eventAction = {
        if (![String]::IsNullOrEmpty($EventArgs.Data)) {
            $Event.MessageData.AppendLine($EventArgs.Data)
        }
    }

    $evtStdOut = Register-ObjectEvent -InputObject $agent.Process -Action $eventAction -EventName 'OutputDataReceived' -MessageData $agent.Output
    $evtStdErr = Register-ObjectEvent -InputObject $agent.Process -Action $eventAction -EventName 'ErrorDataReceived' -MessageData $agent.Errors
    $agent.Process.Start() | Out-Null
    $agent.Process.BeginOutputReadLine()
    $agent.Process.BeginErrorReadLine()
    do {
        Start-Sleep -s 1
    } until ($agent.Output.Length -gt 0)
    $agent.id = Read-VeeamAgentBufferProperty -Agent $agent -Value "PID:"
    $agent.port = Read-VeeamAgentBufferProperty -Agent $agent -Value "Dispatch port:"
    return $agent
}

function Start-VeeamAgent($type) {
    $agent = New-VeeamAgentProcess
    Write-Host "Data Mover Started ($($type), GUID: $($agent.Guid), Port: $($agent.Port))"
    if ($type -eq "server")
    { 
        $global:VeeamAgentServerUri = "127.0.0.1:" + $agent.port
        Send-VeeamAgentCommand -Agent $agent -Value "startServer"
        Send-VeeamAgentCommand -Agent $agent -Value $VeeamAgentServerUser
        Send-VeeamAgentCommand -Agent $agent -Value $VeeamAgentServerPassword
    }
    elseif ($type -eq "client") {
        Send-VeeamAgentCommand -Agent $agent -Value "connectLocal"
        Send-VeeamAgentCommand -Agent $agent -Value $global:VeeamAgentServerUri
        Send-VeeamAgentCommand -Agent $agent -Value "."
        Send-VeeamAgentCommand -Agent $agent -Value "1"
        Send-VeeamAgentCommand -Agent $agent -Value $VeeamAgentServerUser
        Send-VeeamAgentCommand -Agent $agent -Value $VeeamAgentServerPassword
        Send-VeeamAgentCommand -Agent $agent -Value "2" 
        Send-VeeamAgentCommand -Agent $agent -Value $([system.guid]::Empty).ToString()
    }
    return $agent
}

function Restore-VeeamBackupContent($agent, $oib, $destination)
{
    if ($agent.Output) { $agent.Output.Clear() | Out-Null }
    Send-VeeamAgentCommand -Agent $agent -Value "restore"
    Send-VeeamAgentCommand -Agent $agent -Value $destination
    Send-VeeamAgentCommand -Agent $agent -Value "veeamfs:0:$($oib.Guid) $($oib.Uri)@$($oib.Parent)"
    Send-VeeamAgentCommand -Agent $agent -Value "."
    do {
        Start-Sleep -s 1
    } until (($agent.Output.Length -gt 0) -and $agent.Output.ToString().Contains('100'))
    if ((Test-Path $destination)) {
        Write-Host "Restored $($oib.Uri) to $($destination)."
    }
    else {
        Write-Host "Error: Failed to restore $($oib.Uri)."
    }
}

function Get-VeeamBackupMetadata($agent, $file) {
    $meta = @{}
    if ($agent.Output) { $agent.Output.Clear() | Out-Null }
    Send-VeeamAgentCommand -Agent $agent -Value "dir"
    Send-VeeamAgentCommand -Agent $agent -Value $file
    do {
        Start-Sleep -s 1
    } until ($agent.Output.Length -gt 0)
    while ($agent.Output.Length -gt 0) {
        $line = Read-AgentOutputBuffer -Agent $agent
        if ($line -ne '>')
        {
            $content = $line.Split(" ")
            $oib = New-Object VeeamObjectInBackup
            $oib.Parent = $file
            $oib.Size = [long]$content[0]
            $oib.Guid = [System.Guid]$content[1]
            $oib.Uri = $content[2]
            $meta[$oib.Uri.Split('/')[1]] = $oib
        }
    }
    return $meta
}

$_meta = @{}

Write-Host ""
Write-Host ('-' * 80)
Write-Host 'Initializing Data Movers...'
$vaServer = Start-VeeamAgent -Type "server"
$vaClient = Start-VeeamAgent -Type "client"
if ($vaClient.Errors.Length -gt 0) { Write-Error -Message "Error: Unexpected agent control error occurred: $($agent.Errors.ToString())" -Category ConnectionError }
Write-Host ('-' * 80)
Write-Host ""

if ($file) {
    $f = $file.ToString()
    $_meta[$f] = Get-VeeamBackupMetadata -Agent $vaClient -File $file
    foreach($k in $_meta[$f].Keys) {
                if ($k -match $extension) {
                    $dt = $f.Substring($f.Length - 21).Split('.')[0]
                    Restore-VeeamBackupContent -Agent $vaClient -Oib $_meta[$f][$k] -Destination "$($destination)\$($_meta[$f][$k].Guid)-$($dt)-$($k)"
                }
            }
}
else {
    $_files = Get-ChildItem -Path $folder -Recurse -Directory | ForEach-Object { Get-ChildItem -Path $_.FullName | Sort-Object LastAccessTime -Descending }
    foreach ($_file in $_files) {
        $extn = [IO.Path]::GetExtension($_file)
        if (($extn -eq '.vib') -or ($extn -eq '.vbk') -or ($extn -eq '.vrb'))
        {
            write-host $_file.FullName
            $f = $_file.ToString()
            $_meta[$f] = Get-VeeamBackupMetadata -Agent $vaClient -File $_file.FullName
            foreach($k in $_meta[$f].Keys) {
                if ($k -match $extension) {
                    $dt = $f.Substring($f.Length - 21).Split('.')[0]
                    Restore-VeeamBackupContent -Agent $vaClient -Oib $_meta[$f][$k] -Destination "$($destination)\$($_meta[$f][$k].Guid)-$($dt)-$($k)"
                }
            }
        }
    }
}