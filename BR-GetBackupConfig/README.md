# Veeam Backup Configuration Export Script
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2018 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Johan Huttenga (@johanhuttenga)

**Version:** 0.1

**Function:** Queries Veeam Backup & Replication WMI and uses this to export data to CSV or MySQL. 

**Requires:** Access to Veeam Backup & Replication. Needs to be run with credentials that have WMI access. To use the MySQL export logic a local MySQL instance needs to be available.

**Usage:** 
-VBRServer: source VBR server to collect WMI data from
-VBRCredential: PowerShell credential object that has access to the VBR Server
-SQLServer: target MySQL server
-SQLDatabase: target MySQL database$
-SQLCredential: PowerShell credential object that has access to the MySQL database
[-Mode,$Interval] for future use.