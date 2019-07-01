<#
.SYNOPSIS  
    PowerShell script to map or unmap an existing vCloud Director Job to it's linked tenant to appear in the vCD Self Service Portal
.DESCRIPTION
    Performs a number of configuration actions against a Veeam Backup & Replication Server as per the included functions.
    - Gets a list of existing vCloud Director jobs
    - Depending on the paramter, will map or unmap the job to the tenant in the vCD SSP
    Note: To be run on a Server installed with the Veeam Backup & Replicaton Console
    Note: Set desired Veeam variables in config.json 
.NOTES
    Version:        1.0
    Author:         Anthony Spiteri
    Twitter:        @anthonyspiteri
    Github:         anthonyspiteri
    Credits:        Luca Dell'Oca @dellock6 (https://www.virtualtothecore.com/automated-veeam-cloud-connect-deployment-5-replication-services-for-vcloud-director)
                    Show-Options
                    Get-Userchoice
    
.LINK
    
.EXAMPLE
        PS C:\>vCD_job -map
        PS C:\>vCD_job -unmap
#>

[CmdletBinding()]

    Param
    (
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [Switch]$map,

        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [Switch]$unmap
    )

if (!$RunAll -and !$map -and !$unmap)
    {
        Write-Host ""
        Write-Host ":: - ERROR! Script was run without using a parameter..." -ForegroundColor Red -BackgroundColor Black
        Write-Host ":: - Please use: -map or -unmap" -ForegroundColor Yellow -BackgroundColor Black 
        Write-Host ""
        break
    }

#Get Variables from Master Config
$config = Get-Content config.json | ConvertFrom-Json

#To be run on Server installed with Veeam Backup & Replicaton Console
if (!(get-pssnapin -name VeeamPSSnapIn -erroraction silentlycontinue)) 
        {
         add-pssnapin VeeamPSSnapIn
        }

function Connect-VBR-Server
        {
            #Connect to the Backup & Replication Server
            Disconnect-VBRServer
            Connect-VBRServer -Server $config.VBRDetails.VBRServer -user $config.VBRDetails.Username -password $config.VBRDetails.Password 
        }

function Show-Options
    {
        [CmdletBinding()]
            param
            (
               [Parameter(Mandatory = $true)]
               [string]
               $Message,
                    
               [Parameter(Mandatory = $true)]
               [string[]]
               $Options
            )

    Write-Host -Object "`n$Message`n"

    foreach ($option in $Options)
        {
            Write-Host -Object "`t[$($Options.IndexOf($option) + 1)] $($option)"
        }
    }
function Get-UserChoice
    {
        [CmdletBinding()]
            param
            (
                [Parameter(Mandatory = $true)]
                [string]
                $Message,

                [Parameter(Mandatory = $true)]
                [string[]]
                $Options
            )

        $inputIsValid = $false

        do
            {
                try { [int]$userInput = (Read-Host -Prompt "`n$Message") }
                catch 
                    {
                        Write-Host -Object "Invalid input! Must be an integer."
                        continue
                    }
                if ($userInput -ge 1 -and $userInput -le $Options.Length)
                    {
                        $inputIsValid = $true
                    }
                else
                    {
                        Write-Host -Object "Invalid input! Must be in the range 1..$($Options.Length)."
                    }
            }
            until ($inputIsValid)
            return $userInput - 1
    }
 
function MapUnMapvCDJob 
    {
        #Get Existing vCD Job
        $all_jobs = Get-VBRJob | ?{$_.TypeToString -eq "vCloud Backup"}
        Show-Options -Message "Existing vCloud Backup Jobs:" -Options $all_jobs.Name
        $vcd_job = Get-UserChoice -Message "Choose a vCloud Job" -Options $all_jobs
        $job = $all_jobs[$vcd_job]

        if($map)
            {
                try { Set-VBRvCloudOrganizationJobMapping -Action Map -Job $job -ErrorAction stop -verbose
                    Write-Host ""
                    Write-Host "vCloud Job"$all_jobs[$vcd_job].name"Mapped" -ForegroundColor Green -BackgroundColor Black
                    Write-Host "" }
                    catch 
                        {
                        Write-Host ""
                        write-host $_.Exception.Message`n -ForegroundColor Red -BackgroundColor Black
                        continue 
                        }
            }
        if($unmap)
            {
                try { Set-VBRvCloudOrganizationJobMapping -Action UnMap -Job $job -ErrorAction stop -verbose
                    Write-Host ""
                    Write-Host "vCloud Job"$all_jobs[$vcd_job].name"UnMapped" -ForegroundColor Green -BackgroundColor Black
                    Write-Host "" }
                    catch 
                        {
                        Write-Host ""
                        write-host $_.Exception.Message`n -ForegroundColor Red -BackgroundColor Black
                        continue 
                        }
            }
    }

#Run Functions
Connect-VBR-Server
MapUnMapvCDJob