# Veeam Backup Session Report
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2016 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Timothy Dewin (@tdewin)

**Function:** Mimics the report in B&R (when you select a job and click "Report").

**Requires:** Veeam Backup & Replication v9

**Usage:** 

.\MimicReport.ps1 -JobName "Backup Job 1"

.\MimicReport.ps1 -JobName "Backup Job 1" -Max 5

.\MimicReport.ps1 -JobName "Backup Job 1" -Max 5 -File "myfile.html"

**Parameters:**

* -JobName
	* Name of Job
* -Max
	* Max session, by default 0 which means infinite number of sessions
* -File
    * Filename for html, by default generated with a timestamp/jobname

**Sample:**
![Mimic Report](./Media/mimic.png)