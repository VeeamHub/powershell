# Surebackup SQL Check
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2016 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Timothy Dewin

**Function:** Allows you to verifiy if SQL is succesfully working in your Virtual Lab (Surebackup)

**Requires:** Backup & Replication v9

**Usage:** Schedule the script via the Application Group or via the "Surebackup" job > "Linked Job" section. Configure credentials in the application group. Use the -server parameter to pass the ip of the server

**Parameters:**

* -server %vm_ip%
	* What is the masked IP of the SQL server, use %vm_ip% in the Surebackup setup.
* -instance MSSQLSERVER
	* What is the instance name
* -minimumdb 4
	* What are the minimum amount of DBs that should be detected when connecting.  By default this is 4 to account for : master, model, msdb, tempdb