#$DebugPreference = 'Continue'
Add-PSSnapin VeeamPSSnapin

function Test-RestorePath {
    <#
    .Synopsis
        Validates path given to ensure compatibility with restore script.
    .Description
        This function will accept a string and validate that it is a valid path for to be used in restore script.
    .Example
        PS C:\> Test-RestorePath 'C:\temp\'
    .Example
        PS C:\> Test-RestorePath 'C:\temp\document.txt'
    .Example
        PS C:\> Test-RestorePath '\\servername\c$\'
    .Example
        PS C:\> Test-RestorePath '\\servername\c$\document.txt'
    .Notes
         NAME:      Test-RestorePath
         VERSION:   1.0
         AUTHOR:    Chris Evans
         THANKS:    https://github.com/fullenw1 I wouldn't have been able to do this sort of validation without having yours to start from!
    #>
    Param(
        [Parameter(Mandatory)]
        #Three regular expressions separated by a pipe meaning:
        #Local file | UNC path | Local path | Local drive (root directory)
        [ValidatePattern('^[a-zA-Z]:\\\w+|^\\\\\w+\\*|^[a-zA-Z]:\\\w+\\|^[a-zA-Z]:\\')]
        #Checking if the parent folder exists
        [ValidateScript(
            {
                <##### DEBUG: Switch block 2 #####>
                switch ($PSItem) {
                    #Matches a root drive (ie. C:\ or Z:\). Break is necessary to avoid the final switch condition from the final switch condition from throwing error as a root directory has no parent.
                    { $PSItem -match '^[a-zA-Z]:\\$' } { $True; Write-Debug "Exited switch block 2 via root drive match.`n"; break }
                    #Checks for a path containing more than one colon
                    { $PSItem -match '(:[^:]+:)|::+' } { Throw 'Path cannot contain more than one colon.'}
                    #Checks for any forbidden characters that don't get caught by Test-Path
                    { $PSItem -match '[~/{}]' } { Throw 'The file contains one or more invalid characters (~/{}).' }
                    #Checks to see if file can be created given the parent path. If path does not exist, we cannot create a file there, now can we?
                    {(-not(Test-Path -Path (Split-Path -Path $PSItem -Parent))) } { Throw 'The file cannot be created in the path you provided because the folder does not exist.' }
                    #Default true if nothing has matched.
                    Default { $True; Write-Debug "Switch block 2 exited out of default value.`n" }
                }
            }
        )]
        [ValidateScript(
            {
                Write-Debug ("Testing path: " + $PSItem + "`n")
                
                <##### DEBUG: Switch block 1 #####>
                #Checking final character in path for a period or whitespace.
                switch ($PSItem[-1]) {
                    '.' {Throw 'A valid filepath cannot end with a period.'}
                    { $PSItem -match '\s' } { Throw 'A valid filepath cannot end with a blank character.' }
                    Default { $True; Write-Debug "Switch block 1 exited out of default value.`n" }
                }
            }
        )]
        #Syntax validation
        [ValidateScript( {Test-Path -Path $PSItem -IsValid})]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )
Write-Debug ("Is the path valid? " + $?)
}#Test-RestorePath

function Show-Backups {
    <#
    .Synopsis
        Formats table of backups for better readability.
    .Description
        This function will format the $Result into a table to display to user and make it easier to choose which backup(s) to select for restore.
    .Example
        PS C:\> Show-Backups $Result
    .Notes
         NAME:      Show-Backups
         VERSION:   1.0
         AUTHOR:    Chris Evans
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0,
            Mandatory = $False
        )]
        [PSObject]
        $Output = $Result
    )
    begin {
        $Global:n = 0
    }
    process {
        $CustomTable = @{ Expression={ $Global:n;$Global:n++ };Label="Index";Width=10;Align="left" }, `
        @{ Expression={ $_.VmName };Label="VM Name";Width=20;Align="left" }, `
        @{ Expression={ $_.CreationTime };Label="Creation Time";Width=25;Align="left" }, `
        @{ Expression={ $_.Type };Label="Type";Width=15;Align="left" }
    }
    end {
        Write-Host
        Write-Host "Here is the list of backups according to your input:"
        Write-Host
        return $Output | Format-Table $CustomTable
    }
}#Show-Backups

do { [string]$JobName = Read-Host ' 
Name of job which has backups you would like to restore from.
Enter job name' } until ($JobName -ne '')
Write-Debug ('$JobName: ' + $JobName)

do { [string]$ServerName = Read-Host '
From which server would you like to restore folder/file(s)?
Enter server name' } until ($ServerName -ne '')
Write-Debug ('$ServerName: ' + $ServerName)

do { [string]$RestoreFile = Read-Host '
Path to folder or file which you would like to restore. 
Example: C:\temp\ or C:\temp\file.txt
Enter source folder/file path' } until ($RestoreFile -ne '')
Write-Debug ('$RestoreFile: ' + $RestoreFile)

do { [string]$CopyTo = Read-Host '
Drive path (or UNC path) where restored folder or file(s) will go.
Example: C:\temp\ or \\servername\c$\temp\
Enter target folder path'; Test-RestorePath $CopyTo } until ($? -eq $True)

<# Checks to make sure $CopyTo path ends with \. If not, adds it.#>
if ($CopyTo -NotMatch '\\$') { $CopyTo += '\' }
Write-Debug ('$CopyTo: ' + $CopyTo)

$Result = Get-VBRBackup | Where-Object { $_.jobname -eq $JobName } | Get-VBRRestorePoint | Where-Object { $_.name -eq $ServerName } | Sort-Object CreationTime

if ($Result.Count -eq 0) {
	Write-Host 'Unable to locate any backups based on input. Please try again.'
	Start-Sleep -s 3
	Exit
} else {
    Show-Backups $Result
}

$Title    = 'Reverse List Order?'
$Question = 'Would you like to flip the sort order to list newest backups at the top?'
$Choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$Choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$Choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

$Decision = $Host.UI.PromptForChoice($Title, $Question, $Choices, 1)
if ($Decision -eq 0) {
    Clear-Host
    $Result = Get-VBRBackup | Where-Object { $_.jobname -eq $JobName } | Get-VBRRestorePoint | Where-Object { $_.name -eq $ServerName } | Sort-Object CreationTime -Descending
	Show-Backups $Result
}

do { [int]$Start = Read-Host 'Please enter starting index' } until (($Start -lt $Result.Count) -and ($Start -ge 0))
Write-Debug ('$Start index: ' + $Start)
Write-Host
do { [int]$Stop = Read-Host 'Please enter ending index' } until (($Stop -ge $Start) -and ($Stop -lt $Result.Count))
Write-Debug ('$Stop index: ' + $Stop)

for (($i = $Start), ($j = 1), ($k = (($Stop - $Start) + 1)); $i -le $Stop; ($i++), ($j++)) {
	Write-Host
	Write-Host 'Starting restore' $j 'of' $k
    $Session = $Result | Select-Object -Index $i | Start-VBRWindowsFileRestore
    $FLRMountPoint = ($Session.MountSession.MountedDevices | Where-Object { $_.DriveLetter -eq (Split-Path -Qualifier $RestoreFile) })
    $VeeamFLRDir = $FLRMountPoint.MountPoint + (Split-Path -NoQualifier $RestoreFile)
    $VeeamFLRLeaf = $VeeamFLRDir | Split-Path -Leaf
    Copy-Item -Path $VeeamFLRDir -Destination $CopyTo -Recurse -Force
    Get-ChildItem ($CopyTo + $VeeamFLRLeaf) | Rename-Item -NewName { (Get-Date $Session.CreationTime -UFormat 'RESTORED_%d-%b-%Y_%H-%M-%S ') + $_.Name }
    try {
        Get-Item ($CopyTo + $VeeamFLRLeaf) -ErrorAction Stop | Rename-Item -NewName { (Get-Date $Session.CreationTime -UFormat 'RESTORED_%d-%b-%Y_%H-%M-%S ') + $_.Name }
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Debug "Exception caught! Item being restored was a file, not a folder. It had already been renamed."
    }
    Stop-VBRWindowsFileRestore $Session
	Write-Host 'Restore' $j 'of' $k 'completed.'
}

Write-Host
Invoke-Item $CopyTo
$null = Read-Host 'Restores complete! Press ENTER to exit.'
Exit
