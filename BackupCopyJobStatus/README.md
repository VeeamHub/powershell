# HTML Report of all Veeam Backup Copy Jobs in Powershell

http://mikeconjoice.com/2017/01/12/html-report-of-all-veeam-backup-copy-jobs-in-powershell/

Due to the way our infrastructure operates, we have a number of remote sites backing up to a central Veeam repository (~300 branches at present)

We get a number of requests from the network team on bandwidth usage issues which is always finger pointed at the Veeam Backup Copy jobs.

I put together the following Powershell script to report on all the Backup Copy jobs currently configured and return their status.

There are a number of parameters which can be configured on the script:

`-Server` - This specifies the Veeam server to run the report against (Defaults to `localhost` if no parameter is specified)

`-Outfile` - This specifies the location in which to save the HTML report (Defaults to `C:\Reports\CopyJobStatus.html` if no parameter is specified)

If you're running this on a machine other than your Veeam server, you'll need to have the `VeeamPSSNapin` Snapin available (Installed alongside the Veeam B&R Console)

Internally, we have this running as a scheduled task every 30 minutes saving the report to a web server accessible to all teams. A screenshot of the report is available [here!](http://i.imgur.com/c5qqXeq.png" target="_blank)