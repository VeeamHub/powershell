[String] $Server = <Veeam Ent. Server>
[Boolean] $HTTPS = $True
[String] $Port = "9398"
[String] $Authentication = "<dummy>"

#region: Workaround for SelfSigned Cert
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
#endregion

#region: Switch Http/s
if ($HTTPS -eq $True) {$Proto = "https"} else {$Proto = "http"}
#endregion

#region: POST - Authorization
[String] $URL = $Proto + "://" + $Server + ":" + $Port + "/api/sessionMngr/?v=v1_2"
Write-Verbose "Authorization Url: $URL"
$Auth = @{uri = $URL;
                   Method = 'POST';
                   Headers = @{Authorization = 'Basic ' + $Authentication;
           }
   }
try {$AuthXML = Invoke-WebRequest @Auth -ErrorAction Stop} catch {Write-Error "`nERROR: Authorization Failed!";Exit 1}
#endregion

#region: POST - Add BR Server
[String] $URL = $Proto + "://" + $Server + ":" + $Port + "/api/backupServers?action=create"
Write-Verbose "Add BR Server Url: $URL"
$BRServer = @{uri = $URL;
                   Method = 'POST';
				   Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId'];
                                'Content-Type' = 'application/xml'}
                   Body = '
                   <BackupServerSpec xmlns="http://www.veeam.com/ent/v1.0" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                     <Description>Veeam Lab Server</Description>
                     <DnsNameOrIpAddress>192.168.3.100</DnsNameOrIpAddress>
                     <Port>9392</Port>
                     <Username>Veeam-01\svc_veeam</Username>
                     <Password>Passw0rd!</Password>
                    </BackupServerSpec>
                    '
           } 
	
try {$BRServerXML = Invoke-RestMethod @BRServer -ErrorAction Stop} catch {Write-Error "`nERROR: Add BR Server Failed!";Exit 1}
#endregion

#region: GET - Get BR Server
[String] $URL = $Proto + "://" + $Server + ":" + $Port + "/api/backupServers"
Write-Verbose "Get BR Server Url: $URL"
$BRServer = @{uri = $URL;
                   Method = 'GET';
				   Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId']}
           } 
	
try {$BRServerXML = Invoke-RestMethod @BRServer -ErrorAction Stop} catch {Write-Error "`nERROR: Get BR Server Failed!";Exit 1}

#endregion

#region: POST - Collect BR Server
[String] $URL = $BRServerXML.EntityReferences.Ref.Href + "?action=collect"
Write-Verbose "Collect BR Server Url: $URL"
$BRServer = @{uri = $URL;
                   Method = 'POST';
				   Headers = @{'X-RestSvcSessionId' = $AuthXML.Headers['X-RestSvcSessionId']}
           } 
	
try {$BRServerXML = Invoke-RestMethod @BRServer -ErrorAction Stop} catch {Write-Error "`nERROR: Collect BR Server Failed!";Exit 1}
#endregion