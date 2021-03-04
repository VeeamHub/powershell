# Veeam-Multi-FLR

# 📗 Documentation

## Project Notes
**Author:** Chris Evans <br>

**Thank you!:** https://github.com/fullenw1 and [his blog](https://itluke.online) where I found his [AWESOME write-up](https://itluke.online/2019/01/28/how-to-validate-the-file-parameter-in-powershell/#Valid%20and%20invalid%20syntax) on validating file/folder paths. Without this I never would've been able to figure out how to validate folder/file paths like I wanted.

## **Description:**
Allows for restoring the same folder/file from multiple backups to a separate location (ie. 'Copy To' functionality)

## **Requires:** <br>
Backup & Replication v9+ (possibly earlier, but haven't validated)<br>
Tested with **v10.0.1.4854** and **v11.0.0.837**

## **Background:** <br>
I had a client who had daily backups of a particular file that had to be retained indefinitely during a legal case. At one point the client was asked to restore a folder (including all files inside said folder) from every single day of the month for the months of September and October. That's 61 total File Level Restores that the client would've had to run via the GUI. I decided to create a PowerShell script that will allow you to input _Job Name_, _Server Name_, _Source Folder/File Path_, and _Target Restore Path_ and it will display a numbered list of backup points. Simply choose the starting index and stopping index and the script will recover the same folder/file from every backup point between the Start/Stop indexes.

## **Usage:** <br>
Execute **_Multi-FLR.ps1_** and input the required details when prompted. <br>
As long as the information is correct and backups are found, a numbered list will be displayed. Defaults to sorting from oldest to newest. <br><br>
![image](https://user-images.githubusercontent.com/22597403/109668164-e24fc700-7b3e-11eb-956e-9ad4721ae5b4.png) <br><br>
You will then be prompted if you would like to flip the sorting (ie. Newest to oldest) <br><br>
![image](https://user-images.githubusercontent.com/22597403/109668195-eb409880-7b3e-11eb-8a67-981f59a3a176.png) <br><br>
Each backup point will have an index (number on the far left). Choose the starting point (_$Start_). <br>
Then choose stopping point (_$Stop_). <br>
Restores will begin starting from the point chosen and will end at the chosen stopping point. Total number of restores would be _(($Stop - $Start) + 1)_ <br>
Restored files will be named *"RESTORED_%d-%b-%Y_%H-%M-%S \<original filename\>"* <br>

## **Prompts:**
* **Job Name:** Name of the job which backs up the server you wish to restore files from.
* **Server Name:** Hostname of the server you wish to restore files from.
* **Folder or File to Restore:** Path to folder or file which you would like to restore. (Example: _C:\temp\\_ or _C:\temp\file.txt_)
* **Copy To:** Drive path (or UNC path) where restored folder or file(s) will be copied to. (Example: _C:\temp\\_ or _\\\servername\c$\temp\\_)

## **Features**
* Basic error handling. It's not hard to break it if you purposefully input bogus information, but it should account for most common stuff.
* Basic input validation. Should properly validate given paths to ensure it either exists already or can be created if necessary.
* Basic debugging included (Uncomment line #1 to see debug output)

## **TO DO**
* Implement an option to choose multiple folders/files rather than 1 at a time
* Improve error handling/validation
* Consolidate/Refactor code to make it look neater
* Probably should add better comments/debugging as well

### VeeamHub
Veeamhub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees. 

### 🤝🏾 License
Copyright (c) 2020 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### ✍ Contributions

We welcome contributions from the community! We encourage you to create [issues](https://github.com/VeeamHub/veeam-multi-flr/issues/new/choose) for Bugs & Feature Requests and submit Pull Requests. For more detailed information, refer to our [Contributing Guide](CONTRIBUTING.md).

### 🤔 Questions

If you have any questions or something is unclear, please don't hesitate to [create an issue](https://github.com/VeeamHub/veeam-multi-flr/issues/new/choose) and let us know!
