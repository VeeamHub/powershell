<#
.SYNOPSIS  
    PowerShell script to configure a freshly installed Veeam Backup & Replication Server ready for use with local and cloud based repositories with default Tag based Backup Job Policies created
.DESCRIPTION
    Performs a number of configuration actions against a Veeam Backup & Replication Server as per the included functions.

    - Attach a vCenter
    - Add and configure Cloud Connect Backup and/or Replication Provider
    - Add and configure a Linux Based Repository
    - Create vSphere Tag Catagories and Tags
    - Create a set of default Tag Based Policy Backup Jobs
    - Clears all configured settings

    Note: To be run on a Server installed with the Veeam Backup & Replicaton Console
    Note: There is no error checking or halt on error function
    Note: Set desired Veeam and vCenter variables in config.json 
.NOTES
    Version:        1.0
    Author:         Anthony Spiteri
    Twitter:        @anthonyspiteri
    Github:         anthonyspiteri
    
.LINK
    
.PARAMETER Runall
        Runs all the functions
.PARAMETER CloudConnectOnly
        Runs all the functions to configure the Veeam Backup & Replication Server
.PARAMETER RunVBRConfigure
        Runs all the functions to configure the Veeam Backup & Replication Server
.PARAMETER CloudConnectNEA
        When used with RunAll or RunVBRConfigure will deploy and configure the Cloud Connect Network Extension Appliance
.PARAMETER NoCloudConnect
        When used with RunAll or RunVBRConfigure will not configure the Cloud Connect component
.PARAMETER NoLinuxRepo
        When used with RunAll or RunVBRConfigure will not add and configure the Linux Repository
.PARAMETER ClearVBRConfig
        Will clear all previously configured settings and return Veeam Backup & Replication Server to default install
.EXAMPLE
        PS C:\>configure_veeam.ps1 -RubVBRConfigure -NoLinuxRepo
.EXAMPLE
        PS C:\>configure_veeam.ps1 -ClearVBRConfig
#>

[CmdletBinding()]

    Param
    (
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [Switch]$RunAll,

        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [Switch]$RunVBRConfigure,

        [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$CloudConnectNEA,

        [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$NoCloudConnect,

        [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$CloudConnectOnly,

        [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true)]
        [Switch]$NoLinuxRepo,

        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [Switch]$ClearVBRConfig
    )

if (!$RunAll -and !$RunVBRConfigure -and !$ClearVBRConfig)
    {
        Write-Host ""
        Write-Host ":: - ERROR! Script was run without using a parameter..." -ForegroundColor Red -BackgroundColor Black
        Write-Host ":: - Please use: -RunAll, -RunVBRConfigure or -ClearVBRConfig" -ForegroundColor Yellow -BackgroundColor Black 
        Write-Host ""
        break
    }

$StartTime = Get-Date

#To be run on Server installed with Veeam Backup & Replicaton Console
if (!(get-pssnapin -name VeeamPSSnapIn -erroraction silentlycontinue)) 
        {
         add-pssnapin VeeamPSSnapIn
        }

#Check for VMware PowerCLI and Install and Import if missing
if (!(Get-Module VMware.PowerCLI -erroraction silentlycontinue)) 
        {
        #Install-Module VMware.PowerCLI -Force | Out-Null
        Import-Module VMware.PowerCLI | Out-Null
        }

#Get Variables from Master Config
$config = Get-Content config.json | ConvertFrom-Json

function Pause
    {
        write-Host ""
        write-Host ":: Press Enter to continue..." -ForegroundColor Yellow -BackgroundColor Black
        Read-Host | Out-Null 
    }

function Connect-VBR-Server
    {
        #Connect to the Backup & Replication Server
        Disconnect-VBRServer
        Connect-VBRServer -Server $config.VBRCredentials.VBRServer -user $config.VBRCredentials.Username -password $config.VBRCredentials.Password 
    }

function Add-vCenter    
    {
        Write-Host ":: Adding vCenter to Backup & Replication" -ForegroundColor Green
        Add-VBRvCenter -Name $config.VMCCredentials.vCenter -User $config.VMCCredentials.Username -Password $config.VMCCredentials.Password -WarningAction SilentlyContinue | Out-Null     
    }

function Add-VCC-Provider 
    {
        $host.ui.RawUI.WindowTitle = "Adding Cloud Connect Service Provider"
        
        #Add Cloud Connect User Account from Service Provider Cloud
        Write-Host ":: Adding Cloud Connect Tenant to Stored Credentials" -ForegroundColor Green
        Add-VBRCredentials -User $config.VCCProvider.CCUserName -Password $config.VCCProvider.CCPassword -Description $config.VCCProvider.CCUserName | Out-Null

        #Set the Cloud Connect User Account credentials
        $credentials = Get-VBRCredentials -Name $config.VCCProvider.CCUserName

        #Add the Cloud Provider into Veeam Backup & Replication
        Write-Host ":: Adding Cloud Connect Service Provider Endpoint and Backup Repository" -ForegroundColor Green

        if ($CloudConnectNEA)
            {
                #Get NEA Paramaters
                $NEAHost = Get-VBRServer -Name $config.VCCProvider.ESXiHost
                $NEANetwork = Get-VBRViServerNetworkInfo -Server $NEAHost | Where { $_.Type -eq "ViDVS" -and $_.SwitchName -eq $config.VCCProvider.vCenterDVS -and $_.NetworkName -eq $config.VCCProvider.vCenterPortGroup }
                $NEAResPool = Find-VBRViResourcePool -Server $NEAHost -Name $config.VCCProvider.vCenterResPool
                $NEADatastore = Find-VBRViDatastore -Server $NEAHost -Name $config.VCCProvider.vCenterDatastore

                Write-Host ":: Setting Network Extension Appliance Details" -ForegroundColor Green
                $NEA = New-VBRCloudProviderNetworkAppliance -Server $NEAHost -ResourcePool $NEAResPool -Network $NEANetwork -IpAddress $config.VCCProvider.NEAIPAddress -SubnetMask $config.VCCProvider.NEASubnetMask -DefaultGateway $config.VCCProvider.NEAGateway -Datastore $NEADatastore

                Add-VBRCloudProvider -Address $config.VCCProvider.CCServerAddress -Port $config.VCCProvider.CCPort -VerifyCertificate:$false -Credentials $credentials -Appliance $NEA -Force -WarningAction SilentlyContinue | Out-Null
            }
        else 
            {
                Add-VBRCloudProvider -Address $config.VCCProvider.CCServerAddress -Port $config.VCCProvider.CCPort -VerifyCertificate:$false -Credentials $credentials -Force -WarningAction SilentlyContinue | Out-Null
            }      
    }

function Add-Linux-Repo 
    {
        $host.ui.RawUI.WindowTitle = "Configuring Veeam Linux Repository"

        #Get Variables from Master Config
        $config = Get-Content config.json | ConvertFrom-Json

        #Add Linux Public Key Credential
        Add-VBRCredentials -Type LinuxPubKey -User $config.LinuxRepo.Username -PrivateKeyPath $config.LinuxRepo.Key -Password "" -ElevateToRoot | Out-Null

        #Get Linux Credential
        $LinuxCredential = Get-VBRCredentials -Name $config.LinuxRepo.Username

        #Add Linux Instance to Backup & Replication
        Write-Host ":: Adding Linux Server to Backup & Replication" -ForegroundColor Green
        Add-VBRLinux -Name $config.LinuxRepo.IpAddress -Description "Linux Repository" -Credentials $LinuxCredential -WarningAction SilentlyContinue | Out-Null

        #Add Linux Repository to Backup & Replication
        Write-Host ":: Creating New Linux Backup Repository" -ForegroundColor Green
        Add-VBRBackupRepository -Name $config.LinuxRepo.RepoName -Description "AWS Linux Repository" -Type LinuxLocal -Server $config.LinuxRepo.IpAddress -Folder $config.LinuxRepo.RepoFolder -Credentials $LinuxCredential | Out-Null
    }

function Create-vSphereTags

    {
        $host.ui.RawUI.WindowTitle = "Creating vCenter Tags"

        Connect-VIServer -Server $config.VMCCredentials.vCenter -User $config.VMCCredentials.Username -Password $config.VMCCredentials.Password -Force | Out-Null
        
        Write-Host ":: Creating VMware Tag Catagories" -ForegroundColor Green
        New-TagCategory -Name $config.VBRJobDetails.TagCatagory1 -Cardinality "Single" -EntityType "VirtualMachine" -Description "Backup Jobs Policy Tag" | Out-Null
        New-TagCategory -Name $config.VBRJobDetails.TagCatagory2 -Cardinality "Single" -EntityType "VirtualMachine" -Description "Backup Jobs Policy Tag" | Out-Null
        
        Write-Host ":: Creating VMware Tags" -ForegroundColor Green
        New-Tag -Name $config.VBRJobDetails.Tag1 -Category $config.VBRJobDetails.TagCatagory2 | Out-Null
        New-Tag -Name $config.VBRJobDetails.Tag2 -Category $config.VBRJobDetails.TagCatagory1 | Out-Null
        New-Tag -Name $config.VBRJobDetails.Tag3 -Category $config.VBRJobDetails.TagCatagory1 | Out-Null
    }

function Create-VBRJobs
    {   
        $host.ui.RawUI.WindowTitle = "Creating Veeam Backup & Replication Jobs"

        if (!$NoLinuxRepo -and !$NoCloudConnect)
            {
                $BackupRepo1 = $config.LinuxRepo.RepoName
                $BackupRepo2 = $config.VCCProvider.CCRepoName
            }
        elseif ($NoLinuxRepo -and !$NoCloudConnect)
            {
                $BackupRepo1 = $config.VBRJobDetails.DefaultRepo1
                $BackupRepo2 = $config.VCCProvider.CCRepoName  
            }
        elseif (!$NoLinuxRepo -and $NoCloudConnect)
            {
                $BackupRepo1 = $config.LinuxRepo.RepoName
                $BackupRepo2 = $config.VBRJobDetails.DefaultRepo1 
            }    
        else
            {
                $BackupRepo1 = $config.VBRJobDetails.DefaultRepo1
                $BackupRepo2 = $config.VBRJobDetails.DefaultRepo1   
            }
               
        Write-Host ":: Creating Tag Based Policy Backup Job 1" -ForegroundColor Green
        Add-VBRViBackupJob -Name $config.VBRJobDetails.Job2 -BackupRepository $BackupRepo1 -Entity (Find-VBRViEntity -Tags -Name $config.VBRJobDetails.Tag2) | Out-Null
        Write-Host ":: Creating Tag Based Policy Backup Job 2" -ForegroundColor Green
        Add-VBRViBackupJob -Name $config.VBRJobDetails.Job3 -BackupRepository $BackupRepo2 -Entity (Find-VBRViEntity -Tags -Name $config.VBRJobDetails.Tag3) | Out-Null
        
        Write-Host ":: Setting Retention Policy Backup Jobs" -ForegroundColor Green
        $JobOptions = Get-VBRJobOptions $config.VBRJobDetails.Job2
        $JobOptions.BackupStorageOptions.RetainCycles = $config.VBRJobDetails.RestorePoints1 
        $config.VBRJobDetails.Job2 | Set-VBRJobOptions -Options $JobOptions | Out-Null

        $JobOptions = Get-VBRJobOptions $config.VBRJobDetails.Job3
        $JobOptions.BackupStorageOptions.RetainCycles = $config.VBRJobDetails.RestorePoints2
        $config.VBRJobDetails.Job3 | Set-VBRJobOptions -Options $JobOptions | Out-Null
        
        Get-VBRJob -Name $config.VBRJobDetails.Job2 | Set-VBRJobAdvancedBackupOptions -Algorithm Incremental -TransformFullToSyntethic $False -EnableFullBackup $True -FullBackupDays $config.VBRJobDetails.FullDay | Out-Null
        Get-VBRJob -Name $config.VBRJobDetails.Job3 | Set-VBRJobAdvancedBackupOptions -Algorithm Incremental -TransformFullToSyntethic $False -EnableFullBackup $True -FullBackupDays $config.VBRJobDetails.FullDay | Out-Null
        
        Write-Host ":: Setting Schedule for Backup Jobs" -ForegroundColor Green
        Get-VBRJob -Name $config.VBRJobDetails.Job2 | Set-VBRJobSchedule -Daily -At $config.VBRJobDetails.Time1 | Out-Null
        Get-VBRJob -Name $config.VBRJobDetails.Job2 | Enable-VBRJobSchedule | Out-Null

        Write-Host ":: Enabling Backup Jobs" -ForegroundColor Green
        Get-VBRJob -Name $config.VBRJobDetails.Job3 | Set-VBRJobSchedule -Daily -At $config.VBRJobDetails.Time2 | Out-Null
        Get-VBRJob -Name $config.VBRJobDetails.Job3 | Enable-VBRJobSchedule | Out-Null
    }

function ClearVBRConfig

    {
        #Clear all the Backup & Replication Configuration

        $host.ui.RawUI.WindowTitle = "Clearing the Veeam Backup & Replication Configuration"

        Connect-VBR-Server
        
        $config = Get-Content config.json | ConvertFrom-Json

        #Clear Jobs
        Get-VBRJob -Name $config.VBRJobDetails.Job1 | Remove-VBRJob -Confirm:$false -WarningAction SilentlyContinue | Out-Null
        Get-VBRJob -Name $config.VBRJobDetails.Job2 | Remove-VBRJob -Confirm:$false -WarningAction SilentlyContinue | Out-Null
        Get-VBRJob -Name $config.VBRJobDetails.Job3 | Remove-VBRJob -Confirm:$false -WarningAction SilentlyContinue | Out-Null

        #Clear Linux Repo and Server
        Get-VBRBackupRepository -Name $config.LinuxRepo.RepoName | Remove-VBRBackupRepository -Confirm:$false -WarningAction SilentlyContinue | Out-Null
        Get-VBRServer -Type Linux | Remove-VBRServer -Confirm:$false -WarningAction SilentlyContinue | Out-Null

        #Clear Cloud Connect Provider
        Get-VBRCloudProvider -Name $config.VCCProvider.CCServerAddress | Remove-VBRCloudProvider -Confirm:$false -WarningAction SilentlyContinue | Out-Null

        #Clear vCenter Server
        Get-VBRServer -Type VC -Name $config.VMCCredentials.vCenter | Remove-VBRServer -Confirm:$false -WarningAction SilentlyContinue | Out-Null

        #Clear Credentials
        Get-VBRCredentials -Name $config.VMCCredentials.Username | Remove-VBRCredentials -Confirm:$false -WarningAction SilentlyContinue | Out-Null
        Get-VBRCredentials -Name $config.VCCProvider.CCUserName | Remove-VBRCredentials -Confirm:$false -WarningAction SilentlyContinue | Out-Null
        Get-VBRCredentials -Name $config.LinuxRepo.Username | Remove-VBRCredentials -Confirm:$false -WarningAction SilentlyContinue | Out-Null

        #Clear vCenter Tags and Tag Categories
        get-tag $config.VBRJobDetails.Tag1 | Remove-Tag -Confirm:$false | Out-Null
        get-tag $config.VBRJobDetails.Tag2 | Remove-Tag -Confirm:$false | Out-Null
        get-tag $config.VBRJobDetails.Tag3 | Remove-Tag -Confirm:$false | Out-Null

        Get-TagCategory $config.VBRJobDetails.TagCatagory1 | Remove-TagCategory -Confirm:$false | Out-Null
        Get-TagCategory $config.VBRJobDetails.TagCatagory2 | Remove-TagCategory -Confirm:$false | Out-Null
    }

#Execute Functions

if ($RunAll){
    #Run the code for run all

    $StartTimeVB = Get-Date
    Connect-VBR-Server
    Write-Host ""
    Write-Host ":: - Connected to Backup & Replication Server - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeVB = Get-Date
    $durationVB = [math]::Round((New-TimeSpan -Start $StartTimeVB -End $EndTimeVB).TotalMinutes,2)
    Write-Host "Execution Time" $durationVB -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
    
    $StartTimeVC = Get-Date
    Add-vCenter
    Write-Host ""
    Write-Host ":: - vCenter added to Backup & Replication - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeVC = Get-Date
    $durationVC = [math]::Round((New-TimeSpan -Start $StartTimeVC -End $EndTimeVC).TotalMinutes,2)
    Write-Host "Execution Time" $durationVC -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
    
    $StartTimeVCC = Get-Date
    Add-VCC-Provider
    Write-Host ""
    Write-Host ":: - Veeam Cloud Connect Service Provider Configured - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeVCC = Get-Date
    $durationVCC = [math]::Round((New-TimeSpan -Start $StartTimeVCC -End $EndTimeVCC).TotalMinutes,2)
    Write-Host "Execution Time" $durationVCC -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
    
    $StartTimeLR = Get-Date
    Add-Linux-Repo
    Write-Host ""
    Write-Host ":: - Veeam Linux Repository Configured - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeLR = Get-Date
    $durationLR = [math]::Round((New-TimeSpan -Start $StartTimeLR -End $EndTimeLR).TotalMinutes,2)
    Write-Host "Execution Time" $durationLR -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
    
    $StartTimeTG = Get-Date
    Create-vSphereTags
    Write-Host ""
    Write-Host ":: - vSphere Tags Created - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeTG = Get-Date
    $durationTG = [math]::Round((New-TimeSpan -Start $StartTimeTG -End $EndTimeTG).TotalMinutes,2)
    Write-Host "Execution Time" $durationTG -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
    
    $StartTimeJB = Get-Date
    Create-VBRJobs
    Write-Host ""
    Write-Host ":: - Backup Jobs Configured - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeJB = Get-Date
    $durationJB = [math]::Round((New-TimeSpan -Start $StartTimeJB -End $EndTimeJB).TotalMinutes,2)
    Write-Host "Execution Time" $durationJB -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
}

if ($CloudConnectOnly){
    #Run Code to Configure Cloud Connect Only
    $StartTimeVB = Get-Date
    Connect-VBR-Server
    Write-Host ""
    Write-Host ":: - Connected to Backup & Replication Server - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeVB = Get-Date
    $durationVB = [math]::Round((New-TimeSpan -Start $StartTimeVB -End $EndTimeVB).TotalMinutes,2)
    Write-Host "Execution Time" $durationVB -ForegroundColor Green -BackgroundColor Black
    Write-Host ""

    $StartTimeVCC = Get-Date
    Add-VCC-Provider
    Write-Host ""
    Write-Host ":: - Veeam Cloud Connect Service Provider Configured - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeVCC = Get-Date
    $durationVCC = [math]::Round((New-TimeSpan -Start $StartTimeVCC -End $EndTimeVCC).TotalMinutes,2)
    Write-Host "Execution Time" $durationVCC -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
}

if ($RunVBRConfigure){
    #Run the code for VBR configure

    $StartTimeVB = Get-Date
    Connect-VBR-Server
    Write-Host ""
    Write-Host ":: - Connected to Backup & Replication Server - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeVB = Get-Date
    $durationVB = [math]::Round((New-TimeSpan -Start $StartTimeVB -End $EndTimeVB).TotalMinutes,2)
    Write-Host "Execution Time" $durationVB -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
    
    $StartTimeVC = Get-Date
    Add-vCenter
    Write-Host ""
    Write-Host ":: - vCenter added to Backup & Replication - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeVC = Get-Date
    $durationVC = [math]::Round((New-TimeSpan -Start $StartTimeVC -End $EndTimeVC).TotalMinutes,2)
    Write-Host "Execution Time" $durationVC -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
    
    if (!$NoCloudConnect)
        {
            $StartTimeVCC = Get-Date
            Add-VCC-Provider
            Write-Host ""
            Write-Host ":: - Veeam Cloud Connect Service Provider Configured - ::" -ForegroundColor Green -BackgroundColor Black
            $EndTimeVCC = Get-Date
            $durationVCC = [math]::Round((New-TimeSpan -Start $StartTimeVCC -End $EndTimeVCC).TotalMinutes,2)
            Write-Host "Execution Time" $durationVCC -ForegroundColor Green -BackgroundColor Black
            Write-Host ""
        }
    
    if (!$NoLinuxRepo)
        {  
            $StartTimeLR = Get-Date
            Add-Linux-Repo
            Write-Host ""
            Write-Host ":: - Veeam Linux Repository Configured - ::" -ForegroundColor Green -BackgroundColor Black
            $EndTimeLR = Get-Date
            $durationLR = [math]::Round((New-TimeSpan -Start $StartTimeLR -End $EndTimeLR).TotalMinutes,2)
            Write-Host "Execution Time" $durationLR -ForegroundColor Green -BackgroundColor Black
            Write-Host ""
        }

    $StartTimeTG = Get-Date
    Create-vSphereTags
    Write-Host ""
    Write-Host ":: - vSphere Tags Created - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeTG = Get-Date
    $durationTG = [math]::Round((New-TimeSpan -Start $StartTimeTG -End $EndTimeTG).TotalMinutes,2)
    Write-Host "Execution Time" $durationTG -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
    
    $StartTimeJB = Get-Date
    Create-VBRJobs
    Write-Host ""
    Write-Host ":: - Backup Jobs Configured - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeJB = Get-Date
    $durationJB = [math]::Round((New-TimeSpan -Start $StartTimeJB -End $EndTimeJB).TotalMinutes,2)
    Write-Host "Execution Time" $durationJB -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
}

if ($CloudConnectOnly){
    #Run Code to Configure Cloud Connect Only
    $StartTimeVB = Get-Date
    Connect-VBR-Server
    Write-Host ""
    Write-Host ":: - Connected to Backup & Replication Server - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeVB = Get-Date
    $durationVB = [math]::Round((New-TimeSpan -Start $StartTimeVB -End $EndTimeVB).TotalMinutes,2)
    Write-Host "Execution Time" $durationVB -ForegroundColor Green -BackgroundColor Black
    Write-Host ""

    $StartTimeVCC = Get-Date
    Add-VCC-Provider
    Write-Host ""
    Write-Host ":: - Veeam Cloud Connect Service Provider Configured - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeVCC = Get-Date
    $durationVCC = [math]::Round((New-TimeSpan -Start $StartTimeVCC -End $EndTimeVCC).TotalMinutes,2)
    Write-Host "Execution Time" $durationVCC -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
}

if ($ClearVBRConfig){
    #Run the code for VBR Clean

    $StartTimeCL = Get-Date
    ClearVBRConfig
    Write-Host ""
    Write-Host ":: - Clearing Backup & Replication Server Configuration - ::" -ForegroundColor Green -BackgroundColor Black
    $EndTimeCL = Get-Date
    $durationCL = [math]::Round((New-TimeSpan -Start $StartTimeCL -End $EndTimeCL).TotalMinutes,2)
    Write-Host "Execution Time" $durationCL -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
}

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)

$host.ui.RawUI.WindowTitle = "AUTOMATION AND ORCHESTRATION COMPLETE"
Write-Host "Total Execution Time" $duration -ForegroundColor Green -BackgroundColor Black
Write-Host