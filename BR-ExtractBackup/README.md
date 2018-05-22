# Veeam Backup Data Extractor
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

**Function:** Starts the Veeam Backup Transport Service (VeeamAgent.exe) and instructs it to restore data based on extension from VBK, VIB and VRB files specified. This can either be a folder or an individual file.

**Requires:** Veeam Backup & Replication v9 or v9.5 Data Mover (VeeamAgent.exe). Needs to be run wherever the backup data is stored.

**Usage:** 
[-Folder]: source folder containing backup files to be extracted
[-File]: source backup file to be extracted
-Extension: file extension of content from backup files to be extracted
-Destination: destination folder with enough free space for extracted files

.\BR-ExtractBackup.ps1 -Folder D:\ -Extension ".xml" -Destination D:\Restored\
or
.\BR-ExtractBackup.ps1 -File D:\Backup-Job\backup-job.20180522.vbk -Extension "*" -Destination D:\Restored\