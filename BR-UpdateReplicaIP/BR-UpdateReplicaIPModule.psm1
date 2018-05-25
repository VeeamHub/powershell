# Johan Huttenga, 20180425

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
    param($config, $ostype)
    $result = @()
    
    $lines = $config.Split("`n")
    
    if ($ostype -eq "Linux") {
            $gw = $lines[0].Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)[2]
            for($i=1; $i -lt $lines.Count; $i++) {
                $l = $lines[$i]
                if ($l -like "*mtu*") {
                        if ($ifcfg -ne $null) { $result += $ifcfg }
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
            if ($ifcfg -ne $null) { $result += $ifcfg }
    }
    else {
            $ifcfg = $null
            for($i=0; $i -lt $lines.Count; $i++) {
                $l = $lines[$i]
                if (($l -like "*adapter*") -and !($l -like "*description*")) {
                        if ($ifcfg -ne $null) { $result += $ifcfg }
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
    $cred = ([Veeam.Backup.Core.CDbCredentials]::Get([System.Guid]::new($id))).Credentials
    if ($cred -eq $null) { 
        Write-Log "Error: Unable to query credential ($($cred)). Ensure it exists and this process is run with administrator permissions."
    }
    $decoded = [Veeam.Backup.Common.CStringCoder]::Decode($cred.EncryptedPassword, $true)
    $secpwd = ConvertTo-SecureString $decoded -AsPlainText $true
    return New-Object System.Management.Automation.PSCredential($cred.UserName, $secpwd)
}

function Add-VIConnection {
    param($Server, $Credential)

    $result = $null

    if ($Credential -eq $null) {
        Write-Log "Error: Cannot connect to $server as no credentials were specified."
        return
    }

    if (!($VIConnections.ContainsKey($Server)))
    {
            Write-Log "Connecting to $Server using credentials ($($Credential.UserName))."
            $VIConnections[$Server] = Connect-VIServer $Server -Credential $Credential
            if ($VIConnections[$Server] -eq $null) {
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
            if ($rule.TargetIp.Split(".")[$i] -eq "*") { $TargetIp = $pattern.Replace($TargetIp,$SourceIpAddress.Split(".")[$i],1) }
    }
    return $TargetIp
}

function Get-VMGuestNetworkInterface {
    param($vm, $GuestCredential)
    
    $scripttype = ""
    $scripttext = ""
    
    $ostype = "Linux" 
    $vm_os = $vm.Guest.OSFullName
    if ($vm_os -like "*Windows*") { $ostype = "Windows" }
    
    if ($ostype -eq "Linux") { 
            $scripttype = "Bash"
            $scripttext = "ip route | grep default && /sbin/ifconfig -a"
    }
    else { 
            $scripttype = "Bat" 
            $scripttext = "ipconfig /all"
    }
    
    Write-Log "Invoking script: $($scripttext)"
    $output = Invoke-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext
    Write-Log $output
    $result = Parse-InterfaceConfig -Config $output.ScriptOutput -OSType $ostype
    
    return $result
}



function Set-VMGuestNetworkInterface {
    param($vm, $interface, $ipaddress, $netmask, $gateway, $dns, $guestcredential)

    $scripttype = ""
    $scripttext = ""
    $ostype = "Linux" 
    $vm_os = $vm.Guest.OSFullName

    if ($vm_os -like "*CentOS*") { $ostype = "CentOS" }
    if ($vm_os -like "*Red Hat*") { $ostype = "RedHat" }
    if ($vm_os -like "*Windows*") { $ostype = "Windows" }
    if (($ostype -eq "CentOS") -or ($ostype = "RedHat")) { 
    $scripttype = "Bash"
    $scripttext = "more /etc/sysconfig/network-scripts/ifcfg-" + $interface
    Write-Log "Invoking script: $($scripttext)"
    $output = Invoke-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext
    Write-Log $output
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
    $scripttext += "' > /etc/sysconfig/network-scripts/ifcfg-$interface && service network restart"
    Write-Log "Invoking script: $($scripttext)"
    $output = Invoke-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext
    Write-Log $output

    if ($dns -ne $null) {
    $scripttext = "echo -e '"
    $scripttext += "nameserver $dns"
    $scripttext += "' > /etc/resolv.conf"
    Write-Log "Invoking script: $($scripttext)"
    $output = Invoke-VMScript -VM $vm.Name -GuestCredential $guestcredential -ScriptType $scripttype -ScriptText $scripttext
    Write-Log $output
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
    param ($Name, $SkipWaitForTools = $false, $SkipWaitForGuestDetails = $false)

    $vm = Get-VM -Name $Name
    
    if ($vm -eq $null) {
        Write-Log "Error: $($Name) does not exist or cannot be accessed."
        return
    }

    if (!($SkipWaitForTools)) {
            Write-Log "Waiting for $($Name) integration tools status (180 seconds max)..."
            $wait = 0
            $toolsstatus = $null
            try { $toolsstatus = ($vm = Get-VM -Name $Name | Get-View).Guest.ToolsStatus } catch { }
            while ((($toolsstatus -eq $null) -or ($toolsstatus -ne "toolsOk")) -and ($wait -lt 180)) {
                $wait = $wait +5;
                Sleep 5
                try { $vm = Get-VM -Name $Name } catch { }
                try { $toolsstatus = ($vm | Get-View).Guest.ToolsStatus } catch { }
                Write-Log "$($wait) : guest tools available : $($toolsstatus -eq "toolsOk")"
            }
    }
    if (!($SkipWaitForGuestDetails)) {
            Write-Log "Waiting for $($Name) integration tools data (180 seconds max)..."
            $wait = 0
            $os = $vm.Guest.OSFullName
            while ((($os -eq $null) -or ($os.Length -eq 0)) -and ($wait -lt 180)) {
                $wait = $wait +5;
                Sleep 5
                $vm = $vm = Get-VM -Name $Name
                $os = $vm.Guest.OSFullName
                Write-Log "$($wait) : guest data available : $($os -ne $null)"
            }
            if ($wait -eq 180) {
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
    Param($FailoverPlan)
    $foijs = $FailoverPlan.FailoverPlanObject
    $platform = $foijs[0].item.platform
    $replicationjobs = [Veeam.Backup.Core.CBackupJob]::GetByTypeAndPlatform([Veeam.Backup.Model.EDbJobType]::Replica, $platform, $false)

    $result = @()
    foreach ($j in $replicationjobs) {
            $roijs = $j.GetObjectsInJob()
            foreach($ro in $roijs) {
                foreach ($fo in $foijs)
                {
                        if ($ro.Location -like $fo.Item.Path)
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
                                    if ($j.VssOptions.LinCredsId -ne [System.Guid]::Empty) { $rcreds = $j.VssOptions.LinCredsId }
                                    if ($j.VssOptions.WinCredsId -ne [System.Guid]::Empty) { $rcreds = $j.VssOptions.WinCredsId }
                                    $rcreds = Get-VBRCredential -Id $rcreds
                          }
                            if ($j.TargetHostId) {
                                    $replicatarget = [Veeam.Backup.Core.Common.CHost]::Get([System.Guid]::new($j.TargetHostId))
                                    $rtparentci = $replicatarget.GetSoapConnHostInfo()
                                    $rtparentcreds = (([Veeam.Backup.Core.Common.CHost]::Get([System.Guid]::new($rtparentci.Id))).GetSoapCreds()).CredsId
                                    $rtparentcreds = Get-VBRCredential -Id $rtparentcreds
                            }
                            $p = @{
                                    'SourceName'=$ro.Name
                                    'Platform'=$platform
                                    'Path'=$ro.Location
                                    'PlanName'=$fo.Name
                                    'PlanId'=$fo.Id
                                    'PlanOijId'=$fo.Item.Id
                                    'JobName'=$j.Name
                                    'JobId'=$j.Id
                                    'JobOijId'=$ro.Id
                                    'ReplicaName'=$rprefix + $ro.Name + $rsuffix
                                    'TargetHostId'=$j.TargetHostId
                                    'TargetParentConnectionInfo'=$rtparentci
                                    'TargetParentCredential'=$rtparentcreds
                                    'TargetOptions'= $replicatoptions
                                    'ReipRules'=$reiprules
                                    'GuestCredential'=$rcreds
                            }
                            Write-Log ("$($fo.Item.Name) ($($fo.Item.Path)) is associated with " + $j.Name + ".")
                            $result += New-Object -TypeName PSObject -Prop $p
                        }
                }
            }
    }
    return $result
}

function Update-VMIPAddresses {
    param ($VM, $ReIpRules, $GuestCredential)

    $_vm = Get-VM -Name $VM

    $nics = $null
    if ($_vm -ne $null) {
        $nics = Get-VMGuestNetworkInterface -VM $_vm -GuestCredential $GuestCredential
    }
    else {
        Write-Log "Error: Virtual Machine $($VM) is unavailable. Check parent server connections and permissions."
        return
    }

    if ($nics -ne $null) {

            if ($_vm.Guest.OSFullName -like "*Windows*") {
                Write-Log "Skipped: $($VM) has the following network configuration:`n$($nics)"
                foreach($iface in $nics) { Write-Log "  $($iface.Name) ($($iface.Mac)), $($iface.Ipv4), Subnet: $($iface.Subnet)" }
            }
            else {

                Write-Log "$($VM) has the following network configuration:"
                foreach($iface in $nics) { Write-Log "  $($iface.Name) ($($iface.Mac)), $($iface.Ipv4), Subnet: $($iface.Subnet)" }
                Write-Log "`r$($VM) will have the following re-ip rules applied:"
                foreach($rule in $ReIpRules) { Write-Log "  Source: $($rule.SourceIp), Target: $($rule.TargetIP), Subnet: $($rule.TargetSubnet), Gateway: $($rule.TargetGateway)" }
    
                foreach($rule in $ReIpRules)
                {
                        $matched = $false
                        foreach($iface in ($nics | ?{ $_.Ipv4 -like $rule.SourceIp })) {
                            
                            $matched = $true
                            $srcip = $iface.Ipv4; 
                            $trgip = Apply-VMReIpRule -SourceIpAddress $srcip -ReIpRule $rule

                            Write-Log "Processing: Virtual Machine $($_vm.Name) interface: $($iface.Name), source: $srcip, target: $trgip"
                            Set-VMGuestNetworkInterface -VM $_vm -Interface $iface.Name -IPAddress $trgip -Netmask $rule.TargetSubnet -Gateway $rule.TargetGateway -DNS $rule.TargetDns -GuestCredential ($GuestCredential)
                            
                            $cnics = Get-VMGuestNetworkInterface -VM $_vm -GuestCredential ($GuestCredential) | ?{ $_.Name -like $iface.Name }
                            
                            if (($cnics -ne $null) -and ($cnics.Ipv4 -eq $trgip)) { Write-Log "Success: Virtual Machine $($_vm.Name) interface $($cnics.Name) ($($cnics.Mac)) updated to $($cnics.Ipv4)" }
                            elseif ($cnics -ne $null) { 
                                Write-Log "Failed: $($VM) has the following network configuration:"
                                foreach($iface in $nics) { Write-Log "  $($iface.Name) ($($iface.Mac)), $($iface.Ipv4), Subnet: $($iface.Subnet)" }
                            }
                            else { Write-Log "Error: Virtual Machine $($_vm.Name) network configuration does not contain interface $($cnics.Name)." }
                            
                        }
                        if (!$matched) {
                            Write-Log "Warning: Virtual Machine $($_vm.Name) does not contain network interfaces matching $($rule.SourceIp)"
                        }
                }
                
            }
    }
    else {
            Write-Log "Error: Virtual Machine $($VM) has no network information available."
    }
} 

Export-ModuleMember -Function * -Variable *