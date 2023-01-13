# Automated Veeam Backup Tape Media Move to Free pool from Unreconized Pool

## Author

Marty Williams (@skitch210)

## Function

This script is designed to help automate the import of new tapes from the Unreconized Pool(Default) into the Free Pool


***NOTE:*** Before executing this script in a production environment, I strongly recommend you:

* Read [Veeam's Backup Documentation](https://helpcenter.veeam.com/docs/backup/vsphere/tape_device_support.html?ver=110)
* Fully understand what the script is doing
* Test the script in a lab environment

## Known Issues

* 

## Requirements

* Veeam Backup & Replication 11a or later
* Supported Tape Library
* Tape Server Role configured in Veeam Backup

## Additional Information

Would suggest setting this up as a Scheduled Task