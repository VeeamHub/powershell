# Veeam Light Weight Report
## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2020 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Timothy Dewin

**Version:** 0.1.1


You probably don't want to use it, instead:
- use veeam vbr enterprise manager if you have a simple non multitenant environment for central environment
- use veeam one if you want complete reportings
- use veeam vspc if you have a complex multitenant environment where you want to monitor everything centrally

This is only created for 2 special use case (in fact this are the 2 use cases that inspired me):
- secure environments where the means of transfering data is limited to certain protocol (email, ftp, ..)
- super low bandwidth where every byte counts and you want to have full control on how much reporting is done




## How it works
- run the localsite on every site you want to monitor on a frequent basis. make sure to change the sitename and uid in the script for every site
- json report will be dumped to c:\veeamlwr. It is your own duty to copy these files to a central location via the protocol of your liking
- put all reports on a central server under c:\veeamlwr
- run lwr-central to query the latest license status or job status (decided by the -mode parameter)
- It is your own duty to delete older files (you might want to keep them for tracking)

## Local Site 
Output should be nothing unless you add -verbose. Make sure -uniqueid is unique for every site but consistent for every run on each side
```
.\lwr-sitelocal.ps1 -uniqueid jkfjsdkjfksjkfds -sitename Main
```

## Central site
```
.\lwr-central.ps1 -mode jobquery
```
example:
```
PS C:\scripts> .\lwr-central.ps1 -mode jobquery

Site UpdateStatus       jobname currentstatus lastrun             laststatus
---- ------------       ------- ------------- -------             ----------
DC2  7/07/2020 15:29:28 linux   Stopped       21/04/2020 8:06:42  Success   
DC2  7/07/2020 15:29:28 fsnas   Stopped       15/04/2020 11:03:30 Success   
DC2  7/07/2020 15:29:28 windows Stopped       21/04/2020 7:11:29  Success   
DC3  7/07/2020 15:37:15 linux   Stopped       21/04/2020 8:06:42  Success   
DC3  7/07/2020 15:37:15 fsnas   Stopped       15/04/2020 11:03:30 Success   
DC3  7/07/2020 15:37:15 windows Stopped       21/04/2020 7:11:29  Success   
Main 7/07/2020 15:54:42 linux   Stopped       21/04/2020 8:06:42  Success   
Main 7/07/2020 15:54:42 fsnas   Stopped       15/04/2020 11:03:30 Success   
Main 7/07/2020 15:54:42 windows Stopped       21/04/2020 7:11:29  Success   
```

```
.\lwr-central.ps1 -mode licensequery
```
```
PS C:\scripts> .\lwr-central.ps1 -mode licensequery

date               sitename socketsused socketsinstalled instanceused instanceinstalled
----               -------- ----------- ---------------- ------------ -----------------
7/07/2020 13:38:32 DC                 0               12            0              1006
7/07/2020 14:43:06 DC                 0               12            0              1006
7/07/2020 15:29:28 DC2                0               12            0              1006
7/07/2020 15:37:15 DC3                0               12            0              1006
7/07/2020 15:54:42 Main               0               12            0              1006
```

# FAQ
Q: Should I use this?
A: No run away quickly if you have an alternative

Q: Is this reliable?
A: Probably not but in the use cases described, it's better than nothing

Q: Should I adapt the code?
A: Yes please!

Q: Will you add feature x?
A: No please!

Q: Why did you make it?
A: For a couple of special use case

Q: I don't understand how I need to transfer the files, can you help me?
A: Please refer to q/a 1 and q/a 4 for more information