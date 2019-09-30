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

### Known Issues

* _None_

### Requirements

* Veeam Availability Console version 2 Update 1 & [version 3 Patch 3](https://www.veeam.com/kb3003)
  * Portal Administrator account used to access each Rest API.

### Usage

Get-Help .\VAC-MigratePolicies.ps1

After the script has completed, don't forget to...

* PASSWORDS ARE NOT TRANSFERRED! Any and all passwords on all policies must be re-entered after the migration.
* Assign private Backup Policies to their corresponding companies.
