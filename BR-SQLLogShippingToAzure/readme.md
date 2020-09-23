VeeamHub
VeeamHub projects are community driven projects, and are not created by Veeam R&D nor validated by Veeam Q&A. They are maintained by community members which might be or not be Veeam employees.

Project Notes
Author(s): Johan Huttenga (Veeam Software)

**Functionality of the script:**  
This will copy Veeam SQL Log backup files (*.vsm,*.vlm,*.vlb) in a specific repository in parallel to Azure Blob based on log age.

**Running the script:**  
This example script is made to run as a scheduled task. Be sure to update the values with the relevant repository path, Azure Blob url and SAS token.

WARNING: In this example the SAS token is stored as plain text. You will need to use the Windows Credentials manager to store this or use DPAPI to encrypt and decrypt this content on the fly.

**The output of the script:**  
The script will create a log file by the same name as the script with a timestamp associated. 

🤝🏾 License
Copyright (c) 2020 VeeamHub

MIT License