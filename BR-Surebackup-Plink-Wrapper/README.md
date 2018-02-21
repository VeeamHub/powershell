## VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

## Distributed under MIT license
Copyright (c) 2018 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes
**Author:** Timothy Dewin

**Function:** Allows you to verifiy a linux VM with plink

**Requires:** Tested against VBR 9.5 but might work with any version. Tested with plink 0.62 but might work with any version


**Parameters:**
* -plink "C:\bin\plink.exe"
	* Default "C:\bin\plink.exe" ; location of plink
* -ip %vm_ip%
	* What is the masked IP of the server, use %vm_ip% in the surebackup setup.
* -fexist "/root/hellodarknessmyoldfriend.txt"
	* What file should be checked, by default an awkward document name that should never exist on a server
* -username root
	* What account to use to do the test
* -password mysupersecretpass
	* What password to use
* -logpref "[linuxfexist]"
	* Default "[linuxfexist]" will make sure that write-hosts will be prefixed so you can easily find the output in the logs
* -timeout 30
	* Kills plink if it doesn't stop after 30 seconds (for example incorrect pass)

