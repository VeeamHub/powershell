<# 
   .Synopsis 
    Combines all selected tags of VMs to an special helper tag for backup assignment
   .Example 
	Run the code on the backup server
   .Notes 
    NAME       : combine-tags.ps1
    Author     : Marco Horstmann, Veeam Software GmbH (marco.horstmann@veeam.com)
    LASTEDIT   : 12-07-2017 
    KEYWORDS   : Veeam, Tags
 #> 
 
#
# CONFIGURATION SECTION
#

# Enter vCenter Name or IP adresss

$config_vcenter = "mho-vc01";

# Enter vCenter username

$config_vcenter_user = "Administrator@vsphere.local";

# Enter vCenter password

$config_vcenter_pass = "Veeam4all!";

# Enter here a tag category e.g. "RPO" where all VMs which should be processed by this script
# should have a tag from e.g "RPO 24 Hours". All other VMs without a tag from this category will
# be skipped.
$selectvmsbycategory = "RPO"

# Enter here the tag categories that should be used for generating the helper tags.
#
$usedtagcategorys = "RPO","Backup Encryption","VM purpose"

# Category name for the automatically created tags. This should be a
# free category, because this script automatically will create it.
# CAUTION: If you change this tag category name after first run it can create a mess of tags.
$tagcategory = "Backup-Job"

# Prefix for the automatically created Tags used for backup selection
$jobprefix = "Job"

##########################################################################
###                                                                    ###
### PLEASE DO NOT CHANGE ANYTHING BELOW THIS BOX, BECAUSE ANY CHANGE   ###
### CAN BREAK THIS SCRIPT. BUT MAYBE YOU HAVE SOME IDEAS TO IMPROVE IT ###
###                                                                    ###
##########################################################################

### CODE Section

# Adding PS Snapins for Veeam and VMware
try {  
   add-pssnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue
} catch {  
   throw $_.Exception.Message
   exit
}  

# Connection to vCenter
try {  
   Connect-VIServer -Server $config_vcenter -User $config_vcenter_user -Password $config_vcenter_pass;
} catch {  
   throw $_.Exception.Message
   exit
}  

# Future improvement comment:
# Maybe an option to check for previous tags if they category was renamed later
# Get-TagCategory | Where { $_.Description -EQ "VEEAM Automatic Backup Job Tags" }

# If configured Category for Backup-Job tags doesn't exist, it will be created
if(Get-TagCategory -Name $tagcategory -ErrorAction SilentlyContinue) {
    echo "Tag catagory $tagcategory already exists. SKIPPING";
}
else {
    echo "Tag catagory $tagcategory doesn't exist. CREATING";
    New-TagCategory -Name $tagcategory -Cardinality Single -EntityType VM -Description "VEEAM Automatic Backup Job Tags";
}


$listofvmtags = @()

#Get all VMs which have a tag from configured tag category
$vms = Get-VM | where {(Get-TagAssignment -Entity $_ -Category $selectvmsbycategory)}

$vms | ForEach {
    #Create new String with configured Job Prefix
    [string]$actualvmtag = $jobprefix
    $actualvm = $_.Name
    # Get all tags for this VM, sort them and create a loop
    Get-TagAssignment -Entity $_ | sort -Property Tag | ForEach {
            # Skip all unused categories
            if( $usedtagcategorys -contains $_.Tag.Category ) { 
                # Add this tag to the generated tag for this vm
                $actualvmtag += "-"
                $actualvmtag += $_.Tag.Name
            }
        }
        #Write-Host "----------------------------"
        Write-Host "The Tag $actualvmtag for VM $actualvm will be created, if it not already exists"
        # Add the generated helper tag to the array with tags which will be needed 
        $listofvmtags += $actualvmtag
 }




# For each tag combination create a own helper tag
$listofvmtags |  Get-Unique –AsString | foreach {
    # If helper tag doesn't exist create it otherwise skip it.
    if(Get-Tag -Name $_ -ErrorAction SilentlyContinue) {
        echo "Tag $_ already exists. SKIPPING";
    }
    else {
        echo "Tag $_ doesn't exist. CREATING";
        New-Tag -Name $_ -Description "VEEAM Automatic Backup Job $_" -Category "$tagcategory";
    }
    
}

$vms | ForEach {
    #Create new String with configured Job Prefix
    [string]$actualvmtag = $jobprefix
    $actualvm = $_.Name
    # Get all tags for this VM, sort them and create a loop
    Get-TagAssignment -Entity $_ | sort -Property Tag | ForEach {
            # Skip all unused categories
            if( $usedtagcategorys -contains $_.Tag.Category ) { 
                $actualvmtag += "-"
                $actualvmtag += $_.Tag.Name
            }    
    }
    Write-Host "----------------------------"
    Write-Host Der VM $actualvm bekommt den Tag $actualvmtag zugewiesen
    if(!(Get-VM -Name $_.Name | New-TagAssignment –Tag $actualvmtag -ErrorAction SilentlyContinue)) {
        Get-VM -Name $_.Name | Get-TagAssignment -Category $tagcategory | Remove-TagAssignment -Confirm:$false
        Get-VM -Name $_.Name | New-TagAssignment –Tag $actualvmtag
        }        
 }
