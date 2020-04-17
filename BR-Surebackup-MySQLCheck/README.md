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

**Function:** Allows you to verifiy if MySQL is succesfully working in your Virtual Lab (Surebackup)

**Requires:** 
Backup & Replication v9 

Download dotnet connector https://dev.mysql.com/downloads/connector/net/ 
Tested with v8.0.19

Inspired by https://www.techtrek.io/connecting-powershell-to-mysql-database/ (v8 correct path, path detection added)

**Usage:** Schedule the script via the Application Group or via the "Surebackup" job > "Linked Job" section.

**Parameters:**

* -server %vm_ip%
	* What is the masked IP of the SQL server, use %vm_ip% in the Surebackup setup.
* -user user
	* What is the mysql user
* -password password
	* What is the mysql password
* -port 3306
* -query 
	* What do you want to query to test the result e.g "select * from database.tablename",
* -minreply
	* How many rows you minimum expect to return from the query (executes a scalar query)
