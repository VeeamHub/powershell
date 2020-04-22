# Surebackup SQL Check
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2020 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Timothy Dewin

**Function:** Allows you to verifiy linux vms but executing shell commands via ssh

**Requires:** 
Backup & Replication v10

Renci.SshNet.dll -> should be shipped with B&R v10 and detected by the script

**Watch out**
Password is plaintext passed. You might want to secure it a bit better or lock down the rights of the user correctly

**Usage:** Schedule the script via the Application Group or via the "Surebackup" job > "Linked Job" section.

For example : 
-server %vm_ip% -username timothy -password Root123!


**Parameters:**

* -server %vm_ip%
	* What is the masked IP of the SQL server, use %vm_ip% in the Surebackup setup.
* -user user
	* What is the mysql user
* -password password
	* What is the mysql password
* -servicecheck
	* What do you want to execute (default 'service mysql status')
* -matchoutput
	* Regex match on the output (default 'active [(]running[)]' which just confirms that the serivce is running)
