# Veeam Cloud Connect Usage Report
## VeeamHub
Veeamhub projects are community-driven projects and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members who might be, or might not be, Veeam employees.

## Distributed under MIT license
Copyright (c) 2025 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Ilya Sikorskiy

**Function:**
This script connects to a Veeam Cloud Connect Gateway server, performs a handshake, retrieves the SSL certificate, and saves it as HostName.cer in a specified folder. Optionally, it can also download CRL and OCSP files referenced in the certificate.

**Requires:**
PowerShell 5.1 or later
Network access to the Veeam Cloud Connect gateway
No additional Veeam PowerShell modules required

**Usage:**
Run the script from a PowerShell session on a Windows server or workstation with network connectivity to the Cloud Connect gateway.

**Parameters:**

* -HostName (string, required): Hostname or IP address of the Veeam Cloud Connect server
* -Port (int, required): Port number for the Cloud Connect server (typically 6180)
* -OutputFolder (string, required): The folder where the certificate and any CRL/OCSP files will be saved
* -DownloadCRLandOCSP (switch, optional): If specified, CRL and OCSP files referenced in the certificate will be downloaded to the output folder

**Example:**

.\BR-GetVccCertificate.ps1 -HostName "hostname.local" -Port 6180 -OutputFolder "C:\temp" -DownloadCRLandOCSP