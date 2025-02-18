
#### tested against: 
# VBM365 7.1.0.1401 P20231218
# VBM365 7.1.0.1501 P20240123
# VBM365 7.1.0.2701 P20240730

## Import VBM365 Powershell Modules
Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

## Load funtions
Function Logging ($text) {
    write-host (get-date -Format "dd-MM-yyyy HH:mm:ss") $text
}

## Input variables
# General input
$debug = $true # if debug = true, only print output, no actions taken
$OrganizationName = "msft.onmicrosoft.com" # Organization name as known in VBM365
$RepoPrefix = $null # When you use a Repositoryname Prefix. Defaults to $null
$RepoName = "test" # Repository name as known in VBM365 that is assosiated with the Organization
$EntireOrganization = $false # Set $true if entire Organization must be removed from the Repository

# Input for Users
# These variables only takes email adresses assosiated with a User. Can also be "All" to select all usernames or Objects. Multiple emailadresses or objecttypes can be split with ","
# Example:
# $UserNames = "example1@msft.com,example2@msft.com,example31@msft.com,example4@msft.com". Default is Null
# $UserObjectTypes choices are [All, Email, EmailArchive, PersonalSharepoint, OneDrive]. Default is All
$UserNames = $null
$UserObjectTypes = "All"

# Input for Groups
# These variables only takes email adresses assosiated with a Group. Can also be "All" to select all Groups or Objects. Multiple email adresses or objecttypes can be split with ","
# Example:
# $GroupNames = "example1@msft.com,example2@msft.com,example31@msft.com,example4@msft.com". Default is Null
# $GroupObjectTypes choices are [All, Email, PersonalSharepoint]. Default is All
$GroupNames = $null 
$GroupObjectTypes = "All"

# Input for Sharepointsites (not personalsites)
# This variable only takes FQDN assosiated with a SharePointSite. Can also be "All" to select all SharePointSites. Multiple FQDN's can be split with ","
# Example:
# $SharePointSiteNames = "msft.sharepoint.com,msft.sharepoint.com". Default is Null
$SharePointSiteNames = $null

# Input for Teams 
# This variable only takes email adresses assosiated with a Team. Can also be "All" to select all Teams. Multiple email adresses can be split with ","
# Example:
# $TeamsNames = "example1@msft.com,example2@msft.com,example31@msft.com,example4@msft.com". Default is Null
$TeamsNames = $null

## if entire organization is $true all variables are changed to "all"
if ($EntireOrganization -eq $true) 
    {
    $UserNames = "All"
    $UserObjectTypes = "All"
    $GroupNames = "All" 
    $GroupObjectTypes = "All"
    $SharePointSiteNames = "All"
    $TeamsNames = "All"
}
else {}

##### Load inputs and prepare them for script #####
###################################################

## Gather backup data
# Get VBM365 Repository
$VBMRepository = Get-VBORepository -name "$($RepoPrefix)$($RepoName)"
if ($null -eq $VBMRepository) 
    {
    Logging "Could not locate Repository or encountered another error, stopping script"
    Write-Output $Error[0].Exception
    break
}
else {Logging "Found repository in VBM server"}

# Get VBM365 Organisation
$VBMOrganization = Get-VBOOrganization -Name $OrganizationName
if ($null -eq $VBMOrganization) 
    {
    Logging "Could not locate Organization in VBM365 server or encountered another error, continuing without VBM365 server information about this Organisation"
}
else {Logging "Found Organization in VBM server"}

## Inputs for Users ##
if ($null -eq $UserNames) 
    {
        Logging "No user input found, skipping user removal"
    }
    elseif ($null -ne $UserObjectTypes -or "" -ne $UserObjectTypes) 
        {
            Logging "User & ObjectTypes are specified"
        }
else 
    {
        Logging "USERS input validation - Something is wrong"
        Break
    }

## Inputs for Groups ##
if ($null -eq $GroupNames) 
    {
        Logging "No groups input found, skipping group removal"
    }
    elseif ($null -ne $GroupObjectTypes -or "" -ne $GroupObjectTypes) 
        {
            Logging "Group & ObjectTypes are specified"
        }
else 
    {Logging "GROUPS input validation - Something is wrong"
     Break
    }

## Inputs for Sharepoint ##
if ($null -eq $SharePointSiteNames) 
    {
        Logging "No SharePointSites input found, skipping SharePointSite removal"
    }
    elseif ($null -ne $SharePointSiteNames -or "" -ne $SharePointSiteNames) 
        {
            Logging "SharePointSites are specified"
        }
else 
    {Logging "SHAREPOINTSITES input validation - Something is wrong"
     Break
    }

## Inputs for Teams ##
if ($null -eq $TeamsNames) 
    {
        Logging "No Teams input found, skipping Teams removal"
    }
    elseif ($null -ne $TeamsNames -or "" -ne $TeamsNames) 
        {
            Logging "Teams are specified"
        }
else 
    {Logging "TEAMS input validation - Something is wrong"
     Break
    }

## After input validation we gather information that is present in the backup repository and create arrays that can be used for final check and go. These arrays are used as source for the actual removal of data.
if ($null -ne $UserNames) {
    # Initialize users array if user removal is requested
    $Users = New-Object PSObject -Property @{
        Allusers = $false # defaults to false
        Usernames = $null
    }
    
    # Prepare array with users
    if ($usernames -eq 'all' -or $EntireOrganization -eq $true) 
        {
            $Users.Allusers = $true
        }
    else 
        {
            $Users.Usernames = $UserNames -split ","
        }
    
    # Prepare array with UserObjectTypes
    $UserObjectTypes = $UserObjectTypes.replace(' ','').Replace(',','|') 
    $UserObjects = @()
        if ($UserObjectTypes -match 'all') 
            {
                $UserObjects += ('Email','EmailArchive','PersonalSharepoint','OneDrive').split(",")
            } 
        else 
            {
            if ($UserObjectTypes -match 'Email')                        {$UserObjects += 'Email'}
            if ($UserObjectTypes -match 'EmailArchive')                 {$UserObjects += 'EmailArchive'}
            if ($UserObjectTypes -match 'PersonalSharepoint')           {$UserObjects += 'PersonalSharepoint'}
            if ($UserObjectTypes -match 'OneDrive')                     {$UserObjects += 'OneDrive'}
            }
    
    # Check and match users from input with backed up data
    Logging "Enumerating users from backupdata"
    # First gather all user objects from specified repository and organization
    $VBMUserObjects = @()
    $VBMUserObjects = Get-VBOEntityData -Type User -Repository $VBMRepository | Where-Object {$_.Organization -like $OrganizationName}
    
    # Initialize array to create overview of actions to be taken 
    $VBMUserObjectsModification = @()
    $UsernamesRegex = try {$Users.usernames.replace(' ','') -join "|"} catch {}
    
    # Loop through
    foreach ($obj in $VBMUserObjects)
        {
        $o = New-Object PSObject -Property @{
            AccountType              = $obj.AccountType
            ArchiveBackedUpTime      = $obj.ArchiveBackedUpTime
            ArchiveName              = $obj.ArchiveName
            DisplayName              = $obj.DisplayName
            Email                    = $obj.Email
            IsArchiveBackedUp        = $obj.IsArchiveBackedUp
            IsMailboxBackedUp        = $obj.IsMailboxBackedUp
            IsOneDriveBackedUp       = $obj.IsOneDriveBackedUp
            IsPersonalSiteBackedUp   = $obj.IsPersonalSiteBackedUp
            MailboxBackedUpTime      = $obj.MailboxBackedUpTime
            OneDriveBackedUpTime     = $obj.OneDriveBackedUpTime
            OneDriveUrl              = $obj.OneDriveUrl
            Organization             = $obj.Organization
            PersonalSiteBackedUpTime = $obj.PersonalSiteBackedUpTime
            PersonalSiteUrl          = $obj.PersonalSiteUrl
            Type                     = $obj.Type
            RemoveEmail              = if (($users.Allusers -eq $true -or $UsernamesRegex -match $obj.Email) -and $UserObjects -contains "Email" -and $obj.IsMailboxBackedUp -eq $true) {$true} else {$false} 
            RemoveEmailArchive       = if (($users.Allusers -eq $true -or $UsernamesRegex -match $obj.Email) -and $UserObjects -contains "EmailArchive" -and $obj.IsArchiveBackedUp -eq $true) {$true} else {$false}  
            RemovePersonalSharepoint = if (($users.Allusers -eq $true -or $UsernamesRegex -match $obj.Email) -and $UserObjects -contains "PersonalSharepoint" -and $obj.IsPersonalSiteBackedUp -eq $true) {$true} else {$false}  
            RemoveOneDrive           = if (($users.Allusers -eq $true -or $UsernamesRegex -match $obj.Email) -and $UserObjects -contains "OneDrive" -and $obj.IsOneDriveBackedUp -eq $true) {$true} else {$false}  
        }
        $VBMUserObjectsModification += $o
    }
}
else {}

if ($null -ne $GroupNames) {
    # Initialize Groups array
    $Groups = New-Object PSObject -Property @{
        AllGroups = $false # defaults to false
        Groupnames = $null
    }
    
    # Prepare array with Groups
    if ($GroupNames -eq 'all' -or $EntireOrganization -eq $true) 
        {
            $Groups.AllGroups = $true
        }
    else 
        {
            $Groups.Groupnames = $GroupNames -split ","
        }
    
    # Prepare array with GroupObjectTypes
    $GroupObjectTypes = $GroupObjectTypes.replace(' ','').Replace(',','|') 
    $GroupObjects = @()
        if ($GroupObjectTypes -match 'all') 
        {
            $GroupObjects += ('Email','PersonalSharepoint','OneDrive').split(",")
        } 
        else {
            if ($GroupObjectTypes -match 'Email')                        {$GroupObjects += 'Email'}
            if ($GroupObjectTypes -match 'PersonalSharepoint')           {$GroupObjects += 'PersonalSharepoint'}
        }
    
    
    # Check and match groups from input with backed up data
    Logging "Enumerating groups from backupdata"
    # First gather all group objects from specified repository and organization
    $VBMGroupObjects = @()
    $VBMGroupObjects = Get-VBOEntityData -Type group -Repository $VBMRepository | Where-Object {$_.Organization -like $OrganizationName}
    
    # Initialize array to create overview of actions to be taken 
    $VBMGroupObjectsModification = @()
    $GroupnamesRegex = try {$Groups.Groupnames.replace(' ','') -join "|"} catch {}
    
    # Loop through
    foreach ($obj in $VBMGroupObjects) {
        $o = New-Object PSObject -Property @{
            DisplayName              = $obj.DisplayName
            Email                    = $obj.Email
            IsMailboxBackedUp        = $obj.IsMailboxBackedUp
            IsSiteBackedUp           = $obj.IsSiteBackedUp
            MailboxBackedUpTime      = $obj.MailboxBackedUpTime
            OneDriveUrl              = $obj.OneDriveUrl
            Organization             = $obj.Organization
            PersonalSiteUrl          = $obj.PersonalSiteUrl
            SiteBackedUpTime         = $obj.SiteBackedUpTime
            Type                     = $obj.Type
            RemoveEmail              = if (($groups.Allgroups -eq $true -or $GroupnamesRegex -match $obj.Email) -and $GroupObjects -contains "Email" -and $obj.IsMailboxBackedUp -eq $true) {$true} else {$false}
            RemovePersonalSharepoint = if (($groups.Allgroups -eq $true -or $GroupnamesRegex -match $obj.Email) -and $GroupObjects -contains "PersonalSharepoint" -and $obj.IsSiteBackedUp) {$true} else {$false}
        }
        $VBMGroupObjectsModification += $o
    }
}
else {}

if ($null -ne $SharePointSiteNames) {
    # Initialize SharePointSites array
    $SharePointSites = New-Object PSObject -Property @{
        AllSites = $false # defaults to false
        SiteNames = $null
    }
    
    # Prepare array with SharePointSites
    if ($SharePointSiteNames -eq 'all' -or $EntireOrganization -eq $true) 
        {
            $SharePointSites.AllSites = $true
        }
    else 
        {
            $SharePointSites.SiteNames = $SharePointSiteNames -split ","
        }
    
    # Check and match SharePointSites from input with backed up data
    Logging "Enumerating SharepointSites from backupdata"
    # First gather all group objects from specified repository and organization
    $VBMSharePointObjects = @()
    $VBMSharePointObjects = Get-VBOEntityData -Type Site -Repository $VBMRepository | Where-Object {$_.Organization -like $OrganizationName}
    
    # Initialize array to create overview of actions to be taken 
    $VBMSharePointObjectsModification = @()
    $SharePointRegex = try {$Groups.Groupnames.replace(' ','') -join "|"} catch {}
    
    # Loop through
    foreach ($obj in $VBMSharePointObjects) {
        $o = New-Object PSObject -Property @{
            Title                = $obj.Title        
            Url                  = $obj.Url          
            Organization         = $obj.Organization 
            BackedUpTime         = $obj.BackedUpTime 
            DisplayName          = $obj.DisplayName  
            Type                 = $obj.Type
            IsSiteBackedUp       = if ($null -ne $obj.BackedUpTime) {$true} else {$false} # This one does not exist as property but is needed to check if the object should be removed
            RemoveSharePointSite = if ($SharePointSites.AllSites -eq $true -or $SharePointRegex -match $obj.Url) {$true} else {$false} 
        }
        $VBMSharePointObjectsModification += $o
    }
    
    ### TEMPORARY FIX - Remove all "/personal/" because personal sites also get returned by "Get-VBOEntityData -Type Site" and is redundant. Personal sites can be removed via Users.
    # FR requested https://forums.veeam.com/veeam-backup-for-microsoft-365-f47/feature-request-vbm365-get-vboentitydata-type-site-t91996.html
    $VBMSharePointObjectsModification = $VBMSharePointObjectsModification | Where-Object {$_.Url -notlike "*sharepoint.com/personal/*"}

}
else {}

if ($null -ne $TeamsNames) {
    # Initialize Teams array
    $Teams = New-Object PSObject -Property @{
        AllTeams = $false # defaults to false
        Teams = $null
    }
    
    # Prepare array with Teams
    if ($TeamsNames -eq 'all' -or $EntireOrganization -eq $true) 
        {
            $Teams.AllTeams = $true
        }
    else 
        {
            $Teams.Teams = $TeamsNames -split ","
        }
    
    
    # Check and match Teams from input with backed up data
    Logging "Enumerating Teams from backupdata"
    # First gather all group objects from specified repository and organization
    $VBMTeamsObjects = @()
    $VBMTeamsObjects = Get-VBOEntityData -Type Team -Repository $VBMRepository | Where-Object {$_.Organization -like $OrganizationName}
    
    # Initialize array to create overview of actions to be taken 
    $VBMTeamsObjectsModification = @()
    $TeamsRegex = try {$Teams.Teams.replace(' ','') -join "|"} catch {}
    
    # Loop through
    foreach ($obj in $VBMTeamsObjects) {
        $o = New-Object PSObject -Property @{
            Alias           = $obj.Alias  
            Email           = $obj.Mail       
            Organization    = $obj.Organization 
            BackedUpTime    = $obj.BackedUpTime 
            DisplayName     = $obj.DisplayName  
            Type            = $obj.Type
            IsTeamsBackedUp = if ($null -ne $obj.BackedUpTime) {$true} else {$false} # This one does not exist as property but is needed to check if the object should be removed
            RemoveTeams     = if ($Teams.AllTeams -eq $true -or $TeamsRegex -match $obj.Mail) {$true} else {$false} 
        }
        $VBMTeamsObjectsModification += $o
    }
}
else {}

# if no backupdata for this organization is found in this repository, stop script.
if (
    $null -eq $VBMUserObjects -and
    $null -eq $VBMGroupObjects -and
    $null -eq $VBMSharePointObjects -and
    $null -eq $VBMTeamsObjects 
    )
    {
        Logging "No back-ups found in this repository $($VBMRepository.name), Aborting script"
        Break
    }
Else {}

## Present all data
Write-host
Write-host "I found the following User objects in the repository that match the input given"
Write-host "###############################################################################"
Write-output $VBMUserObjectsModification | Select-Object Email, DisplayName, IsMailboxBackedUp, RemoveEmail, IsArchiveBackedUp, RemoveEmailArchive, IsPersonalSiteBackedUp, RemovePersonalSharepoint, IsOneDriveBackedUp ,RemoveOneDrive | sort-object Email |Format-Table -AutoSize

Write-host
Write-host "I found the following Group objects in the repository that match the input given"
Write-host "################################################################################"
Write-output $VBMGroupObjectsModification | Select-Object Email, DisplayName, IsMailboxBackedUp, RemoveEmail, IsSiteBackedUp, RemovePersonalSharepoint | sort-object Email | Format-Table -AutoSize

Write-host
Write-host "I found the following SharePoint objects in the repository that match the input given"
Write-host "#####################################################################################"
Write-output $VBMSharePointObjectsModification | Select-Object Url, DisplayName, IsSiteBackedUp, RemoveSharePointSite | sort-object Url | Format-Table -AutoSize

Write-host
Write-host "I found the following Teams objects in the repository that match the input given"
Write-host "################################################################################"
Write-output $VBMTeamsObjectsModification | Select-Object Email, Displayname, IsTeamsBackedUp, RemoveTeams | sort-object Email | Format-Table -AutoSize

Write-host "Are you certain all these objects need to be deleted, this action cannot be reversed"
$RemovalConfirmation = $null # Reset entry, fun times when you re run this script with existing variables.
While ($true)  {
        $RemovalConfirmation = Read-Host "Please enter Yes or No"
        if ($RemovalConfirmation -eq "Yes"){
            Logging "Removal confirmed"
            break
        }
        elseif ($RemovalConfirmation -eq "No")
            {
            Logging "Aborting script"
            break
        }
        Write-Host "Invalid input" -ForegroundColor Red
}
if ($RemovalConfirmation -eq "No") 
    {
    Break
}

####################################################################################################################################################################################
# Execution part
####################################################################################################################################################################################

# Initialize Veeam task logging
$VeeamTaskLog = @()

# User removal
if ($null -ne $VBMUserObjectsModification)
    { 
        # Initialize report array for User actions
        $VBMuserReport = @()

        foreach ($obj in $VBMUserObjectsModification) 
        {
            Logging "Processing user $($obj.DisplayName)"

            # Initialize array for result logging
            $o = New-Object PSObject -Property @{
            Organization                   = $obj.Organization
            DisplayName                    = $obj.DisplayName
            Email                          = $obj.Email
            RemoveEmail                    = $obj.RemoveEmail
            RemoveEmailTaskId              = $null
            RemoveEmailJobId               = $null
            RemoveEmailResult              = $null
            RemoveEmailArchive             = $obj.RemoveEmailArchive
            RemoveEmailArchiveTaskId       = $null
            RemoveEmailArchiveJobId        = $null
            RemoveEmailArchiveResult       = $null
            RemoveOneDrive                 = $obj.RemoveOneDrive
            RemoveOneDriveTaskId           = $null
            RemoveOneDriveJobId            = $null
            RemoveOneDriveResult           = $null
            RemovePersonalSharepoint       = $obj.RemovePersonalSharepoint
            RemovePersonalSharepointTaskId = $null
            RemovePersonalSharepointJobId  = $null
            RemovePersonalSharepointResult = $null
            }
         
            # User Email removal
            if ($obj.RemoveEmail -eq $true)
                {
                if ($debug -ne $true)
                    {
                    Logging "$($obj.Type) $($obj.DisplayName) - Removing Email back-up from repository $($VBMRepository.Name)"

                    # refresh variables
                    $ObjItem = $null
                    $action = $null

                    # Initialize Veeam task logging
                    $vtl = New-Object PSObject -Property @{
                        Organization = if ($null -eq $VBMOrganization) {$OrganizationName} else {$VBMOrganization.name}
                        Id           = $null
                        JobId        = $null
                        JobName      = $null
                        CreationTime = $null
                        EndTime      = $null
                        Status       = $null
                        Statistics   = $null
                        Log          = $null
                    }
                    
                    # Why on earth would we work with object ID's... Remove-vboentitydata command requires original and complete objectline from output get-vboentitydata -type user.
                    $ObjItem = $VBMUserObjects | Where-Object {$_.DisplayName -eq $obj.DisplayName -and $_.MailboxBackedUpTime -eq $obj.MailboxBackedUpTime}
                    $action = Remove-VBOEntityData -Repository $VBMRepository -User $ObjItem -Mailbox -Confirm:$false
                    
                    #log result
                    $o.RemoveEmailTaskId = $action.Id
                    $o.RemoveEmailJobId  = $action.JobId
                    $o.RemoveEmailResult = $action.Status
                    $vtl.Id              = $action.Id
                    $vtl.JobId           = $action.JobId
                    $vtl.JobName         = $action.JobName
                    $vtl.CreationTime    = $action.CreationTime
                    $vtl.EndTime         = $action.EndTime
                    $vtl.status          = $action.Status
                    $vtl.Statistics      = $action.Statistics
                    $vtl.Log             = $action.Log
                    
                    # Add row to report
                    $VeeamTaskLog += $vtl                      
                    }

                else 
                    {
                    Logging "DEBUG - $($obj.Type) $($obj.DisplayName) - Removing Email back-up from repository $($VBMRepository.Name)"
                    }   
            }

            # User EmailArchive removal
            if ($obj.RemoveEmailArchive -eq $true)
                {
                if ($debug -ne $true)
                    {
                    Logging "$($obj.Type) $($obj.DisplayName) - Removing EmailArchive back-up from repository $($VBMRepository.Name)"

                    # refresh variables
                    $ObjItem = $null
                    $action = $null

                    # Initialize Veeam task logging
                    $vtl = New-Object PSObject -Property @{
                        Organization = if ($null -eq $VBMOrganization) {$OrganizationName} else {$VBMOrganization.name}
                        Id           = $null
                        JobId        = $null
                        JobName      = $null
                        CreationTime = $null
                        EndTime      = $null
                        Status       = $null
                        Statistics   = $null
                        Log          = $null
                    }

                    # Why on earth would we work with object ID's... Remove-vboentitydata command requires original and complete objectline from output get-vboentitydata -type user.
                    $ObjItem = $VBMUserObjects | Where-Object {$_.DisplayName -eq $obj.DisplayName} 
                    $action = Remove-VBOEntityData -Repository $VBMRepository -User $ObjItem -ArchiveMailbox -Confirm:$false
                    
                    #log result
                    $o.RemoveEmailArchiveTaskId = $action.Id
                    $o.RemoveEmailArchiveJobId  = $action.JobId
                    $o.RemoveEmailArchiveResult = $action.Status
                    $vtl.Id                     = $action.Id
                    $vtl.JobId                  = $action.JobId
                    $vtl.JobName                = $action.JobName
                    $vtl.CreationTime           = $action.CreationTime
                    $vtl.EndTime                = $action.EndTime
                    $vtl.status                 = $action.Status
                    $vtl.Statistics             = $action.Statistics
                    $vtl.Log                    = $action.Log
                    
                    # Add row to report
                    $VeeamTaskLog += $vtl             
                    }        
                else 
                    {
                    Logging "DEBUG - $($obj.Type) $($obj.DisplayName) - Removing EmailArchive back-up from repository $($VBMRepository.Name)"
                    }
            }
            
            # User PersonalSharepoint removal
            if ($obj.RemovePersonalSharepoint -eq $true)
                {
                if ($debug -ne $true)
                    {
                    Logging "$($obj.Type) $($obj.DisplayName) - Removing PersonalSharePoint back-up from repository $($VBMRepository.Name)"

                    # refresh variables
                    $ObjItem = $null
                    $action = $null

                    # Initialize Veeam task logging
                    $vtl = New-Object PSObject -Property @{
                        Organization = if ($null -eq $VBMOrganization) {$OrganizationName} else {$VBMOrganization.name}
                        Id           = $null
                        JobId        = $null
                        JobName      = $null
                        CreationTime = $null
                        EndTime      = $null
                        Status       = $null
                        Statistics   = $null
                        Log          = $null
                    }

                    # Why on earth would we work with object ID's... Remove-vboentitydata command requires original and complete objectline from output get-vboentitydata -type user.
                    $ObjItem = $VBMUserObjects | Where-Object {$_.DisplayName -eq $obj.DisplayName -and $_.PersonalSiteBackedUpTime -eq $obj.PersonalSiteBackedUpTime}
                    $action = Remove-VBOEntityData -Repository $VBMRepository -User $ObjItem -Sites -Confirm:$false
                    
                    #log result
                    $o.RemovePersonalSharepointTaskId = $action.Id
                    $o.RemovePersonalSharepointJobId  = $action.JobId
                    $o.RemovePersonalSharepointResult = $action.Status
                    $vtl.Id                           = $action.Id
                    $vtl.JobId                        = $action.JobId
                    $vtl.JobName                      = $action.JobName
                    $vtl.CreationTime                 = $action.CreationTime
                    $vtl.EndTime                      = $action.EndTime
                    $vtl.status                       = $action.Status
                    $vtl.Statistics                   = $action.Statistics
                    $vtl.Log                          = $action.Log
                    
                    # Add row to report
                    $VeeamTaskLog += $vtl       
                    }
                else
                    {
                    Logging "DEBUG - $($obj.Type) $($obj.DisplayName) - Removing PersonalSharePoint back-up from repository $($VBMRepository.Name)"
                    }
            }  

            # User OneDrive removal
            if ($obj.RemoveOneDrive -eq $true)
                {
                if ($debug -ne $true)
                    {
                    Logging "$($obj.Type) $($obj.DisplayName) - Removing OneDrive back-up from repository $($VBMRepository.Name)"

                    # refresh variables
                    $ObjItem = $null
                    $action = $null

                    # Initialize Veeam task logging
                    $vtl = New-Object PSObject -Property @{
                        Organization = if ($null -eq $VBMOrganization) {$OrganizationName} else {$VBMOrganization.name}
                        Id           = $null
                        JobId        = $null
                        JobName      = $null
                        CreationTime = $null
                        EndTime      = $null
                        Status       = $null
                        Statistics   = $null
                        Log          = $null
                    }

                    # Why on earth would we work with object ID's... Remove-vboentitydata command requires original and complete objectline from output get-vboentitydata -type user.
                    $ObjItem = $VBMUserObjects | Where-Object {$_.DisplayName -eq $obj.DisplayName -and $_.OneDriveBackedUpTime -eq $obj.OneDriveBackedUpTime}
                    $action = Remove-VBOEntityData -Repository $VBMRepository -User $ObjItem -OneDrive -Confirm:$false
                    
                    #log result
                    $o.RemoveOneDriveTaskId = $action.Id
                    $o.RemoveOneDriveJobId  = $action.JobId
                    $o.RemoveOneDriveResult = $action.Status
                    $vtl.Id                 = $action.Id
                    $vtl.JobId              = $action.JobId
                    $vtl.JobName            = $action.JobName
                    $vtl.CreationTime       = $action.CreationTime
                    $vtl.EndTime            = $action.EndTime
                    $vtl.status             = $action.Status
                    $vtl.Statistics         = $action.Statistics
                    $vtl.Log                = $action.Log
                    
                    # Add row to report
                    $VeeamTaskLog += $vtl             
                    }  
                else 
                    {
                    Logging "DEBUG - $($obj.Type) $($obj.DisplayName) - Removing OneDrive back-up from repository $($VBMRepository.Name)"
                    }
            }
        # Add row to report
        $VBMuserReport += $o
        }
}
else {}


# Group removal
if ($null -ne $VBMGroupObjectsModification)
     { 
        # Initialize report array for Group actions
        $VBMGroupReport = @()

        foreach ($obj in $VBMGroupObjectsModification) 
        {
            Logging "Processing Group $($obj.DisplayName)"

            # Initialize array for result logging
            $o = New-Object PSObject -Property @{
            Organization                   = $obj.Organization
            DisplayName                    = $obj.DisplayName
            Email                          = $obj.Email
            RemoveEmail                    = $obj.RemoveEmail
            RemoveEmailTaskId              = $null
            RemoveEmailJobId               = $null
            RemoveEmailResult              = $null
            RemovePersonalSharepoint       = $obj.RemovePersonalSharepoint
            RemovePersonalSharepointTaskId = $null
            RemovePersonalSharepointJobId  = $null
            RemovePersonalSharepointResult = $null
            }
            
            # Group Email removal
            if ($obj.RemoveEmail -eq $true)
                {
                if ($debug -ne $true)
                    {
                    Logging "$($obj.Type) $($obj.DisplayName) - Removing Email back-up from repository $($VBMRepository.Name)"

                    # refresh variables
                    $ObjItem = $null
                    $action = $null

                    # Initialize Veeam task logging
                    $vtl = New-Object PSObject -Property @{
                        Organization = if ($null -eq $VBMOrganization) {$OrganizationName} else {$VBMOrganization.name}
                        Id           = $null
                        JobId        = $null
                        JobName      = $null
                        CreationTime = $null
                        EndTime      = $null
                        Status       = $null
                        Statistics   = $null
                        Log          = $null
                    }

                    # Why on earth would we work with object ID's... Remove-vboentitydata command requires original and complete objectline from output get-vboentitydata -type user.
                    $ObjItem = $VBMGroupObjects | Where-Object {$_.DisplayName -eq $obj.DisplayName -and $_.MailboxBackedUpTime -eq $obj.MailboxBackedUpTime} 
                    $action = Remove-VBOEntityData -Repository $VBMRepository -Group $ObjItem -GroupMailbox -Confirm:$false
                    
                    #log result
                    $o.RemoveEmailTaskId = $action.Id
                    $o.RemoveEmailJobId  = $action.JobId
                    $o.RemoveEmailResult = $action.Status
                    $vtl.Id              = $action.Id
                    $vtl.JobId           = $action.JobId
                    $vtl.JobName         = $action.JobName
                    $vtl.CreationTime    = $action.CreationTime
                    $vtl.EndTime         = $action.EndTime
                    $vtl.status          = $action.Status
                    $vtl.Statistics      = $action.Statistics
                    $vtl.Log             = $action.Log
                    
                    # Add row to report
                    $VeeamTaskLog += $vtl          
                    }
                else 
                    {
                    Logging "DEBUG - $($obj.Type) $($obj.DisplayName) - Removing Email back-up from repository $($VBMRepository.Name)"
                    }   
            }
            
            # Group PersonalSharepoint removal
            if ($obj.RemovePersonalSharepoint -eq $true)
                {
                if ($debug -ne $true)
                    {
                    Logging "$($obj.Type) $($obj.DisplayName) - Removing PersonalSharePoint back-up from repository $($VBMRepository.Name)"

                    # refresh variables
                    $ObjItem = $null
                    $action = $null

                    # Initialize Veeam task logging
                    $vtl = New-Object PSObject -Property @{
                        Organization = if ($null -eq $VBMOrganization) {$OrganizationName} else {$VBMOrganization.name}
                        Id           = $null
                        JobId        = $null
                        JobName      = $null
                        CreationTime = $null
                        EndTime      = $null
                        Status       = $null
                        Statistics   = $null
                        Log          = $null
                    }

                    # Why on earth would we work with object ID's... Remove-vboentitydata command requires original and complete objectline from output get-vboentitydata -type user.
                    $ObjItem = $VBMGroupObjects | Where-Object {$_.DisplayName -eq $obj.DisplayName -and $_.SiteBackedUpTime -eq $obj.SiteBackedUpTime} 
                    $action = Remove-VBOEntityData -Repository $VBMRepository -Group $ObjItem -GroupSite -Confirm:$false
                    
                    #log result
                    $o.RemovePersonalSharepointTaskId = $action.Id
                    $o.RemovePersonalSharepointJobId  = $action.JobId
                    $o.RemovePersonalSharepointResult = $action.Status
                    $vtl.Id                           = $action.Id
                    $vtl.JobId                        = $action.JobId
                    $vtl.JobName                      = $action.JobName
                    $vtl.CreationTime                 = $action.CreationTime
                    $vtl.EndTime                      = $action.EndTime
                    $vtl.status                       = $action.Status
                    $vtl.Statistics                   = $action.Statistics
                    $vtl.Log                          = $action.Log
                    
                    # Add row to report
                    $VeeamTaskLog += $vtl       
                    }
            else
                {
                Logging "DEBUG - $($obj.Type) $($obj.DisplayName) - Removing PersonalSharePoint back-up from repository $($VBMRepository.Name)"
                }
            }  
        # Add row to report
        $VBMGroupReport += $o
        }   
}
else {}

# Sharepoint removal
if ($null -ne $VBMSharepointObjectsModification)
    { 
        # Initialize report array for Sharepoint actions
        $VBMSharePointReport = @()

        foreach ($obj in $VBMSharePointObjectsModification) 
        {
            Logging "Processing Sharepoint $($obj.DisplayName)"

            # Initialize array for result logging
            $o = New-Object PSObject -Property @{
            Organization           = $obj.Organization
            DisplayName            = $obj.DisplayName
            Url                    = $obj.Url
            RemoveSharepoint       = $obj.RemovePersonalSharepoint
            RemoveSharepointTaskId = $null
            RemoveSharepointJobId  = $null
            RemoveSharepointResult = $null
            }
            
            # Sharepoint removal
            if ($obj.RemoveSharepointSite -eq $true)
                {
                if ($debug -ne $true)
                    {
                    Logging "$($obj.Type) $($obj.DisplayName) - Removing Sharepoint back-up from repository $($VBMRepository.Name)"

                    # refresh variables
                    $ObjItem = $null
                    $action = $null

                    # Initialize Veeam task logging
                    $vtl = New-Object PSObject -Property @{
                        Organization = if ($null -eq $VBMOrganization) {$OrganizationName} else {$VBMOrganization.name}
                        Id           = $null
                        JobId        = $null
                        JobName      = $null
                        CreationTime = $null
                        EndTime      = $null
                        Status       = $null
                        Statistics   = $null
                        Log          = $null
                    }

                    # Why on earth would we work with object ID's... Remove-vboentitydata command requires original and complete objectline from output get-vboentitydata -type user.
                    $ObjItem = $VBMSharePointObjects | Where-Object {$_.DisplayName -eq $obj.DisplayName -and $_.BackedUpTime -eq $obj.BackedUpTime} 
                    $action = Remove-VBOEntityData -Repository $VBMRepository -Site $ObjItem -Confirm:$false
                    
                    #log result
                    $o.RemoveSharepointTaskId = $action.Id
                    $o.RemoveSharepointJobId  = $action.JobId
                    $o.RemoveSharepointResult = $action.Status
                    $vtl.Id                   = $action.Id
                    $vtl.JobId                = $action.JobId
                    $vtl.JobName              = $action.JobName
                    $vtl.CreationTime         = $action.CreationTime
                    $vtl.EndTime              = $action.EndTime
                    $vtl.status               = $action.Status
                    $vtl.Statistics           = $action.Statistics
                    $vtl.Log                  = $action.Log
                    
                    # Add row to report
                    $VeeamTaskLog += $vtl       
                    }
            else
                {
                Logging "DEBUG - $($obj.Type) $($obj.DisplayName) - Removing Sharepoint back-up from repository $($VBMRepository.Name)"
                }
            }  
        # Add row to report
        $VBMSharePointReport += $o
        }   
}
else {}

# Teams removal
if ($null -ne $VBMTeamsObjectsModification)
    { 
        # Initialize report array for Sharepoint actions
        $VBMTeamsReport = @()

        foreach ($obj in $VBMTeamsObjectsModification) 
        {
            Logging "Processing Teams $($obj.DisplayName)"

            # Initialize array for result logging
            $o = New-Object PSObject -Property @{
            Organization      = $obj.Organization
            DisplayName       = $obj.DisplayName
            Email             = $obj.Email
            RemoveTeams       = $obj.RemoveTeams
            RemoveTeamsTaskId = $null
            RemoveTeamsJobId  = $null
            RemoveTeamsResult = $null
            }
            
            # Sharepoint removal
            if ($obj.RemoveTeams -eq $true)
                {
                if ($debug -ne $true)
                    {
                    Logging "$($obj.Type) $($obj.DisplayName) - Removing Teams back-up from repository $($VBMRepository.Name)"

                    # refresh variables
                    $ObjItem = $null
                    $action = $null

                    # Initialize Veeam task logging
                    $vtl = New-Object PSObject -Property @{
                        Organization = if ($null -eq $VBMOrganization) {$OrganizationName} else {$VBMOrganization.name}
                        Id           = $null
                        JobId        = $null
                        JobName      = $null
                        CreationTime = $null
                        EndTime      = $null
                        Status       = $null
                        Statistics   = $null
                        Log          = $null
                    }

                    # Why on earth would we work with object ID's... Remove-vboentitydata command requires original and complete objectline from output get-vboentitydata -type user.
                    $ObjItem = $VBMTeamsObjects | Where-Object {$_.DisplayName -eq $obj.DisplayName -and $_.BackedUpTime -eq $obj.BackedUpTime}
                    $action = Remove-VBOEntityData -Repository $VBMRepository -Team $ObjItem -Confirm:$false
                    
                    #log result
                    $o.RemoveTeamsTaskId = $action.Id
                    $o.RemoveTeamsJobId  = $action.JobId
                    $o.RemoveTeamsResult = $action.Status
                    $vtl.Id              = $action.Id
                    $vtl.JobId           = $action.JobId
                    $vtl.JobName         = $action.JobName
                    $vtl.CreationTime    = $action.CreationTime
                    $vtl.EndTime         = $action.EndTime
                    $vtl.status          = $action.Status
                    $vtl.Statistics      = $action.Statistics
                    $vtl.Log             = $action.Log
                    
                    # Add row to report
                    $VeeamTaskLog += $vtl       
                    }
            else
                {
                Logging "DEBUG - $($obj.Type) $($obj.DisplayName) - Removing Teams back-up from repository $($VBMRepository.Name)"
                }
            }  
        
        # Add row to report
        $VBMTeamsReport += $o
        }   
}
else {}

# Display results
Write-host
Write-host "Users - Backup removal report"
Write-host "###############################################################################"
Write-output $VBMuserReport | Select-Object Organization, Email, RemoveEmailResult, RemoveEmailArchiveResult, RemovePersonalSharepointResult, RemoveOneDriveResult | sort-object Email |Format-Table -AutoSize

Write-host
Write-host "Group - Backup removal report"
Write-host "###############################################################################"
Write-output $VBMGroupReport | Select-Object Organization, Email, RemoveEmailResult, RemovePersonalSharepointResult| sort-object Email |Format-Table -AutoSize

Write-host
Write-host "SharePoint - Backup removal report"
Write-host "###############################################################################"
Write-output $VBMSharePointReport | Select-Object Organization, Url,  RemoveSharepointResult | sort-object Url |Format-Table -AutoSize

Write-host
Write-host "Teams - Backup removal report"
Write-host "###############################################################################"
Write-output $VBMTeamsReport | Select-Object Organization, Email, RemoveTeamsResult | sort-object Url |Format-Table -AutoSize

Write-host
Write-host "Veeam Task Log"
Write-host "###############################################################################"
Write-output $VeeamTaskLog | Select-Object Organization, Id, JobId, JobName, CreationTime, EndTime, Status, Statistics, Log | sort-object Organization, CreationTime, Id, JobId | Format-Table -AutoSize

# Export Veeam Task Log
$VeeamTaskLog  | Select-Object Organization, Id, JobId, JobName, CreationTime, EndTime, Status, Statistics, Log | sort-object Organization, CreationTime, Id, JobId | Export-Csv -Path ".\Veeam_task_log_$(get-date -Format "dd-MM-yyyy").csv" -NoTypeInformation
$VeeamTaskLog  | Select-Object Organization, Id, JobId, JobName, CreationTime, EndTime, Status, Statistics, Log | sort-object Organization, CreationTime, Id, JobId | Out-File -FilePath ".\Veeam_task_log_$(get-date -Format "dd-MM-yyyy").log" 
