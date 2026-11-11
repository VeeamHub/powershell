# Veeam-Surebackup-vCenterCheck
SureBackup validation script for vCenter server.

This script is meant as a SureBackup test/validation script for vCenter Server to ensure it is functional when brought up in a lab environment.

## LICENSE
Distributed under MIT license

Copyright (c) 2017 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## PROJECT NOTES

**Author**: [Chip Zoller](https://github.com/chipzoller)

### Prerequisites
vCenter 5.5 through 6.5 backed up by Veeam, an application group containing vCenter and a domain controller, SureBackup virtual lab, and PowerCLI installed on Veeam Backup & Replication Server.

### Usage instructions
Create an application group which consists of at least vCenter Server and a domain controller. Download this script somewhere local to the Veeam Backup & Replication server and configure as the test script for the vCenter server. Set the "Maximum allowed boot time" to something sufficient to allow ample time for all the vCenter services to start--600 seconds may be sufficient. Add a new test script for vCenter using the script downloaded and passing the arguments "-server %vm_ip%" to it. Ensure the domain controller starts before vCenter. Create a virtual lab that contains said application group. Create a SureBackup job invoking the application group inside the virtual lab allowing it to validate the availability of vCenter when brought up inside it.

### Examples
1. Ensure you have a valid backup of at least one domain controller and a vCenter Server.
2. Create an Application Group that contains, at a minimum, one domain controller and one vCenter Server.
3. Order the startups so the domain controller starts before vCenter Server, and apply the necessary roles if desired to test the functionality of your domain controller.
4. For vCenter Server, adjust the "Maximum allowed boot time" number to account for time necessary to start all vCenter services. This is heavily dependent upon storage performance and other factors.
5. On the "Test scripts" tab, add a new test script and browse for the PS1 file downloaded that represents this test script.
6. Choose to "Use the following script" and select this script.
7. Name it appropriately, select the path, and input the arguments as follows:  -server %vm_ip%
8. Create a new Virtual Lab designed to test this application group.
9. Create a new SureBackup job using the new Application Group and Virtual Lab. This can optionally be linked to another job and/or scheduled.
10. Run the SureBackup job and ensure the Application Group is started in the correct order, invoking this vCenter test script in the virtual lab, and the job succeeds.
