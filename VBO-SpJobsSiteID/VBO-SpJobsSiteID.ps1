<# 
   .SYNOPSIS
   Reading unprotected SharePoint Sites and add them to backup jobs 

   .DESCRIPTION
   This script gets all unprotected SharePoint Sites from an organisation added to Veeam Backup for Microsoft 365.
   These unprotected sites are then addod to backup jobs based on the firt two characters of the Site ID. 
   If a corresponding job does not exist, it will be created with the given paramaters.
   The detault will create up to 64 backup jobs but this can be adjusted by changing the grouping for the second charater array.
    
   .NOTES 
   Version:        2.1
   Author:         David Bewernick (david.bewernick@veeam.com)
   Creation Date:  11.11.2022
   Purpose/Change: Initial script development

   .CHANGELOG
   v1.0   18.10.2022   Script created
   v2.0   10.11.2022   removed manual reading for Site ID directly from Microsoft
   v2.1   11.11.2022   added time delay for new jobs

 #> 

######## Your definitions ########

# Enable (1) or disable (0) debug messages
$debug = 0

# Define the VB365 organisation
$OrgName = "dabew.onmicrosoft.com"

# Define the target repository
$RepoName = "repo01"

# Define the backup schedule for new jobs (Options Info: https://helpcenter.veeam.com/archive/vbo365/40/powershell/new-vbojobschedulepolicy.html)
$vbSchedType = "daily"
$vbSchedDailyType = "Everyday"
$vbSchedStartHr = "22"
$vbSchedStartMin = "00"

# Create the initial start time value
$global:vbDailyTime = "$vbSchedStartHr" + ":" + "$vbSchedStartMin" + ":00"

# Time to delay the next created job
$global:vbSchedDelayMin = "2"

# Where should the logfiles be saved?
[string]$LogFile = "C:\Scripts\VBO-SpJobsSiteID_$timestampFileName.log"

# The naming start of the backup jobs
[string]$strJobNameStart = "SharePoint_"

##################################

$timestampFileName = get-date -Format "yyyy-MM-dd_HH-mm-ss"

# A one dimensional array for the first charater of the SiteId
$arrFirstChar = '0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'

# A two dimensional array for the secon charater of the SiteId in groups
$arrScndChar = @(("0","1","2","3"),("4","5","6","7"),("8","9","a","b"),("c","d","e","f"))


######### Some functions #########

function Write-Log($Info, $Status){
    $timestamp = get-date -Format "yyyy-mm-dd HH:mm:ss"
    switch($Status){
        Info    {Write-Host "$timestamp $Status : $Info" -ForegroundColor Green  ; "$timestamp $Status : $Info" | Out-File -FilePath $LogFile -Append}
        Status  {Write-Host "$timestamp $Status : $Info" -ForegroundColor Yellow ; "$timestamp $Status : $Info" | Out-File -FilePath $LogFile -Append}
        Warning {Write-Host "$timestamp $Status : $Info" -ForegroundColor Yellow ; "$timestamp $Status : $Info" | Out-File -FilePath $LogFile -Append}
        Error   {Write-Host "$timestamp $Status : $Info" -ForegroundColor Red -BackgroundColor White; "$timestamp $Status : $Info" | Out-File -FilePath $LogFile -Append}
        default {Write-Host "$timestamp $Status : $Info" -ForegroundColor white "$timestamp $Status : $Info" | Out-File -FilePath $LogFile -Append}
    }
}


# Function to dd all unprotected sites to a job
function handelUnprotected(){

    foreach ($VbUnprotectedSite in $VbUnprotectedSites) {
        
        # Get the name of the unprotected site
        $VbUnprotectedSiteName = $VbUnprotectedSite.Name

        # Get the SiteId as a string
        [string]$SiteID = $VbUnprotectedSite.SiteId

        # First character of the SiteId
        $SiteIdFirstChar = $SiteID.substring(0,1)

        # Second character of the SiteId
        $SiteIdSecondtChar = $SiteID.substring(1,1)

        if($debug="1"){Write-Host "SiteId start: $SiteIdFirstChar$SiteIdSecondtChar"}

        # Call function to add the site to a job
        AddCreateSPjobs
    }
}

# Function to add sites to a job and create the job if it does not exist
function AddCreateSPjobs(){
    
    # Go through the array for the first character
    $i=0
    while($i -lt $arrFirstChar.length){ 
        
        # Check if the first array charater maches the first SiteId character
        if ($arrFirstChar[$i] -like $SiteIdFirstChar){
            if($debug="1"){Write-Host "First Char match: $SiteIdFirstChar"} 
            
            # Go through the array for the second character in dimention 1
            $j=0
            while($j -lt $arrScndChar.length){

                # Create the second character group name
                $JobNameScndCharGroup = $arrScndChar[$j][0] + "-" + $arrScndChar[$j][-1]
                if($debug="1"){Write-Host "JobNameScndCharGroup: $JobNameScndCharGroup"}

                # Building the end of the job name
                $JobNameEnd = $arrFirstChar[$i] + $JobNameScndCharGroup
                if($debug="1"){Write-Host "JobNameEnd: $JobNameEnd"}
                
                # Building the complete job name
                $JobName = $strJobNameStart + $JobNameEnd
                if($debug="1"){Write-Host "JobName: $JobName"}
                               
                # Go through the array for the second character in each dimention 2
                $k=0
                while($k -lt $arrScndChar[$j].length){

                    # Check if the second array charater maches the second SiteId character
                    if ($arrScndChar[$j][$k] -like $SiteIdSecondtChar){
                        if($debug="1"){Write-Host "Second Char match: $SiteIdSecondtChar"}                
                                                
                        $jobitem = New-VBOBackupItem -Site $VbUnprotectedSite

                        # Check if job exist and add site

                        if ($VbJob=Get-VBOJob | ? {$_.Name -like $JobName}){
                            Write-Log -Info "$JobName exists, adding $VbUnprotectedSiteName" -Status Info
                            Add-VBOBackupItem -Job $VbJob -BackupItem $jobitem

                        }

                        # If job does not exist create it including the site
                        else {
                            Write-Log -Info "Creating $JobName and adding $VbUnprotectedSiteName" -Status Info
                            Add-VBOJob -Organization $vbOrgObject -Name "$JobName" -Repository $vbRepoObject -SchedulePolicy $vbSchedule -SelectedItems $jobitem

                            # Increase the time for the next schedule
                            if($debug="1"){Write-Host "Schedule before delay: $($vbSchedule.DailyTime)"}
                            AddTimeDelay
                            if($debug="1"){Write-Host "Schedule after delay: $($vbSchedule.DailyTime)"}
                        }

                    }
                $k++
                }
                
            $j++
            }
        }
    $i++
    }

}

function AddTimeDelay(){

    if($debug="1"){Write-Host "vbSchedTimeObj before delay: $vbSchedTimeObj"}

    # Add the delay minutes
    $global:vbSchedTimeObj = $vbSchedTimeObj.AddMinutes($vbSchedDelayMin)
    if($debug="1"){Write-Host "vbSchedTimeObj after delay: $vbSchedTimeObj"}

    # Recreate the DailyTime value
    $global:vbDailyTime = $vbSchedTimeObj.ToString("HH:mm:ss")
    if($debug="1"){Write-Host "vbDailyTime: $vbDailyTime"}

    # Recreate the schedule object with the new start time
    $global:vbSchedule = New-VBOJobSchedulePolicy -Type $vbSchedType -DailyType $vbSchedDailyType -DailyTime $vbDailyTime
    if($debug="1"){Write-Host "vbSchedule: $vbSchedule"}
}

#### Main action ####

# Get the VB365 organisation object
$vbOrgObject = Get-VBOOrganization -Name $OrgName 

# Get the VB365 target repository object
$vbRepoObject = Get-VBORepository -Name $RepoName

# Create a time object for later modification
$global:vbSchedTimeObj = New-Object DateTime 2022, 1, 1, $vbSchedStartHr, $vbSchedStartMin, 0, ([DateTimeKind]::Utc)
if($debug="1"){Write-Host "Initial vbSchedTimeObj: $vbSchedTimeObj"}

# Build the backup job schedule
$global:vbSchedule = New-VBOJobSchedulePolicy -Type $vbSchedType -DailyType $vbSchedDailyType -DailyTime $vbDailyTime
Write-Log -Info "New jobs will be created with this initual schedule:`n`t`t`t`t Type: $($vbSchedule.Type) `n`t`t`t`t DailyType: $($vbSchedule.DailyType) `n`t`t`t`t DailyTime: $($vbSchedule.DailyTime) `n`t`t`t`t Delay for the next job: $vbSchedDelayMin" -Status Info

#get all SP sites not in a job but exclude personal sites
Write-Log -Info "Get all SP sites not in a job but exclude personal sites. This will take a while... Maybe go and grab a Coffee or go for a walk?" -Status Status

# Run and measute the time of the Get-VBOOrganizationSite command to find SharePoint Sites not in jobs
$executionTime = Measure-Command {
    #$VbUnprotectedSites = Get-VBOOrganizationSite -Organization $vbOrgObject -NotInJob
}

# Read some execution values
$execHrs = $executionTime.Hours
$execMin = $executionTime.Minutes
$execSec = $executionTime.Seconds
$execTSec = $executionTime.TotalSeconds

# Count the number of unprotected sites
$countUnprotectedSites = $VbUnprotectedSites.count

Write-Log -Info "I found $countUnprotectedSites unprotected sites in $execTSec seconds, that is $execHrs hrs, $execMin min, $execSec sec  " -Status Info

# handle all the unprotected sites
handelUnprotected