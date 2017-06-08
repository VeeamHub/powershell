<#
#on remote make sure remoting is enabled, should be ok by default on 2012 R2 and up if firewall is off
Enable-PSRemoting

#on local, make sure you thrust target
winrm set winrm/config/client '@{TrustedHosts="192.168.1.*"}'



$credentials = (Get-Credential -UserName "administrator" -Message "Credentials to deploy")
$server = "192.168.1.146"

$basepath = [environment]::getfolderpath("Desktop”)
$binary = ("{0}\{1}" -f $basepath,"VeeamAgentWindows_2.0.0.700.exe")
$license = ("{0}\{1}" -f $basepath,"veeam_agent_windows_nfr_2.lic")
$md5 = ("{0}\{1}" -f $basepath,"VeeamAgentWindows_2.0.0.700.exe.md5")
$installhelper = ("{0}\{1}" -f $basepath,"vawinstallhelper.exe")

#getting the config from the local installation
$localconfig = Get-VeeamHubWindowsAgentConfig -session (New-PSSession -ComputerName "localhost")
$xmlstring = ""
if ($localconfig -ne $null -and $localconfig.config -ne $null) {
    $xmlobj = [xml]$localconfig.config
    $xmlobj.ExecutionResult.Data.JobInfo.RetentionInfo.RestorePointsCount = "7"
    $xmlobj.ExecutionResult.Data.JobInfo.ScheduleInfo.DailyInfo.Time = ([datetime]($xmlobj.ExecutionResult.Data.JobInfo.ScheduleInfo.DailyInfo.Time)).AddHours(1).ToString("MM/dd/yyyy HH:mm:ss")
    $xmlstring = $xmlobj.OuterXml
}

Publish-VeeamHubWindowsAgent -credentials $credentials -server $server -binary $binary -license $license -md5 $md5 -progressbar $true -verbose -installhelper $installhelper -rebootonfirstfail $true -xmlstring $xmlstring


#>

<#
    Helper Function. Allows you to remotely verify a checksum of a file, on success it returns the hash
#>
function Get-VeeamHubRemoteFileMD5 {
    #thanks http://stackoverflow.com/questions/10521061/how-to-get-an-md5-checksum-in-powershell
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][System.Management.Automation.Runspaces.PSSession]$session,
            [Parameter(Mandatory=$true)][string]$remotepath)
    if ($session.State -eq "Opened") {
        $testremotefile = Invoke-Command  -Session $session -ScriptBlock { param($vars); test-path -PathType Leaf $vars.path } -ArgumentList @{path=$remotepath} 
        if ($testremotefile) {
            $md5 = Invoke-Command  -Session $session -ScriptBlock { 
                param($vars); 
                $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
                $utf8 = new-object -TypeName System.Text.UTF8Encoding
                $reader = [System.IO.File]::Open($vars.path ,[System.IO.Filemode]::Open, [System.IO.FileAccess]::Read)
                $hash = [System.BitConverter]::ToString($md5.ComputeHash($reader))
                $reader.Close()
                return $hash

           } -ArgumentList @{path=$remotepath} 
           return ($md5 -replace "-","")
        } else {
            Write-Error "Remote file $remotepath does not exist"
        }
    } else {
        Write-Error "Connection not open"
    }
    return 0
    



}
<#
    Helper Function. Copies a remote file over powershell (localfile to remotepah). Forceifexists forces an overwrite which probably doesn't make sense. If you use smalltextfile, the value is just passed in one time
#>
function Copy-VeeamHubRemoteFile {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][System.Management.Automation.Runspaces.PSSession]$session,
            [boolean]$smalltextfile=$false,
            [Parameter(Mandatory=$true)][string]$remotepath,
            [Parameter(Mandatory=$true)][string]$localfile,
            [boolean]$forceifexists=$false,
            [boolean]$progressbar=$false)
    if ($session.State -eq "Opened") {
        $testremotedir = Invoke-Command  -Session $session -ScriptBlock { param($vars); test-path -PathType Container $vars.path } -ArgumentList @{path=$remotepath} 
        if ($testremotedir) {
            if (Test-Path -PathType Leaf $localfile) {
                $remotefilepath = ("{0}\{1}" -f $remotepath,(Split-Path -Path $localfile -Leaf))

                
                $testremotefile = Invoke-Command  -Session $session -ScriptBlock { param($vars); test-path -PathType Leaf $vars.path } -ArgumentList @{path=$remotefilepath} 

                if (-not $testremotefile -or $forceifexists) {
                
                     Write-Verbose "Uploading $localfile"
                    if($smalltextfile) {
                      
                        $content = Get-Content $localfile

                        Invoke-Command -Session $session -ScriptBlock { param($vars); $vars.content | out-file -filepath $vars.remotefilepath } -ArgumentList @{content=$content;remotefilepath=$remotefilepath} 

                        return $remotefilepath
                    } else {
                        $readsize = 1024kb
                        $buffer = New-Object byte[]($readsize)

                        $totalsize = [int](get-item $localfile).Length

                        $stream = [IO.File]::OpenRead($localfile)
                        $count = 0
                        
                        Write-verbose "Need to transfer $totalsize"

                        if ($progressbar) {
                            Write-Progress -Activity "Uploading $localfile"  -PercentComplete 0
                        }
                        Invoke-Command -Session $session -ScriptBlock { param($vars); $writer = [IO.File]::OpenWrite($vars.remotefilepath) } -ArgumentList @{remotefilepath=$remotefilepath} 
                        for ($r = $stream.Read($buffer,0,$readsize); $r -gt 0; $r = $stream.Read($buffer,0,$readsize)) {
                            Invoke-Command -Session $session -ScriptBlock { param($vars); $writer.Write($vars.block,0,$vars.size) } -ArgumentList @{block=$buffer;size=$r} 
                            
                            #Write-verbose ("Transferred {0}" -f $r)
                            if ($progressbar) { Write-Progress -Activity "Uploading $localfile" -PercentComplete (($count/$totalsize)*100) }
                            $count += $r
                        }
                        if ($progressbar) { Write-Progress -Activity  "Uploading $localfile" -Completed }
                        Write-verbose ("Transferred Total {0}" -f (($count)))
                        Invoke-Command -Session $session -ScriptBlock { param($vars); $writer.Close()}
                        $stream.Close()
                        return $remotefilepath
                    } 
                } else {
                    write-verbose ("File $remotefilepath already exists and not force copying (-forceifexists `$false)")
                    return $remotefilepath
                }
               
            } else {
                Write-Error "Local file $localfile does not exit"
            }
        } else {
            Write-Error "Remote dir $remotepath does not exist"
        }
    }else {
        Write-Error "Connection not open"
    }
    return 0
}
<#
    Helper Function. Should return the default export path
#>
function Get-VeeamHubWindowsAgentDefaultConfigPath {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][System.Management.Automation.Runspaces.PSSession]$session
    )
    $configpath = ""
    if ($session.State -eq "Opened") {
      $configpath = invoke-command -Session $session -ScriptBlock { 
        $configpath = ""
        try {
            $configpath =  ("{0}\!Configuration\Config.xml" -f (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup' -Name LogDirectory).LogDirectory)                    
        } catch {
            return ""
        }
        return $configpath
      }
    } else {
        write-error "Connection not opened"
    }
    return $configpath
}
<#
    Helper Function. Find the config path
#>
function Get-VeeamHubWindowsAgentConfigTool {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][System.Management.Automation.Runspaces.PSSession]$session
    )
    $configtool = ""
    if ($session.State -eq "Opened") {
      $configtool = invoke-command -Session $session -ScriptBlock { 
        $configtool = ""
        try {
                                
            $installdir = (Get-ItemProperty 'HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup' -Name installdir).installdir 
            if ($installdir -match "Veeam") {
                $configtoolp = "$installdir\Veeam.Agent.Configurator.exe"
                if (Test-Path -Path $configtoolp) {
                    $configtool = $configtoolp
                }
            }
        } catch {
            return ""
        }
        return $configtool
      }
    } else {
        write-error "Connection not opened"
    }
    return $configtool
}

<#
    1) Start by copying the binary and the license file. Does verification of the md5
#>

function Copy-VeeamHubWindowsAgentFiles {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][System.Management.Automation.Runspaces.PSSession]$session,
        [Parameter(Mandatory=$true)][string]$binary,
        [Parameter(Mandatory=$true)][string]$installhelper,
        [Parameter(Mandatory=$true)][string]$license,
        [Parameter(Mandatory=$true)][string]$md5,
        [boolean]$progressbar=$false)

    $result = New-Object -TypeName psobject -ArgumentList @{Success=$false;RemoteBinary="";RemoteLicense=""}
    if ($session.State -eq "Opened") {
        if ( (Test-Path $binary) -and (Test-Path $license) -and (Test-Path $md5)) {
            $remotepath = ("{0}\VeeamHubWindowsAgentDeploy" -f (Invoke-Command -Session $session -ScriptBlock { [environment]::getfolderpath("ApplicationData”) }))
            try {
                $mkdir = Invoke-Command -Session $session -ScriptBlock { param($vars); New-Item -ItemType Directory -Path $vars.path } -ArgumentList @{path=$remotepath} -ErrorAction SilentlyContinue
            } catch { }
            $remotelic = Copy-VeeamHubRemoteFile -session $session -smalltextfile $true -remotepath $remotepath -localfile $license -progressbar $progressbar
            $remotebin = Copy-VeeamHubRemoteFile -session $session -smalltextfile $false -remotepath $remotepath -localfile $binary -progressbar $progressbar
            $remoteinstallhelper = Copy-VeeamHubRemoteFile -session $session -smalltextfile $false -remotepath $remotepath -localfile $installhelper -progressbar $progressbar

            $md5check = Get-VeeamHubRemoteFileMD5 -session $session -remotepath $remotebin
            $origmd5 = (Get-Content $md5) | ? { $_ -imatch ("([a-z0-9]+)[^\\s]+{0}$" -f (Split-Path -Leaf $binary)) }  | % { $Matches[1].ToString() }

            if ($md5check -ne 0 -and $origmd5) {
                write-verbose "Check $md5check vs $origmd5"
                $origmd5 = $origmd5.ToUpper(); $md5check = $md5check.ToUpper()
                if ($origmd5 -eq $md5check) {
                    $filename =  (Split-Path $remotebin -Leaf)
                    $result.Success = $true;
                    $result.RemoteBinary = $remotebin;
                    $result.RemoteLicense = $remotelic;
                    $result.RemoteInstallhelper = $remoteinstallhelper;
                    Write-Verbose "Remote binary and licenses uploaded"

                } else {
                    Write-error "Remote binary failed checksum"
                }
            } else {
                write-error "Did not get remote checksum ($md5check)? or did not find localmd5 ($origmd5)?"
            }

        } else {
            Write-Error "Some file do not exist"
        }
    } else {
        Write-Error "Connection not open"
    }

    return $result
}
<#
    Start NDP452-KB2901907-x86-x64-AllOS-ENU.exe  /?
    Find under c:\{hash} the msu package that matches your system
    Extract cab via wusa x64-Windows8.1-KB2934520-x64.msu /extract:.
    Use cab for upload
#>
function Copy-VeeamHubDotNet452 {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][System.Management.Automation.Runspaces.PSSession]$session,
        [Parameter(Mandatory=$true)][string]$cab,
        [boolean]$progressbar=$false)
    $result = New-Object -TypeName psobject -ArgumentList @{Success=$false;RemoteCab=""}
    if ($session.State -eq "Opened") {
        if ((Test-Path $cab)) {
            $remotepath = ("{0}\VeeamHubDotNet" -f (Invoke-Command -Session $session -ScriptBlock { [environment]::getfolderpath("ApplicationData”) }))
            try {
                $mkdir = Invoke-Command -Session $session -ScriptBlock { param($vars); New-Item -ItemType Directory -Path $vars.path } -ArgumentList @{path=$remotepath} -ErrorAction SilentlyContinue
            } catch { }
                
            $remotecab = Copy-VeeamHubRemoteFile -session $session -smalltextfile $false -remotepath $remotepath -localfile $cab -progressbar $progressbar
            if ($remotecab -ne 0) {
                $result.Success = $true
                $result.RemoteCab = $remotecab
            }
            } else {
            Write-Error "Some file do not exist"
        }
    } else {
        Write-Error "Connection not open"
    }

    return $result
}
function Install-VeeamHubDotNet452 {
     [CmdletBinding()]
    param([Parameter(Mandatory=$true)][System.Management.Automation.Runspaces.PSSession]$session,
        [Parameter(Mandatory=$true)][string]$RemoteCab,
        [boolean]$progressbar=$false)  
        
    $installresult = New-Object -TypeName psobject -ArgumentList @{Success=$false}
    if ($session.State -eq "Opened") {
        
        $testRemoteCab = [boolean](invoke-command -Session $session -ScriptBlock { param($vars) ; return (test-path -Path $vars.file -PathType Leaf) } -ArgumentList @{file=$RemoteCab})
        if ($testRemoteCab) { 
                    Write-Verbose "Remote binary is ok, installing"
                    Invoke-Command -Session $session -ScriptBlock { param($vars);
                         $basepath = Split-Path -Path $vars.path -Parent
                         #$argsdism =  ("/online /add-package /PackagePath:{0} /NoRestart /Quite /LogPath {1}" -f $vars.path,$basepath)
                         $res = & dism.exe "/online" "/add-package" "/NoRestart" "/Quiet" ("/PackagePath:`"{0}`"" -f $vars.path)  ("/LogPath:`"{0}\dismlog.txt`"" -f $basepath)
                    } -ArgumentList @{path=$RemoteCab} 
        } else {
            Write-Error "Make sure $RemoteCab exist"
        }
    } else {
        Write-Error "Connection not open"
    }
    return $installresult
}

function Get-VeeamHubDotNet4Version {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][System.Management.Automation.Runspaces.PSSession]$session)
    if ($session.State -eq "Opened") {
        Invoke-Command -Session $session -ScriptBlock { 
            $v = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue)
            if ($v) { return $v.Release }
            return 0
        }
    }
}
<#
    2) Silent install of the agent (reboot might still be required) 
#>
function Install-VeeamHubWindowsAgent {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][System.Management.Automation.Runspaces.PSSession]$session,
        [Parameter(Mandatory=$true)][string]$RemoteBinary,
        [Parameter(Mandatory=$true)][string]$RemoteInstallHelper,
        [boolean]$nofailondotnet=$false,
        [boolean]$progressbar=$false)

    $installresult = New-Object -TypeName psobject -ArgumentList @{Success=$false;Mightneedreboot=$false}

    if ($session.State -eq "Opened") {
        
        $testbinary = [boolean](invoke-command -Session $session -ScriptBlock { param($vars) ; return (test-path -Path $vars.file -PathType Leaf) } -ArgumentList @{file=$RemoteBinary})
        if ($testbinary) {
                    $filename =  (Split-Path $RemoteInstallHelper -Leaf)

                    Write-Verbose "Remote binary is ok, installing"
                    Invoke-Command -Session $session -ScriptBlock { param($vars);
                         $exec = $vars.path
                         $ih = $vars.ih
                         Start-Process -FilePath $ih -ArgumentList @("mkregkey",$exec) -Wait
                         Start-Process -FilePath $ih -ArgumentList @("deploy")

                    } -ArgumentList @{path=$RemoteBinary;ih=$RemoteInstallHelper} 
                    
                    $waiting = $true
                    $timeout = 60*15
                    $preset = 60
                    $current = 0

                    $pname = ($filename -replace ".exe")
                    if ($progressbar) { Write-Progress -Activity "Waiting for $pname to close"  -PercentComplete 0}
                    while($waiting -and $current -lt $timeout) {
                        Start-Sleep -Seconds 5
                        $waiting = Invoke-Command -Session $session -ScriptBlock { param($vars);
                            $p = @(Get-Process | ? { $_.ProcessName -match $vars.pname})
                            return ($p.Count -gt 0) 

                        } -ArgumentList @{pname=$pname}
                        #Write-Verbose "Process $pname is still alive"
                        if ($progressbar) { Write-Progress -Activity "Waiting for $pname to close"  -PercentComplete ((($current/$preset)*100)%100) }
                        $current = $current + 5
                    }
                    Start-Sleep -Seconds 5

                    if ($timeout -ne $current ) {
                        if ($progressbar) { Write-Progress -Activity "Waiting for $pname to close"  -completed }

                        $gotinstalled = Invoke-Command -Session $session -ScriptBlock {
                            $installed = $false
                            $installdir = (Get-ItemProperty 'HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup' -Name Installdir -ErrorAction SilentlyContinue)
                            if ($installdir -ne $null) {
                                $installdir = $installdir.Installdir
                                $installed = (test-path -path ("{0}\Veeam.EndPoint.Backup.exe" -f $installdir))
                            }
                            return $installed
                        }

                        if ($gotinstalled) {
                            write-verbose "Found exe in installdir = $gotinstalled"
                            $waiting = $true
                            $timeout = 60*15
                            $preset = 60
                            $current = 0

                            if ($progressbar) { Write-Progress -Activity "Waiting for service to start"  -PercentComplete 0 }
                            while($waiting -and $current -lt $timeout) {
                                $running = Invoke-Command -Session $session -ScriptBlock { param($vars);
                                    try {
                                        $r = Get-Service | ? { $_.Name -match "Veeam" } | % { $_.Status -eq "Running" }
                                        return $r
                                    } catch {
                                        return $false
                                    }
                                    return $false

                                } -ArgumentList @{}
                                if ($running) { $waiting = $false }

                                #Write-Verbose "Process $pname is still alive"
                                if ($progressbar) { Write-Progress -Activity "Waiting for service to start"  -PercentComplete ((($current/$preset)*100)%100) }
                                $current = $current + 5
                                if($waiting) {
                                    Start-Sleep -Seconds 5
                                }
                            }
                            if ($progressbar) { Write-Progress -Activity "Waiting for service to start" -Completed }

                            if ($timeout -ne $current ) {
                                $installresult.Success = $true
                                write-verbose "Service started"
                                
                            } else {
                                Write-Error "Service not found or not started in fashionable time"
                            }  
                        } else {
                            if ( -not $nofailondotnet) {
                                Write-Error "Endpoint not installed, you might need to reboot the machine to install dotnet 452"
                            } else {
                                $installresult.Mightneedreboot = $true
                            }
                        }
                    } else {
                        write-error "Timeout install"
                    }
        } else {
            Write-Error "Make sure $RemoteBinary exist"
        }
    } else {
        Write-Error "Connection not open"
    }
    return $installresult
}
<#
    3) License the agent (consider the license already to be present locally)
#>
function Set-VeeamHubWindowsAgentLicense {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][System.Management.Automation.Runspaces.PSSession]$session,
        [Parameter(Mandatory=$true)][string]$RemoteLicense,
        [boolean]$progressbar=$false)
    $result = New-Object -TypeName psobject -ArgumentList @{Success=$false;Error="";Message="";Ran=""}
    if ($session.State -eq "Opened") {
        $testlic = [boolean](invoke-command -Session $session -ScriptBlock { param($vars) ; return (test-path -Path $vars.file -PathType Leaf) } -ArgumentList @{file=$RemoteLicense})
        if ($testlic) {
            $configtool = Get-VeeamHubWindowsAgentConfigTool -session $session
            if ($configtool -ne "") {
                Write-Verbose "Detected $configtool, installing license"

                $result = Invoke-Command -Session $session -ScriptBlock { 
                                param($vars);
                                $res = New-Object -TypeName psobject -ArgumentList @{Success=$false;Error="";Message="";Ran=""}
                                $ct = $vars.configtool
                                $lp = ("/f:`"{0}`"" -f $vars.license)
                                try {
                                        $exec = & $ct -license $lp
                                        $res.Ran = "$ct -license $lp"
                                        $res.Message = $exec
                                        if ($exec -match "ExitCode:[\s]+0" ) 
                                        {
                                                $res.Success = $true
                                                $res.Message = ""
                                        } 
                                        else {
                                            $res.Error = ("ExecutionResult Exitcode does not equal 0, check Message")
                                        }
                                } catch {
                                    $res.Error = ("Remote Issue : {0}" -f $Error[0])
                                    $res.Success = $false
                                }
                                return  $res

                } -ArgumentList @{configtool=$configtool;license=$RemoteLicense}
                if ($result.Message -ne "") {           
                        write-verbose ("Failed with error {0} ({1})" -f $result.Message,$result.Ran)
                }

            } else {
                Write-Error "Could not find config tool"
                $result.Error = "Could not find config tool"
            }
        } else {
            Write-Error "Make sure $RemoteLicense exist"
            $result.Error = "Make sure $RemoteLicense exist"
        }
    } else {
        Write-Error "Connection not open"
        $result.Error = "Connection not open"
    }
    return $result

}
<#
    4) Set the config by supplying an xml
#>
function Set-VeeamHubWindowsAgentConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][System.Management.Automation.Runspaces.PSSession]$session,
        [Parameter(Mandatory=$true)][String]$xmlstring
    )
    
    $result = New-Object -TypeName psobject -ArgumentList @{Success=$false;Error="";Message="";Ran=""}
    if ($session.State -eq "Opened") {
            $configtool = Get-VeeamHubWindowsAgentConfigTool -session $session
            $configpath = Get-VeeamHubWindowsAgentDefaultConfigPath -session $session

            if ($configtool -ne "" -and $configpath -ne "") {
                $result = Invoke-Command -Session $session -ScriptBlock { 
                                param($vars);
                                $res = New-Object -TypeName psobject -ArgumentList @{Success=$false;Error="";Message="";Ran=""}
                                $configtool = $vars.configtool
                                $configpath = $vars.configpath
                                try {
                                        $configdir = Split-Path -parent $configpath 
                                        $null = New-Item $configdir -ItemType Directory -ErrorAction SilentlyContinue

                                        $vars.xmlstring | Set-Content -Path $configpath

                                        $exec = & $configtool "-import"
                                        $res.Ran = "$configtool -import"
                                        $res.Message = $exec
                                        if ($exec -match "ExitCode:[\s]+0") {
                                            $res.Success = $true          
                                        } 

                                } catch {
                                    $res.Error = ("Something went wrong {0}" -f $Error[0])
                               
                                }
                                return  $res

                } -ArgumentList @{configtool=$configtool;configpath=$configpath;xmlstring=$xmlstring}
                if (-not $result.Success) {
                    write-error ("Remote error : {0} | Export Result : {1}" -f $result.Error,$result.Message)
                }
            } else {
                Write-Error "No config tool found ($configtool) or could not determine default config path ($configpath)"
            }
    } else {
        write-error "Connection not opened"
    }
    return $result
}
<#
    5) Get the config. Can not be done on initial install
#>
function Get-VeeamHubWindowsAgentConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][System.Management.Automation.Runspaces.PSSession]$session
    )
    $result = New-Object -TypeName psobject -ArgumentList @{Success=$false;Config="";Error="";Message="";Ran=""}
    if ($session.State -eq "Opened") {
            $configtool = Get-VeeamHubWindowsAgentConfigTool -session $session
            $configpath = Get-VeeamHubWindowsAgentDefaultConfigPath -session $session

            if ($configtool -ne "" -and $configpath -ne "") {
                $result = Invoke-Command -Session $session -ScriptBlock { 
                                param($vars);
                                $res = New-Object -TypeName psobject -ArgumentList @{Success=$false;Error="";Config="";Message="";Ran=""}
                                $configtool = $vars.configtool
                                $configpath = $vars.configpath
                                try {
                                        $execres = & $configtool "-export"
                                        $res.Ran = "$configtool -export"
                                        if ($execres -ne "") { $res.Message = $execres }
                                        

                                        
                                        $testexport = (test-path -Path $configpath -PathType Leaf) 
                                        if ($testexport) {
                                                
                                                $res.Config = Get-Content -Path $configpath 
                                                if (([xml]$res.Config).ExecutionResult.ExitCode -eq 0) {
                                                    $res.Success = $true  
                                                } else {
                                                    $res.Error = ("Export happened but result is not ok, did you already configured this node?")
                                                }    
                                            
                                        } else {
                                            $res.Error =  ("Could not find export on {0}" -f $configpath)
                                        }

                                        
                                } catch {
                                    $res.Error = ("Something went wrong {0}" -f $Error[0])                        
                                }
                                return  $res

                } -ArgumentList @{configtool=$configtool;configpath=$configpath}
                if (-not $result.Success) {
                    write-error ("Remote error : {0} | Export Result : {1}" -f $result.Error,$result.Message)
                }
            } else {
                Write-Error "No config tool found ($configtool) or could not determine default config path ($configpath)"
            }
    } else {
        write-error "Connection not opened"
    }
    return $result
}



function Publish-VeeamHubWindowsAgent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$binary,
        [Parameter(Mandatory=$true)][string]$installhelper,
        [Parameter(Mandatory=$true)][string]$license,
        [Parameter(Mandatory=$true)][string]$md5,
        [Parameter(Mandatory=$true)][string]$server,
        [boolean]$rebootonfirstfail=$false,
        [System.Management.Automation.PSCredential]$credentials,
        [string]$xmlstring="",
        [boolean]$progressbar=$false)

    $session = $null
    if ($credentials -ne $null ) {
        $session = New-PSSession -ComputerName $server -Credential $credentials -Authentication Negotiate
    } else {
        $session = New-PSSession -ComputerName $server 
    }

    if ($session -ne $null -and $session.State -eq "Opened") {
       
        $waresult = Copy-VeeamHubWindowsAgentFiles -session $session -binary $binary -license $license -md5 $md5 -installhelper $installhelper -Verbose -progressbar $progressbar
        if($waresult.success) {
            Write-Verbose "Succesfull copy"
            $iaresult = Install-VeeamHubWindowsAgent -session $session -Verbose  -RemoteBinary $waresult.RemoteBinary -RemoteInstallHelper $waresult.remoteinstallhelper -progressbar $progressbar -nofailondotnet $rebootonfirstfail
           
            #if reboot is required and reboot is allowed, reboot it and try to redeploy after reboot           
            if ( -not $iaresult.success -and $iaresult.Mightneedreboot -and $rebootonfirstfail) {
                Invoke-Command -Session $session -ScriptBlock {  shutdown /r /t 0 /d 4:2 }
                Write-verbose "Rebooted the host, sleeping for 30 seconds on minimum"
                Start-Sleep -Seconds 30
                
                $hammertime = (Get-Date).AddSeconds(300)
                $session = $null
                while ($session -eq $null -and (get-date) -lt $hammertime) {
                    Write-Verbose "Trying to reconnect.."

                    if ($credentials -ne $null ) {
                        $session = New-PSSession -ComputerName $server -Credential $credentials -Authentication Negotiate -ErrorAction SilentlyContinue
                    } else {
                        $session = New-PSSession -ComputerName $server -ErrorAction SilentlyContinue
                    }
                    if ($session -eq $null) {
                        Write-Verbose "Failed, sleeping 5 seconds"
                        start-sleep -Seconds 5     
                                     
                    }
                }
                if($session -eq $null) {
                    Write-Error "Could not reconnect"
                    return -1
                } else {
                    $iaresult = Install-VeeamHubWindowsAgent -session $session -Verbose  -RemoteBinary $waresult.RemoteBinary -RemoteInstallHelper $waresult.remoteinstallhelper -progressbar $progressbar
                }

            }


            if ($iaresult.success) {
                Write-Verbose "Succesfull install"
                $lrresult = Set-VeeamHubWindowsAgentLicense -session $session -Verbose -RemoteLicense $waresult.RemoteLicense
                if ($xmlstring -ne "") {
                    $setresult = Set-VeeamHubWindowsAgentConfig -session $session -xmlstring $xmlstring
                    if($setresult.Success) {
                        Write-Verbose "Config applied succesfully"
                    }
                }
            } 
        } else {
            Write-Verbose "Something went wrong during uploading, not continuing"
        }
        
        Remove-PSSession -Session $session
    } else {
        Write-Verbose "Session not opened"
    }
}

Export-ModuleMember -Function Publish-VeeamHubWindowsAgent
Export-ModuleMember -Function Copy-VeeamHubWindowsAgentFiles
Export-ModuleMember -Function Install-VeeamHubWindowsAgent
Export-ModuleMember -Function Set-VeeamHubWindowsAgentLicense
Export-ModuleMember -Function Set-VeeamHubWindowsAgentConfig
Export-ModuleMember -Function Get-VeeamHubWindowsAgentConfig

<#Dotnet Helper functions#>
Export-ModuleMember -Function Copy-VeeamHubDotNet452
Export-ModuleMember -Function Install-VeeamHubDotNet452
Export-ModuleMember -Function Get-VeeamHubDotNet4Version

<#Helper functions#>
Export-ModuleMember -Function Get-VeeamHubRemoteFileMD5
Export-ModuleMember -Function Copy-VeeamHubRemoteFile
Export-ModuleMember -Function Copy-VeeamHubRemoteFile
Export-ModuleMember -Function Get-VeeamHubWindowsAgentConfigTool






