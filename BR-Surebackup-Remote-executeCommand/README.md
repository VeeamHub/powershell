# Surebackup SSH Remote-executeCommand and Service Oracle Service Check
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2020 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Lion Kim

**Function:** Remote Command and Execute (Linux) Template for Backup Verification Target VM

**Requires:** 
Backup & Replication v11 or v12

Refer to the plink.exe file provided during VEEAM installation.

**Watch out**
Password is plaintext passed. You might want to secure it a bit better or lock down the rights of the user correctly

**Usage:** Schedule the script via the Application Group or via the "Surebackup" job > "Linked Job" section.

For example : 
-ip %vm_ip% -fexist "{execution file path}

example
-ip %vm_ip% -fexist "/veeam/oracle_start.sh"
(You must create a script in the verification target and back it up.)


**Parameters:**

* -ip %vm_ip%
	* What is the masked IP of the Linux server, use %vm_ip% in the Surebackup setup.
* -fexist
	* Specify the script path to be executed during surebackup.
