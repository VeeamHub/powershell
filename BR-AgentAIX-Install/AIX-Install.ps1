$conn=Import-Csv path to csv file
$Password = ConvertTo-SecureString $conn[0].passwd -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($conn[0].user, $Password)
new-sshsession -computername $conn[0].server -credential $Credential -acceptkey

#If server already has NFS share mounted, you can comment out the mount commands below

# Adjust mount point directory for your server
invoke-sshcommand -Index 0 -Command "mkdir /nfsshare"

#Adjust NFS share and mount point to match your environment
#Make sure server has access to NFS Share
invoke-sshcommand -Index 0 -Command "mount -o vers=4 fqdn nfs server:/share /nfsshare"


#Install mlocate package prerequisite package
invoke-sshcommand -Index 0 -Command "echo 'all' |rpm -ivh /nfsshare/mlocate-0.26-1.aix6.1.ppc.rpm"

#Install Veeam Agent
invoke-sshcommand -Index 0 -Command "echo 'all' |rpm -ivh /nfsshare/VeeamAgent-4.0.0.891-ppc64.rpm"

#Run the veeamconfig XML file
invoke-sshcommand -Index 0 -Command "veeamconfig mode setVbrSettings --cfg /nfsshare/config.xml --force" -TimeOut 300 

#Run the veeamconfig sync now 
invoke-sshcommand -Index 0 -Command "veeamconfig mode syncnow" -TimeOut 300 