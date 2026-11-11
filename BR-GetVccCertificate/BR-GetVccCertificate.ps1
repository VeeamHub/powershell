<#
.SYNOPSIS
Connects to a Veeam Cloud Connect server, performs handshake, exports SSL certificate as <HostName>.cer, and optionally downloads CRL/OCSP files.

.PARAMETER HostName
Hostname or IP of the Veeam Cloud Connect server.

.PARAMETER Port
TCP port to connect to.

.PARAMETER OutputFolder
The folder to save the certificate and any downloaded CRL/OCSP files.

.PARAMETER DownloadCRLandOCSP
If set, CRL and OCSP URLs found in the certificate will be downloaded into OutputFolder.

.EXAMPLE
.\BR-GetVccCertificate.ps1 -HostName "ProviderIPorDNS" -Port 6180 -OutputFolder "C:\temp" -DownloadCRLandOCSP
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$HostName,

    [Parameter(Mandatory)]
    [int]$Port,

    [Parameter(Mandatory)]
    [string]$OutputFolder,

    [Parameter()]
    [switch]$DownloadCRLandOCSP
)

# Hardcoded ConnRuleString
$ConnRuleString = "C6943F73-E720-48f5-A393-0A665F2A6901"

function Sanitize-FileName {
    param([string]$Name)
    # Remove invalid filename characters
    return ($Name -replace '[\\/:*?"<>|]', '_')
}

function Send-Request {
    param (
        [System.IO.Stream]$Stream,
        [string]$ConnRuleString
    )
    try {
        $packet = New-Object System.Byte[] 0
        $versionSpecificFlags = 0
        $versionSpecificFlagsBytes = [System.BitConverter]::GetBytes($versionSpecificFlags)
        $packet += $versionSpecificFlagsBytes
        $connRuleBytes = [System.Text.Encoding]::ASCII.GetBytes($ConnRuleString)
        $packet += [System.BitConverter]::GetBytes($connRuleBytes.Length)
        $packet += $connRuleBytes
        $packetLenthBytes = [System.BitConverter]::GetBytes($packet.Length)
        $Stream.Write($packetLenthBytes, 0, $packetLenthBytes.Length)
        $Stream.Write($packet, 0, $packet.Length)
        $Stream.Flush()
    } catch {
        throw "Error occurred while sending request: $_"
    }
}

function Receive-Response {
    param ([System.IO.Stream]$Stream)
    try {
        $response = New-Object System.Byte[] 32
        $Stream.Read($response, 0, $response.Count) | Out-Null
        $code = [System.BitConverter]::ToInt32($response, 0)
        switch ($code) {
            0 { Write-Host "Connection to the cloud gateway has been accepted" -ForegroundColor Green }
            Default { throw "The server returned non-zero response: $code" }
        }
    } catch {
        throw "Error occurred while receiving response: $_"
    }
}

function Perform-Handshake {
    param (
        [System.IO.Stream]$Stream,
        [string]$ConnRuleString
    )
    Send-Request -Stream $Stream -ConnRuleString $ConnRuleString
    Receive-Response -Stream $Stream
}

function Connect-VCC {
    param (
        [System.Net.Sockets.TcpClient]$TcpClient,
        [string]$HostName,
        [int]$Port
    )
    try {
        $TcpClient.Connect($HostName, $Port)
    } catch {
        throw "Network error: Unable to connect to ${HostName}:${Port}. $_"
    }
}

function Export-RemoteCertificate {
    param (
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert,
        [string]$OutFile
    )
    $bytes = $Cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    [System.IO.File]::WriteAllBytes($OutFile, $bytes)
    Write-Host "Certificate exported to $OutFile" -ForegroundColor Green
}

function Download-CRL-OCSP {
    param (
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert,
        [string]$Folder
    )
    if (!(Test-Path $Folder)) { New-Item -Path $Folder -ItemType Directory | Out-Null }
    $crlUrls = @()
    $ocspUrls = @()
    foreach ($ext in $Cert.Extensions) {
        if ($ext.Oid.Value -eq "2.5.29.31") {
            $raw = $ext.Format($true)
            $matches = [regex]::Matches($raw, 'http[s]?://[^\s,]+')
            $matches | ForEach-Object { $crlUrls += $_.Value }
        }
        elseif ($ext.Oid.Value -eq "1.3.6.1.5.5.7.1.1") {
            $raw = $ext.Format($true)
            $matches = [regex]::Matches($raw, 'OCSP - URI:(http[s]?://[^\s,]+)')
            $matches | ForEach-Object { $ocspUrls += $_.Groups[1].Value }
        }
    }
    foreach ($url in $crlUrls) {
        try {
            $file = Join-Path $Folder ([System.IO.Path]::GetFileName($url))
            Invoke-WebRequest -Uri $url -OutFile $file -ErrorAction Stop
            Write-Host "Downloaded CRL: $url" -ForegroundColor Cyan
        } catch {
            Write-Warning "Failed to download CRL: $url. $_"
        }
    }
    foreach ($url in $ocspUrls) {
        try {
            $file = Join-Path $Folder ([System.IO.Path]::GetFileName($url) + ".ocsp")
            Invoke-WebRequest -Uri $url -OutFile $file -ErrorAction Stop
            Write-Host "Downloaded OCSP: $url" -ForegroundColor Cyan
        } catch {
            Write-Warning "Failed to download OCSP: $url. $_"
        }
    }
}

# Main Logic
try {
    $TcpClient = New-Object System.Net.Sockets.TcpClient
    Connect-VCC -TcpClient $TcpClient -HostName $HostName -Port $Port
    $Stream = $TcpClient.GetStream()
    Perform-Handshake -Stream $Stream -ConnRuleString $ConnRuleString

    $SslStream = New-Object System.Net.Security.SslStream($Stream, $false, { $true })
    try {
        $SslStream.AuthenticateAsClient($HostName, $null, [System.Security.Authentication.SslProtocols]::Tls12, $false)
    } catch {
        throw "Authentication error: SSL handshake failed. $_"
    }

    $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($SslStream.RemoteCertificate)
    if (!(Test-Path $OutputFolder)) { New-Item -Path $OutputFolder -ItemType Directory | Out-Null }
    $SafeHostName = Sanitize-FileName -Name $HostName
    $CertFile = Join-Path $OutputFolder ("$SafeHostName.cer")
    Export-RemoteCertificate -Cert $Cert -OutFile $CertFile

    if ($DownloadCRLandOCSP) {
        Download-CRL-OCSP -Cert $Cert -Folder $OutputFolder
    }
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
finally {
    if ($null -ne $SslStream) { $SslStream.Dispose() }
    if ($null -ne $Stream)    { $Stream.Dispose() }
    if ($null -ne $TcpClient) { $TcpClient.Close() }
}