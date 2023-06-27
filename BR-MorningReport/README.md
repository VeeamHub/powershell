# Morning report
This script get the last backups results (the last 15 hours by default) and send it by email.

Here is a preview :
![](https://github.com/Weylin-fr/Veeam/blob/57257497eaa3b6ddab1c2ee12604a94b519b34cb/BR-MorningReport/sample.png)

## Features
* Get results of VM backup jobs, agent backup jobs, backup copy jobs and tape jobs.
* Get errors from failed and warning jobs
* Signal crypted backup jobs to prevent involuntary crypted backups

## Usage
1. Edit the parameters on top of the script
2. Feel free to edit the mail template
3. Create a schedule task to execute every morning at 9am (thus get backup jobs from 6pm to 9am)
4. ...
5. Profit!