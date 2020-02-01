# SNOW Incident creation via Veeam One alerts
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2016 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Carlos Talbot (@tusc00)

# Service Now Incident creation and resolution
By Carlos Talbot (carlos@talbot.net)
The two scripts in this folder are required for setting up Veeam One to automatically create and resolve
Service Now incident tickets.

IMPORTANT:
The sript createticket.ps1 needs to be run for the first time interactively from a PowerShell command line. The script
will prompt you for the username and password of your SNOW instnace which is then stored in an encrypted file in the
same directory as the script. You need to run this as the same account as the VeeamOne service is running 
as (e.g. LOCAL Administrator). Below is an example you can use to run the script:
c:\scripts\createticket.ps1 "VM power status" "EXCH2K16" "virtual machine is not Running" "1/29/2020 9:56:38 PM" "Error" "Reset/Resolved" "21117"


Configuring Veeam One
You need to edit the alarm that will trigger the scripts with the settings below under the Notifications tab. The full line for each script is as follows (change path to scripts as required):

powershell.exe C:\scripts\createticketv2.ps1 '%1' '%2' '%3' '%4' '%5' '%6' '%7'
powershell.exe C:\scripts\resolveticketv2.ps1 '%1' '%2' '%3' '%4' '%5' '%6' '%7'

![alt text](https://i.imgur.com/7zcsC1q.png)

You can set a variable in each of the scripts to enable writing to a debug file (SNOWdebug.log) by setting the
variable $Debug = $true
