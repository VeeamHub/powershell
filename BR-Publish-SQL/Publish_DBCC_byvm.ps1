# DBCC check using Veeam's SQL Publish feature v1.1
# By Carlos Talbot (carlos.talbot@veeam.com)
#
# This script should run on the SQL server the databases are attached to
# You will need to install the Veeam console on the SQL server in order to enable the Veeam PowerShell cmdlets
#
# Name of SQL Server and instance that'll be used to attached the published backup images and where the DBCC check will run.
$SQL_Server_Name = "SQL2017"
$SQL_Instance_Name = "VEEAMBR"
$VBRSERVER = "192.168.1.192"
#Set this to true to send an email at the end of the script
$Send_Email = $true
$Email_Acct = "sender@gmail.com"
$Email_Pass = "XXXXXXXXXX"
$Email_RCPT = "receiver@veeam.com"
# Uncomment the following two lines if you plan to use SQL Credentials for publishing the database to the running SQL Instance
# The default is to use Windows passthrough authentication
#$sqlcreds = Get-Credential
#$ntcreds = Get-Credential

# You should haven't to change anything after this line
#-------------------------------------------------------

# Default write cache for SQL Publish is C:\Windows\SysWOW64\config\systemprofile\AppData\Local
# This can be altered with a Reg key
# Key path: HKEY_LOCAL_MACHINE\SOFTWARE\Veeam\Veeam Backup and Replication
# Key type: REG_SZ
# Path must be without “\” at the end of the string and it must exist on the server.

Add-PSSnapin VeeamPSSnapin
Import-Module Veeam.SQL.PowerShell

Connect-VBRServer -Server $VBRSERVER

$errors_found = $false

function Send-Email
{
    param($Body)

    $credentials = new-object Management.Automation.PSCredential $Email_Acct, ($Email_PASS | ConvertTo-SecureString -AsPlainText -Force)
    $From = $Email_Acct
    $To = $Email_RCPT
    
    if ($errors_found) {
        $Subject = "Results from SQL DBCC run - DBCC ERRORS found"
    } else {
        $Subject = "Results from SQL DBCC run - NO ERRORS"
    }
    
    $SMTPServer = "smtp.gmail.com"
    $SMTPPort = "587"
    Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -UseSsl -Credential $credentials –DeliveryNotificationOption OnSuccess
}


function Test-Database
{
    param($SQLINST, $DatabaseName)


    $Sql = "DBCC CHECKDB ($DatabaseName);"
    $CheckDbMessages = @()
    $CheckDbWatch = [System.Diagnostics.Stopwatch]::StartNew()
    SQLCMD.EXE -S "$SQLINST" -E -Q $Sql |
    ForEach-Object {
      $CheckDbMessages += $_
    }
    $CheckDbWatch.Stop()

    if ($CheckDbMessages[($CheckDbMessages.Count) - 2] -clike 'CHECKDB found 0 allocation errors and 0 consistency errors in database *') {
      return
    }
    else {
      return "Error in integrity check of the database [$DatabaseName]:`n  $($CheckDbMessages[($CheckDbMessages.Count) - 2])"
    }
}


$email=""
$CheckDbWatch = [System.Diagnostics.Stopwatch]::StartNew()

#Return all VMs/Phyiscal Servers that have a SQL restore point
$VMs = Get-VBRApplicationRestorePoint -SQL | Sort-Object -Property Name -Unique
$VM_Count = (Get-VBRApplicationRestorePoint -SQL | Sort-Object -Property Name -Unique).Count
$DB_Count = 0

foreach($VM in $VMs) { 

    Write-Host "Instance - " -NoNewline
    Write-Host -ForegroundColor Yellow $VM.Name
    $email += "`nInstance -" + $VM.Name + " `n"
    # Grab the most recent restore point for the given VM/Physical Server
    $restorepoint = Get-VBRApplicationRestorePoint -SQL -Name $VM.Name | Sort-Object –Property CreationTime –Descending | Select -First 1
    if ($restorepoint) {
        Write-Host "     mounting Restore Point from ", $restorepoint.CreationTime
        $email += "     mounting Restore Point from " + $restorepoint.CreationTime + " `n"
        $session = Start-VESQLRestoreSession -RestorePoint $restorepoint

        $DB_Count += (Get-VESQLDatabase -Session $session).count
        foreach ($db in Get-VESQLDatabase -Session $session) {
            $db_tempname = $db.name+"-temp"
            Write-Host "     Publishing " -NoNewline
            Write-Host -ForegroundColor Green $db_tempname
            $email += "     Publishing " + $db_tempname + " `n"
   
            if ($sqlcreds) {       # Use SQL authentication
                $database = Publish-VESQLDatabase -Database $db -ServerName $SQL_Server_Name -InstanceName $SQL_Instance_Name -DatabaseName $db_tempname -UseSQLAuthentication  -SqlCredentials $sqlcreds -GuestCredentials $ntcreds
            } else {               # Use Windows passthrough authentication
                $database = Publish-VESQLDatabase -Database $db -ServerName $SQL_Server_Name -InstanceName $SQL_Instance_Name -DatabaseName $db_tempname
            }

            Write-Host "     Running CHECKDB on " $db_tempname
            $email += "     Running CHECKDB on " + $db_tempname + " `n"
            $CheckDbWatch.Restart()
            $ret = Test-Database -SQLINST "$SQL_Server_Name\$SQL_Instance_Name" -DatabaseName "'$($db_tempname)'"
            if (!$ret) {
                $CheckDbWatch.Stop()
                Write-Host -ForegroundColor Green "     $db_tempname - " -NoNewline
                Write-Host "Checks out OK."
                Write-Host "     Integrity check done in $($CheckDbWatch.Elapsed.ToString()) [hh:mm:ss.ddd]"
                $email += "     $db_tempname -  Checks out OK  Integrity check done in $($CheckDbWatch.Elapsed.ToString()) [hh:mm:ss.ddd]" + " `n"
            } else {
                $CheckDbWatch.Stop()
                Write-Host -ForegroundColor Red "     $db_tempname - " -NoNewline
                Write-Host "Errors Found!"
                Write-Host "     Integrity check done in $($CheckDbWatch.Elapsed.ToString()) [hh:mm:ss.ddd]"
                Write-Host -ForegroundColor Red $ret
                $email += "     $db_tempname -  DBCC ERRORS!" + " `n" + $ret + " `n"
                $errors_found = $true
            }
            Unpublish-VESQLDatabase -Database $database -Confirm:$false
        }
        Stop-VESQLRestoreSession -Session $session
    }
   
}

Disconnect-VBRServer

Write-Host -ForegroundColor Green "$VM_Count Instances and $DB_Count Databases processed"
$email += "$VM_Count Instances and $DB_Count Databases processed"

if ($Send_Email) {
    Send-Email ($email)
}
