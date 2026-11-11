Veeam ONE Notifications to Slack
===================
Simple Script to attach to Veeam ONE Monitor to send notifications to Slack.

After everything is configured, you shall see something similar to the next:
![Veeam ONE 2 Slack](https://www.jorgedelacruz.es/wp-content/uploads/2019/12/vone-slack-003.png)

*Note: This project is a Community contribution. Use it at your own risk. 

----------

### Getting started
This simple Script will allow you or your Business to send the Veeam ONE Notifications to Slack, to an specific Channel where the IT Support or NOC Team is. By default the Script reads all the Veeam ONE variables according to:
* %1 - Alarm
* %2 - Fired node name
* %3 - triggering summary
* %4 - Time
* %5 - status
* %6 - old status
* %7 - id

- As a first step, please download and save inside your Veeam ONE Server the script called VeeamONE-Notification-Slack.ps1 from this repo.
- Edit the Script and under $uri introduce your Slack WebHook
- Then edit the relevant alert or alerts you want to send to Slack Channel, and under Notification, remove the default or add a new one, the Action should be set to Run Script, and inside the value should be the next:
```
powershell.exe "C:\YOURPATHTOTHESCRIPT\VeeamONE-Notification-Slack.ps1" '%1' '%2' '%3' '%4' '%5' '%6' '%7'
```
In case it helps, it should look like this:
![Veeam ONE 2 Slack](https://www.jorgedelacruz.es/wp-content/uploads/2019/11/veeamone-slack-009.png)
- That's it, you are ready to start receiving alerts to your favourite Channel


