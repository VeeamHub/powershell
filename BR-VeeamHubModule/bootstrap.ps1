
$versionurl = "http://dewin.me/veeamhubmodule/version.json"

$installversion = $null
$installmode = $null


$veeamhubmodulename = "VeeamHubModule"

function ln {
    write-host (,'#'*80 -join "")
}
clear-host

write-host "Welcome to the VeeamHub Module Bootstrap Installer"
ln

$allowfire = $false
write-host @"
Copyright (c) 2018 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@
ln
write-host "Before we continue, please take notice that this module is released under MIT License"
write-host "Basically, this module is released in an opensource module, but we do not take any responsibility in any case"
write-host "Do you agree to this before installing?"
$acceptcheck = read-host "Write yes to confirm "
if ($acceptcheck.ToLower().Trim() -eq "yes") {
    $allowfire = $true
} else {
    write-error "You didn't agree, refusing to continue"
}
ln

function Install-VeeamHubWebFile {
    param($url,$dest,$fixnl=$false)
    
    if ($url -ne $null -and $dest -ne $null) {
        $fdest = (Join-Path $dest -ChildPath (Split-Path $url -Leaf))
        write-host "Downloading $url `r`n   > $fdest"
        if(-not $fixnl) {
            Invoke-WebRequest -Uri $url -OutFile $fdest
        } else {
            Invoke-WebRequest -Uri $url -OutFile "$fdest.tmp"
            (Get-Content "$fdest.tmp") -replace "`r(?!`n)","`r`n" | Set-Content $fdest
        }
        
    }
}

if ($allowfire) {
    write-host "Fetching version"
    $r = Invoke-WebRequest $versionurl
    if ($r.StatusCode -eq 200) {
        $versions = $r.Content | ConvertFrom-Json
        if ($versions -ne $null -and $versions.stable -ne $null -and $versions.baseurl -ne $null) {
            $baseurl = $versions.baseurl
            #Ask for version
            while($installversion -eq $null) {
                write-host "Which version do you want to install?"
                $answerversion = (read-host "stable (default) / latest / <version> / list").ToLower().trim()
                if ($answerversion -eq "") {
                    $installversion = $versions.stable
                } elseif ($answerversion -eq "stable") {
                    $installversion = $versions.stable
                } elseif ($answerversion -eq "latest") {
                    $installversion = $versions.latest
                } elseif ($answerversion -match "^([0-9]+\.?)+$") {
                    $installversion = $versions.all | ? { $_.version -eq $answerversion }
                } elseif ($answerversion -eq "list") {
                    ln
                    $versions.all | % { write-host ("{0:6} - {1}" -f $_.version,$_.description )}
                    ln
                }
            }
            write-host ("Installing {0:6} - {1}" -f $installversion.version,$installversion.description )
            ln
            while($installmode -eq $null) {
                write-host "Do you want to install for this user, or for all users?"
                $answermode = (read-host "user (default) / all (need to be admin)").ToLower().Trim()
                if ($answermode -in "user","all") {
                    $installmode = $answermode
                } elseif($answermode -eq "") {
                    $installmode = "user"
                }
            }
            write-host ("Installing for {0}" -f $installmode)
            ln
            $pspaths = $env:PSModulePath -split ";" 
            $installbase = $null
            

            if ($installmode -eq "all") {
                $installbase = $pspaths | ? { $_ -match  $env:SystemRoot.Replace("\","\\") }
            } elseif ($installmode -eq "user") {
                $installbase = $pspaths | ? { $_ -match  $env:USERPROFILE.Replace("\","\\") }
            }

            if ($installbase -ne $null -and $installbase.Trim() -ne "") {
                $installbase = (join-path $installbase -ChildPath $veeamhubmodulename)

                if( -not (Test-Path $installbase)) {
                    New-Item -Path $installbase -ItemType  Directory -ErrorAction SilentlyContinue | out-null
                }

                if( Test-Path $installbase ) {
                    write-host "Installing in $installbase"
                    $alreadyinstalled = @(Get-childItem $installbase).count
                    $canoverwrite = $false
                    if ($alreadyinstalled -gt 0) {
                        write-host "Seems there is already a version installed, do you want to overwrite?"
                        $answeroverwrite = (read-host "yes / no").ToLower().Trim()
                        if ($answeroverwrite -eq "yes") {
                            $canoverwrite = $true
                        } else {
                            write-error "You answered negative to overwriting the current module, stopping"
                        }
                        ln
                    } else {
                        $canoverwrite = $true
                    }
                    if($canoverwrite) {
                        write-host "Downloading from $baseurl"
                        Install-VeeamHubWebFile -url ($installversion.psd -replace "baseurl:/",$baseurl) -dest $installbase -fixnl $true
                        Install-VeeamHubWebFile -url ($installversion.psm -replace "baseurl:/",$baseurl) -dest $installbase -fixnl $true

                        Import-Module "$veeamhubmodulename" -ErrorAction SilentlyContinue
                        if ((Get-Module "$veeamhubmodulename") -ne $null) {
                            try { 
                                $vhv = Invoke-Expression "Get-VeeamHubVersion"
                                write-host "Installed and loaded $vhv"
                                write-host "Next time, please use 'import-module $veeamhubmodulename' to load the module"
                            } catch { 
                                write-error "Could not run Get-VeeamHubVersion"
                            }
                        } else {
                            Write-Error "Something must have gone wrong because I was not able to load the module, please validate $installbase"
                        } 

                    }
                } else {
                    write-error "$installbase could not be created, make sure you have access"
                }

            } else {
                write-error "Could not find path"
            }

        } else {
            Write-Error "Found json version file but it seems corrupted"
        }
    } else {
        Write-Error "Could not find module version page"
    }
}