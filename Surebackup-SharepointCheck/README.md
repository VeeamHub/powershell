# Surebackup Sharepoint Check

**Author:** Timothy Dewin

**Function:** Allows you to verifiy if Sharepoint is succesfully working in your Virtual Lab (Surebackup)

**Requires:** Backup & Replication v9

**Usage:** Schedule the script via the Application Group or via the "Surebackup" job > "Linked Job" section. Configure credentials in the application group. Use the -server parameter to pass the ip of the server

**Parameters:**

* -server %vm_ip%
	* What is the masked IP of the Sharepoint server, use %vm_ip% in the surebackup setup.
* -path "/Shared%20Documents/contenttest.txt"
	* What document will be downloaded
* -content "sharepoint is working succesfully"
	* What should be the content of the document
