# Johan Huttenga, 20221107

$LogFile = "BR-UpdateReplicaIp.log"
$CurrentPid = ([System.Diagnostics.Process]::GetCurrentProcess()).Id
$ViConnections = @{}
Function Write-Log {
    param([string]$str)      
    Write-Host $str
    $dt = (Get-Date).toString("yyyy.MM.dd HH:mm:ss")
    $str = "[$dt] <$CurrentPid> $str"
    Add-Content $LogFile -value $str
}     

Function Get-VBRSessionTaskStatus {
    param ($status)
    [Veeam.Backup.Common.ETaskLogRecordStatus] $result = [Veeam.Backup.Common.ETaskLogRecordStatus]::ENone 
    if ($status -eq "Warning") { $result = [Veeam.Backup.Common.ETaskLogRecordStatus]::EWarning }
    elseif ($status -eq "Failed") { $result = [Veeam.Backup.Common.ETaskLogRecordStatus]::EFailed }
    elseif ($status -eq "Success") { $result = [Veeam.Backup.Common.ETaskLogRecordStatus]::ESucceeded }
    return $result
}

Function Write-VBRSessionLog {
    param($session, $text, $status)
    $task = Create-VBRSessionTask $text -Status $status
    $recordid = $session.Logger.AddLog($task)
    $p = @{
            'RecordId'=$recordid
            'Task'=$task
    }
    $result = New-Object -TypeName PSObject -Prop $p
    return $result
}

Function Update-VBRSessionTask {
    param($session, $recordid, $text, $status)
    $result = 0
    if ($status -eq "Warning") {
            $result = $session.Logger.UpdateWarning($recordid, $text)
    }
    elseif ($status -eq "Failed") {
            $result = $session.Logger.UpdateErr($recordid, $text)
    }
    else {
            $result = $session.Logger.UpdateSuccess($recordid, $text)
    }
}

Function Complete-VBRSessionTask {
    param($session, $cookie, $status)
    $_status = Get-VBRSessionTaskStatus $status
    $session.Logger.Complete($cookie,$_status)
}

Function Create-VBRSessionTask {
    param ($text, $status = "Success")
    $_status = Get-VBRSessionTaskStatus $status
    $cookie = [System.Guid]::NewGuid().ToString()
    [Veeam.Backup.Common.CTaskLogRecord] $result = [Veeam.Backup.Common.CTaskLogRecord]::new($_status, [Veeam.Backup.Common.ETaskLogStyle]::ENone, 0, 0, $text, "", [System.DateTime]::Now, [System.DateTime]::Now, "", $cookie, 0)
    return $result
}

class InterfaceConfig {
    [String]$Name
    [String]$Type
    [String]$Description
    [String]$Mac
    [String[]]$Ipv4
    [String[]]$Ipv6
    [String]$Subnet
    [String]$Gateway
    [String]$Broadcast
}

function Parse-InterfaceConfig {
    param($config, $ostype, $method = "default")
    $result = @()
    
    $lines = $config.Split("`n")
    
    if (($ostype -eq "Linux") -and ($method -eq "default")) {
        $gw = $(ConvertFrom-Json $lines[0]) | Where-Object {$_.dst -eq "default"}
        $ifs = ConvertFrom-Json $lines[1]

        foreach ($ifcfg in $ifs) {
            $if = New-Object InterfaceConfig
            $if.Name = $ifcfg.ifname
            $if.Type = $ifcfg.link_type
            $if.Mac = $ifcfg.address
            $if.Ipv4 = $ifcfg.addr_info | Where-Object {$_.family -eq "inet"} | ForEach-Object {$_.local}
            $if.Ipv6 = $ifcfg.addr_info | Where-Object {$_.family -eq "inet6"} | ForEach-Object {$_.local}
            $if.Subnet = $ifcfg.addr_info | Where-Object {$_.family -eq "inet"} | ForEach-Object { "255."*$([math]::floor($_.prefixlen/8))+[System.Convert]::ToByte($("1"*($_.prefixlen%8)).PadRight(8,"0"),2)+".0"*$(4-$($_.prefixlen/8)) }
            $if.Gateway = $gw | Where-Object {$_.dev -eq $if.Name} | ForEach-Object {$gw.gateway}
            $if.Broadcast = $ifcfg.addresses | Where-Object {$_.family -eq "inet"} | ForEach-Object {$_.broadcast}
            $result += $if
        }
    }
    elseif (($ostype -eq "Linux") -and ($method -eq "ifconfig")) {
        $gw = $lines[0].Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)[2]
        for($i=1; $i -lt $lines.Count; $i++) {
            $l = $lines[$i]
            if ($l -like "*mtu*") {
                    if ($null -ne $ifcfg) { $result += $ifcfg }
                    $ifcfg = New-Object InterfaceConfig
                    $ifcfg.Ipv4 = @()
                    $ifcfg.Ipv6 = @()
                    $ifcfg.Name = $l.Split(":")[0]
            }
            elseif ($l -like "*inet6*") {
                    $cnf = $l.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
                    $ifcfg.Ipv6 += $cnf[1]
            }
            elseif ($l -like "*inet*") {
                    $cnf = $l.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
                    $ifcfg.Ipv4 += $cnf[1]
                    $ifcfg.Subnet = $cnf[3]
                    $ifcfg.Gateway = $gw
                    $ifcfg.Broadcast = $cnf[5]
            }
            elseif ($l -like "*ether*") {
                    $cnf = $l.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
                    $ifcfg.Mac = $cnf[1]
            }
        }
        if ($null -ne $ifcfg) { $result += $ifcfg } #>
    }
    else {
            $ifcfg = $null
            for($i=0; $i -lt $lines.Count; $i++) {
                $l = $lines[$i]
                if (($l -like "*adapter*") -and !($l -like "*description*")) {
                        if ($null -ne $ifcfg) { $result += $ifcfg }
                        $ifcfg = New-Object InterfaceConfig
                        $ifcfg.Ipv4 = @()
                        $ifcfg.Ipv6 = @()
                        if ($l -like "*Ethernet adapter*") {
                            $l = $l.Replace("Ethernet adapter ",""); $ifcfg.Type = "LAN"
                        }
                        elseif ($l -like "*PPP adapter*") {
                            $l = $l.Replace("PPP adapter ",""); $ifcfg.Type = "PPP"
                        }
                        elseif ($l -like "*Wireless LAN adapter*") {
                            $l = $l.Replace("Wireless LAN adapter ",""); $ifcfg.Type = "WLAN"
                        }
                        $ifcfg.Name = $l.Replace(":","")
                }
                elseif ($l -like "*description*") { $ifcfg.Description = $l.Split(":")[1].Trim() }
                elseif ($l -like "*IPv4 Address*") { $ifcfg.Ipv4 += $l.Split(":")[1].Trim().Replace("(Preferred)","") }
                elseif ($l -like "*IPv6 Address*") { $ifcfg.Ipv6 += $l.Substring($l.IndexOf(":")+2).Trim().Replace("(Preferred)","") }
                elseif ($l -like "*Subnet Mask*") { $ifcfg.Subnet = $l.Split(":")[1].Trim() }
                elseif ($l -like "*Default Gateway*") { $ifcfg.Gateway = $l.Split(":")[1].Trim() }
                elseif ($l -like "*Physical Address*") { $ifcfg.Mac = $l.Split(":")[1].Trim() }
            }
            if ($ifcfg -ne $null) { $result += $ifcfg }
    }
    return $result
}

function Get-VBRCredential {
    param ($id)

    # hack to force dependencies to load
    Get-VBRServer -? > $null

    $cred = ([Veeam.Backup.Core.CDbCredentials]::Get([System.Guid]::new($id))).Credentials
    if ($null -eq $cred) { 
        Write-Log "Error: Unable to query credential ($($cred)) associated with id ($($id)). Ensure it exists and this process is run with administrator permissions."
    }
    $decoded = [Veeam.Backup.Common.CStringCoder]::Decode($cred.EncryptedPassword, $true)
    $secpwd = ConvertTo-SecureString $decoded -AsPlainText $true
    return New-Object System.Management.Automation.PSCredential($cred.UserName, $secpwd)
}

function Add-VIConnection {
    param($Server, [PSCredential] $Credential, $CredentialId)

    $result = $null

    if ($null -eq $Credential) {
        Write-Log "Error: Cannot connect to $server as no credentials were specified."
        return
    }

    if (!($VIConnections.ContainsKey($Server)))
    {
            Write-Log "Connecting to $Server using credentials ($($Credential.UserName)) ($($CredentialId))."
            try { $VIConnections[$Server] = Connect-VIServer $Server -Credential $Credential -Force }
            catch {
                if ($null -ne $_.Exception.InnerException.Message) { Write-Log "Error: An error occurred when connecting to $($Server). $($_.Exception.InnerException.Message) " }
                else { Write-Log "Error: An error occurred when connecting to $($vm). $($_.Exception.Message)" }
            }
            if ($null -eq $VIConnections[$Server]) {
                Write-Log "Error: A connectivity issue has occurred when connecting to $Server."
            }
    }
    else {
        $result = $VIConnections[$Server]
    }

    return $result
}

function Apply-VMReIpRule {
    param($SourceIpAddress, $ReIpRule)
    $TargetIp = $ReIpRule.TargetIp
    for($i=1;$i -le 3; $i++) 
    {
            [regex]$pattern  = "\*"
            if ($ReIpRule.TargetIp.Split(".")[$i] -eq "*") { $TargetIp = $pattern.Replace($TargetIp,$SourceIpAddress.Split(".")[$i],1) }
    }
    return $TargetIp
}

function Call-VMScript {
    param($VM,[PSCredential] $GuestCredential, $ScriptText, $ScriptType, $ObfuscateStringOutput = $null)

    $output = "Invoking script: $($scripttext)"

    if($null -ne $ObfuscateStringOutput) { $output = $output.Replace($ObfuscateStringOutput,"***") } 
    
    Write-Log $output

    $output = $null

    try { $output = Invoke-VMScript -VM $vm -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext -ErrorAction Stop }
    catch {  
        if ($null -ne $_.Exception.InnerException.Message) { 
            Write-Log "Error: An error occurred when invoking the script on $($vm). $($_.Exception.InnerException.Message) " 
        }
        else { Write-Log "Error: An error occurred when invoking the script on $($vm). $($_.Exception.Message)" }
    }

    if (($null -ne $output) -and ($output.Length -gt 0)) { 
        if($null -ne $ObfuscateStringOutput) { $output = $output.Replace($ObfuscateStringOutput,"***") }
        Write-Log $output
    }

    return $output
}

function Get-VMGuestOperatingSystem {
    param($vm, [PSCredential] $GuestCredential)
    
    $scripttype = ""
    $scripttext = ""
    
    $ostype = "Linux" 
    $vm_os = $vm.Guest.OSFullName
    if ($vm_os -like "*Windows*") { $ostype = "Windows" }
    
    if ($ostype -eq "Linux") { 
            $scripttype = "Bash"
            $scripttext = "cat /etc/os-release" 
    }
    else { 
            $scripttype = "Bat" 
            $scripttext = "reg query `"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\`" /v ProductName"
    }
    
    $result = Call-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext
    
    return $result
}

function Get-VMGuestNetworkInterface {
    param($vm, [PSCredential] $GuestCredential)
    
    $scripttype = ""
    $scripttext = ""
    
    $ostype = "Linux"
    
    if ($ostype -eq "Linux") { 
            $scripttype = "Bash"
            $scripttext = "ip -json route && ip -json addr" # only works on newer systems
            $output = Call-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext
    }
    else { 
            $scripttype = "Bat" 
            $scripttext = "ipconfig /all"
            $output = Call-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext
    }
    $result = Parse-InterfaceConfig -Config $output -OSType $ostype
    
    return $result
}

function Test-SudoAccess {
    
    param($vm, [PSCredential] $GuestCredential)

    $vm_os = $vm.Guest.OSFullName
    $result = $false

    if ($vm_os -like "*Ubuntu*") { $ostype = "Ubuntu" }
    if ($ostype -eq "Ubuntu") {
        $scripttype = "Bash"
        
        $pwd = $([Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($guestcredential.password)))
        $scripttext = "set +H && echo $($pwd) | sudo -l -S -U $($guestcredential.username) && set -H"
        $output = Call-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext -ObfuscateStringOutput $pwd

        if ($output -like "*ALL : ALL*") { $result = $true }

    }

    return $result

}

function Backup-VMGuestNetworkConfig {
    param($vm, [PSCredential] $GuestCredential, $Elevate=$false)

    $vm_os = $vm.Guest.OSFullName

    if ($vm_os -like "*Ubuntu*") { $ostype = "Ubuntu" }
    if ($ostype -eq "Ubuntu") {
        $scripttype = "Bash"
        if ($Elevate) {
            $pwd = $([Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($guestcredential.password)))
            $scripttext = "echo $($pwd) | sudo -S sh -c 'ls /etc/netplan/*.yaml | xargs -I {} mv {} {}.bak'"
        }
        else {
            $scripttext = "ls /etc/netplan/*.yaml | xargs -I {} mv {} {}.bak"
        }
        $output = Call-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext -ObfuscateStringOutput $pwd
    }

    return $null
}

function Convert-IpAddressToMaskLength([string] $dottedIpAddressString)
{
  $result = 0; 
  # ensure we have a valid IP address
  [IPAddress] $ip = $dottedIpAddressString;
  $octets = $ip.IPAddressToString.Split('.');
  foreach($octet in $octets)
  {
    while(0 -ne $octet) 
    {
      $octet = ($octet -shl 1) -band [byte]::MaxValue
      $result++; 
    }
  }
  return $result;
}

function Set-VMGuestNetworkInterface {
    param($vm, $iface, $ipaddress, $netmask, $gateway, $dns, [PSCredential] $guestcredential, $Elevate=$false)
    $scripttype = "Bash"
    $scripttext = ""
    $ostype = "Linux" 
    $vm_os = $vm.Guest.OSFullName
    if ($vm_os -like "*CentOS*") { $ostype = "CentOS" }
    if ($vm_os -like "*Red Hat*") { $ostype = "RedHat" }
    if ($vm_os -like "*Ubuntu*") { $ostype = "Ubuntu" }
    if ($vm_os -like "*Windows*") { $ostype = "Windows" }
    if (($ostype -eq "Ubuntu")) { 
        
        $prefix = Convert-IpAddressToMaskLength($rule.TargetSubnet)

        # does not include search domain for dns servers
        $netplan = "network:\n  ethernets:\n    $($iface):\n      addresses:\n        - $($ipaddress)/$($prefix)"
        if ($null -ne $dns) {
            $netplan += "\n      nameservers:\n          addresses: [$($dns)]"
        }
        if ($null -ne $gateway) {
            $netplan += "\n      routes:\n        - to: default\n          via: $($gateway)"
        }
        
        if ($Elevate) {
            $pwd = $([Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($guestcredential.password)))
            $scripttext = "echo $($pwd) | sudo -S sh -c 'echo `"$($netplan)`" > /etc/netplan/01-netcfg.yaml'"
        }
        else {
            $scripttext = "echo `"$($netplan)`" > /etc/netplan/01-netcfg.yaml"
        }
        $output = Call-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext -ObfuscateStringOutput $pwd

        if ($Elevate) {
            $pwd = $([Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($guestcredential.password)))
            $scripttext = "echo $($pwd) | sudo -S netplan apply"
        }
        else {
            $scripttext = "netplan apply"
        }


        $output = Call-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext -ObfuscateStringOutput $pwd
        
        if ($Elevate) {
            $pwd = $([Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($guestcredential.password)))
            $scripttext = "echo $($pwd) | sudo -S bash -c 'echo DNSStubListener=no >> /etc/systemd/resolved.conf' && echo $($pwd) | sudo -S systemctl restart systemd-resolved" #"echo DNSStubListener=no | sudo -s tee -a /etc/systemd/resolved.conf && echo $($pwd) | sudo -s systemctl restart systemd-resolved"
        }else{
            Write-Log "Warning: No sudo access please ensure DNS will function correctly!"
        }

        $output = Call-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext -ObfuscateStringOutput $pwd
    }
    elseif ($ostype -eq "CentOS") { 
        $scripttext = "more /etc/sysconfig/network-scripts/ifcfg-" + $iface
        $output = Call-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext
        $lines = $output.Split("`n")
        $scripttext = "echo -e '"
        for($i = 3; $i -lt $lines.Count; $i++) {
            $select = $true
            $select = $select -and !($lines[$i] -like "*BOOTPROTO*") 
            $select = $select -and !($lines[$i] -like "*IPADDR*")
            $select = $select -and !($lines[$i] -like "*NETMASK*") 
            $select = $select -and !($lines[$i] -like "*GATEWAY*")
            if ($select) { $scripttext += $lines[$i].Trim() + "\n" }
        }
        $scripttext += "BOOTPROTO=""static"""
        $scripttext += "\nIPADDR=""$ipaddress"""
        $scripttext += "\nNETMASK=""$netmask"""
        $scripttext += "\nGATEWAY=""$gateway"""
        $scripttext += "' > /etc/sysconfig/network-scripts/ifcfg-$iface && service network restart"
        $output = Call-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext
        
        if ($null -ne $dns) {
            $scripttext = "echo -e '"
            $scripttext += "nameserver $dns"
            $scripttext += "' > /etc/resolv.conf" # network-scripts do not set the DNS server
            $output = Call-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext
        }
    }
    elseif ($ostype = "RedHat") { 
        $scripttext = "more /etc/sysconfig/network-scripts/ifcfg-" + $iface
        $output = Call-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext
        $lines = $output.Split("`n")
        $scripttext = "echo -e '"
        for($i = 3; $i -lt $lines.Count; $i++) {
            $select = $true
            $select = $select -and !($lines[$i] -like "*BOOTPROTO*") 
            $select = $select -and !($lines[$i] -like "*IPADDR*")
            $select = $select -and !($lines[$i] -like "*NETMASK*") 
            $select = $select -and !($lines[$i] -like "*GATEWAY*")
            if ($select) { $scripttext += $lines[$i].Trim() + "\n" }
        }
        $scripttext += "BOOTPROTO=static"
        $scripttext += "\nIPADDR="+$ipaddress
        $scripttext += "\nNETMASK="+$netmask
        $scripttext += "\nGATEWAY="+$gateway
        $scripttext += "' > /etc/sysconfig/network-scripts/ifcfg-$iface && ifdown $iface && ifup $iface"
        
        $output = Call-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext
        
        if ($null -ne $dns) {
            $scripttext = "echo -e '"
            $scripttext += "nameserver $dns"
            $scripttext += "' > /etc/resolv.conf" # network-scripts do not set the DNS server
            $output = Call-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext
        }
    }
    elseif ($ostype -eq "Linux") { 
    #do nothing 
    Write-output "Failed: Virtual Machine $($vm.Name) is running an unsupported operating system $($vm.Guest.OSFullName)."
    }
    elseif ($ostype -eq "Windows") { 
    #do nothing 
    Write-output "Skipped: Virtual Machine $($vm.Name) should have already been processed by Veeam Backup & Replication."
    }
}

function Wait-VMBoot {
    param ($Name, $sesionId, $SkipWaitForTools = $false, $SkipWaitForGuestDetails = $false)

    $vm = Get-VM -Name $Name
    
    if ($null -eq $vm) {
        Write-Log "Error: $($Name) does not exist or cannot be accessed."
        return
    }

    if (!($SkipWaitForTools)) {
            Write-Log "Waiting for $($Name) integration tools status (240 seconds max)..."
            $wait = 0
            $toolsstatus = $null
            try { $toolsstatus = ($vm = Get-VM -Name $Name | Get-View).Guest.ToolsStatus } catch { }
            $state = $null
            while ((($null -eq $toolsstatus) -or ($toolsstatus -ne "toolsOk")) -and ($wait -lt 240) -and ($state -ne "Failed")) {
                $wait = $wait +5;
                Sleep 5
                try { $vm = Get-VM -Name $Name } catch { }
                try { $toolsstatus = ($vm | Get-View).Guest.ToolsStatus } catch { }
                $state = $([Veeam.Backup.Core.CBackupSession]::Get([System.Guid]::new($sessionid))).State
                Write-Log "$($wait) : guest tools available : $($toolsstatus -eq "toolsOk")"
            }
    }
    if (!($SkipWaitForGuestDetails)) {
            Write-Log "Waiting for $($Name) integration tools data (240 seconds max)..."
            $wait = 0
            $os = $vm.Guest.OSFullName
            $state = $null
            while ((($null -eq $os) -or ($os.Length -eq 0)) -and ($wait -lt 240) -and ($state -ne "Failed")) {
                $wait = $wait +5;
                Sleep 5
                $vm = $vm = Get-VM -Name $Name
                $os = $vm.Guest.OSFullName
                Write-Log "$($wait) : guest data available : $($os -ne $null)"
                $state = $([Veeam.Backup.Core.CBackupSession]::Get([System.Guid]::new($sessionid))).State
            }
            if ($wait -eq 240) {
                Write-Log "Error: $($Name) ($($vm.PowerState)) integration tools not available or timeout occurred."
            }
            else {
                Write-Log "Success: $($Name) integration tools available."
            }
    }

    return $vm
}

Function Get-VBRFailoverPlanVMs
{
    Param($FailoverPlan, $Session)
    $platform = $FailoverPlan.BackupPlatform
    if ($platform = "EVMware") {    
        $foijs = $FailoverPlan.GetViOijs()
        $replicationjobs = [Veeam.Backup.Core.CBackupJob]::GetByTypeAndPlatform([Veeam.Backup.Model.EDbJobType]::Replica, [Veeam.Backup.Common.EPlatform]::EVmware , $false)
        $cdpreplicationjobs = [Veeam.Backup.Core.CBackupJob]::GetByTypeAndPlatform([Veeam.Backup.Model.EDbJobType]::CdpReplica, [Veeam.Backup.Common.EPlatform]::EVmware , $false)
    }
    else {
        # not supported
        $foijs = $FailoverPlan.GetHvOijs()
        $replicationjobs = [Veeam.Backup.Core.CBackupJob]::GetByTypeAndPlatform([Veeam.Backup.Model.EDbJobType]::Replica, [Veeam.Backup.Common.EPlatform]::EHyperV , $false)
        $cdpreplicationjobs = [Veeam.Backup.Core.CBackupJob]::GetByTypeAndPlatform([Veeam.Backup.Model.EDbJobType]::CdpReplica, [Veeam.Backup.Common.EPlatform]::EHyperV , $false)
    }

    #$replicationjobs = [Veeam.Backup.Core.CBackupJob]::GetByTypeAndPlatform([Veeam.Backup.Model.EDbJobType]::Replica, $platform, $false)
    $replicationjobs = $replicationjobs + $cdpreplicationjobs

    $result = @()
    foreach ($j in $replicationjobs) {
            $roijs = $j.GetObjectsInJob()
            foreach($ro in $roijs) {
                foreach ($fo in $foijs)
                {
                        if ($ro.Location -like $fo.Location)
                        {
                            if ($platform -eq [Veeam.Backup.Common.EPlatform]::EHyperV) {
                                    $rprefix = $j.Options.HvReplicaTargetOptions.ReplicaNamePrefix
                                    $rsuffix = $j.Options.HvReplicaTargetOptions.ReplicaNameSuffix
                                    $replicatoptions = $j.Options.HvReplicaTargetOptions
                            }
                            elseif ($platform -eq [Veeam.Backup.Common.EPlatform]::EVMware)
                            {
                                    $rprefix = $j.Options.ViReplicaTargetOptions.ReplicaNamePrefix
                                    $rsuffix = $j.Options.ViReplicaTargetOptions.ReplicaNameSuffix
                                    $replicatoptions = $j.Options.ViReplicaTargetOptions
                            }
                            $reiprules = @()
                            foreach($rule in $j.Options.ReIPRulesOptions.Rules) {
                                $r = @{
                                    'SourceIp'=$rule.Source.Ipaddress
                                    'SourceSubnet'=$rule.Source.SubnetMask
                                    'TargetIp'=$rule.Target.Ipaddress
                                    'TargetSubnet'=$rule.Target.SubnetMask
                                    'TargetGateway'=$rule.Target.DefaultGateway
                                    'TargetDNS'=[string]::Join(",",$rule.Target.DNSAddresses)
                                    'TargetWINS'=[string]::Join(",",$rule.Target.WINSAddresses)
                                }
                                $reiprules += New-Object -TypeName PSObject -Prop $r
                            }
                            if ($j.VssOptions) {
                                    $rcreds = $null
                                    $rcredid = $null
                                    if ($j.VssOptions.LinCredsId -ne [System.Guid]::Empty) { $rcredid = $j.VssOptions.LinCredsId }
                                    if ($j.VssOptions.WinCredsId -ne [System.Guid]::Empty) { $rcredid = $j.VssOptions.WinCredsId }
                                    if ($null -ne $rcredid) { $rcreds = Get-VBRCredential -Id $rcredid }
                            }
                            if ($j.TargetHostId) {
                                    $replicatarget = [Veeam.Backup.Core.Common.CHost]::Get([System.Guid]::new($j.TargetHostId))
                                    $rtparentci = $replicatarget.GetSoapConnHostInfo()
                                    $rtparentcredid = (([Veeam.Backup.Core.Common.CHost]::Get([System.Guid]::new($rtparentci.Id))).GetSoapCreds()).CredsId
                                    $rtparentcreds = Get-VBRCredential -Id $rtparentcredid
                            }
                            $p = @{
                                    'SessionId' = $session.Id
                                    'SourceName'=$ro.Name
                                    'Platform'=$platform
                                    'Path'=$ro.Location
                                    'PlanName'=$fo.Name
                                    'PlanId'=$fo.Id
                                    'PlanOijId'=$fo.Id
                                    'JobName'=$j.Name
                                    'JobId'=$j.Id
                                    'JobOijId'=$ro.Id
                                    'ReplicaName'=$rprefix + $ro.Name + $rsuffix
                                    'TargetHostId'=$j.TargetHostId
                                    'TargetParentConnectionInfo'=$rtparentci
                                    'TargetParentCredential'=$rtparentcreds
                                    'TargetParentCredentialId'=$rtparentcredid
                                    'TargetOptions'= $replicatoptions
                                    'ReipRules'=$reiprules
                                    'GuestCredential'=$rcreds
                                    'GuestCredentialId'=$rcredid
                            }
                            Write-Log ("$($fo.Name) ($($fo.Location)) is associated with " + $j.Name + ".")
                            $result += New-Object -TypeName PSObject -Prop $p
                        }
                }
            }
    }
    return $result
}

function Update-VMIPAddresses {
    param ($VM, $ReIpRules, [PSCredential] $GuestCredential)

    $_vm = Get-VM -Name $VM

    $nics = $null
    if ($null -ne $_vm) {
        $nics = Get-VMGuestNetworkInterface -VM $_vm -GuestCredential $GuestCredential
    }
    else {
        Write-Log "Error: Virtual Machine $($VM) is unavailable. Check parent server connections and permissions."
        return
    }
    if ($null -eq $ReIpRules) {
        Write-Log "Error: No ReIP rules specified. Check source replication job."
    }
    if ($null -ne $nics) {

            if ($_vm.Guest.OSFullName -like "*Windows*") {
                # windows vms are reip'd by veeam backup and replication but can be part of the same failover plan
                Write-Log "Skipped: $($VM) has the following network configuration:`n$($nics)"
                foreach($iface in $nics) { Write-Log "  $($iface.Name) ($($iface.Mac)), $($iface.Ipv4), Subnet: $($iface.Subnet)" }
            }
            else {

                Write-Log "$($VM) has the following network configuration:"
                foreach($iface in $nics) { Write-Log "  $($iface.Name) ($($iface.Mac)), $($iface.Ipv4), Subnet: $($iface.Subnet)" }
                Write-Log "$($VM) will have the following re-ip rules applied:"
                foreach($rule in $ReIpRules) { Write-Log "  Source: $($rule.SourceIp), Target: $($rule.TargetIP), Subnet: $($rule.TargetSubnet), Gateway: $($rule.TargetGateway)" }
    
                $elevate = $false
                if ($GuestCredential.UserName -ne "root") {
                    Write-Log "$($VM) checking if $($GuestCredential.UserName) has sudo access."
                    $sudo = Test-SudoAccess -VM $_vm -GuestCredential $GuestCredential

                    if ($sudo) {
                        $elevate = $true
                    }
                    else {
                        Write-Log "Error: $($GuestCredential.UserName) does not have sudo access. Check source replication job guest credentials."
                        return
                    }
                }

                Write-Log "$($VM) backing up existing network configuration."
                Backup-VMGuestNetworkConfig -VM $_vm -GuestCredential ($GuestCredential) -Elevate:$elevate

                foreach($rule in $ReIpRules)
                {
                    $matchednics = $nics | Where-Object { $_.Ipv4 -like $rule.SourceIp }
                    if ($null -ne $matchednics) {

                        foreach($iface in $matchednics) {

                            # setting ip address for interfaces which match source ip
                            
                            $trgip = Apply-VMReIpRule -SourceIpAddress $iface.Ipv4 -ReIpRule $rule

                            # convert subnet to prefix

                            Write-Log "Processing: Virtual Machine $($_vm.Name) interface: $($iface.Name), source: $($iface.Ipv4), target: $($trgip)"

                            Set-VMGuestNetworkInterface -VM $_vm -Iface $iface.Name -IpAddress $trgip -netmask $rule.TargetSubnet -Gateway $rule.TargetGateway -DNS $rule.TargetDNS -WINSAddresses $rule.TargetWINS -GuestCredential $GuestCredential -Elevate:$elevate

                            $cnics = Get-VMGuestNetworkInterface -VM $_vm -GuestCredential ($GuestCredential) | ?{ $_.Name -like $iface.Name }
                            
                            if (($null -ne $cnics) -and ($cnics.Ipv4 -eq $trgip)) { Write-Log "Success: Virtual Machine $($_vm.Name) interface $($cnics.Name) ($($cnics.Mac)) updated to $($cnics.Ipv4)" }
                            elseif ($null -ne $cnics) { 
                                Write-Log "Failed: $($VM) has the following network configuration:"
                                foreach($iface in $nics) { Write-Log "  $($iface.Name) ($($iface.Mac)), $($iface.Ipv4), Subnet: $($iface.Subnet)" }
                            }
                            else { Write-Log "Error: Virtual Machine $($_vm.Name) network configuration does not contain interface $($cnics.Name)." }

                        }
                        
                    }
                    else {
                        Write-Log "Warning: Virtual Machine $($_vm.Name) does not contain network interfaces matching $($rule.SourceIp)"

                        $unaddressednics = $nics | Where-Object { $_.Ipv4.Length -eq 0 -and $_.Type -eq "ether" } 

                        Write-Log "Re-IP is designed for static IP addresses. DHCP could have been used for one or more interfaces. Found $($unaddressednics.Count()) unassigned network interfaces for $($VM)."

                        else {
                            Write-Log "Error: Virtual Machine $($_vm.Name) does not contain any unassigned network interfaces."
                        }
                        
                    }

                }
                
            }
    }
    else {
            Write-Log "Error: Virtual Machine $($VM) has no network information available."
    }
} 

Export-ModuleMember -Function * -Variable *
