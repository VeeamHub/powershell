Veeam Backup & Replication - Audit Log Export and Email Report
==============================================================

![alt tag](https://jorgedelacruz.uk/wp-content/uploads/2024/10/VBR-AUDIT-PS-EMAIL.jpg)

This script automates the process of exporting Veeam Backup & Replication (VBR) audit logs within a specified date range and emailing the formatted report. It dynamically names the CSV report based on the current date and time, embeds the CSV content as an HTML table within the email body, and attaches the CSV file to the email. This makes it ideal for audits, compliance checks, and regular monitoring tasks.

**Please note:** The script is provided as-is, and support tickets will not be entertained for this project.

----------

### Getting Started

You can follow the steps outlined in the following Blog Post to get started:
Will write it later

Alternatively, follow these simple steps:

1. **Download the PowerShell Script**
   - Obtain the `VBR_AuditExport_EmailReport.ps1` file from the repository.

2. **Configure the Parameters**
   - Open the script in a text editor.
   - Update the following parameters with your environment details:
     - **VBR Server Connection:**
       ```powershell
       $VBRServer = "YOURVBR"
       $VBRUser = "DOMAINORWORKGROUP\Administrator"
       $VBRPassword = "YOURPASSWORD"
       ```
     - **Audit Export Details:**
       ```powershell
       $FromDate = Get-Date -Year 2023 -Month 2 -Day 2 -Hour 0 -Minute 0 -Second 0
       $ToDate = Get-Date -Year 2024 -Month 10 -Day 4 -Hour 0 -Minute 0 -Second 0
       ```
     - **Email Configuration:**
       ```powershell
       $TenantId = "YOURTENANT.onmicrosoft.com"
       $ClientId = "YOURCLIENTID"
       $ClientSecret = "YOURSECRETFORAPP" 
       $SenderEmail = "your@email.com"
       $RecipientEmail = "recipient@mail.com"
       $EmailSubject = "[Report] Veeam Backup & Replication Infrastructure Audit"
       $EmailBodyText = @"
       Dear Customer,
       
       Find attached the Veeam Backup & Replication Audit Report.
       
       Best Regards,
       Your Veeam Sentinel
       "@
       ```

3. **Run the Script**
   - Open PowerShell with administrative privileges.
   - Navigate to the directory containing the script.
   - Execute the script:
     ```powershell
     .\VBR_AuditExport_EmailReport.ps1
     ```

4. **Access the Report**
   - Check your email inbox for the report containing both the embedded HTML table and the CSV attachment.

----------

### Additional Information
* Looking to enhance the report further? Share your ideas and suggestions!

### Known Issues 
* Nothing at the moment

