# Veeam Availability Console Backup Policy Migration

## VeeamHub

VeeamHub projects are community driven projects and are not created by Veeam R&D or validated by Veeam Q&A. They are maintained by community members which may or not be Veeam employees.

## Distributed under MIT license

Copyright (c) 2019 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Project Notes

### Author

Chris Arceneaux (@chris_arceneaux)

### Function

This script will allow you to migrate all Backup Policies from one VAC instance to another. This can be highly beneficial when consolidating VAC appliances.

### Requirements

**NOTE:** There is a bug in the - _POST /v2/backupPolicies_ - API call that prevents Application-Aware Processing settings from being defined. To work around this, this script will strip the app-aware settings from the policy prior to creation. After the script has completed, it will output the Backup Policies that need to be fixed as well as the settings to configure.

* Veeam Availability Console version 2 Update 1 & version 3.x
  * Portal Administrator account used to access the Rest API.

### Usage

Get-Help .\VAC-MigratePolicies.ps1

After the script has completed, don't forget to...

* Fix Application-Aware Processing settings accordingly on the newly created Backup Policies.
* Assign private Backup Policies to their corresponding companies.
