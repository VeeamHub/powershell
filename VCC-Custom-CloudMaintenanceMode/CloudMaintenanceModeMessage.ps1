$registryPath = "HKLM:\SOFTWARE\Veeam\Veeam Backup and Replication"
$name = "CloudMaintenanceModeMessage"
clear
write-host

$existing = Get-ItemProperty "$registryPath"
$existingkey = $existing.CloudMaintenanceModeMessage

    write-host "Existing Maintenance Mode Message (if blank default is set):" $existingkey
    write-host
    write-host "Would you like to do?"
    write-host ""
    write-host " 1. Reset to default Maintenance Mode Message" 
    write-host " 2. Add or Modify existing Maintenance Mode Message"
    write-host "" 

    $answer = read-host "Please Make a Selection"
 
        if ($answer -eq 1)
            {
                Remove-ItemProperty -path $regkeypath -name $name 
                write-host
                write-host "--------------------------------------------------------------"
                write-host "Custome Cloud Connect Maintenance Mode Custom Message Deleted!"
                write-host "--------------------------------------------------------------"
                write-host
            }
        elseif ($answer -eq 2)
            {
               $value = read-host "Enter your custom Cloud Connect Maintenance Mode Message"
               New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType STRING -Force | Out-Null
               $regkey = Get-ItemProperty "$registryPath"

                write-host
                write-host "----------------------------------------------------"
                write-host "Cloud Connect Maintenance Mode Custom Message Added!"
                write-host "----------------------------------------------------"
                write-host
                write-host "New Message =" $regkey.CloudMaintenanceModeMessage
                write-host 
            }
        else 
            {
               write-host "You choose....poorly"
        exit 
            }