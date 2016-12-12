<# 
   .Synopsis 
    Combines any combination of given tags to create new tags for backup assignment
   .Example 
	Run the code on the backup server
   .Notes 
    NAME: combine-tags.ps1
    AUTHOR: Marco Horstmann, Veeam
    LASTEDIT: 09-12-2016 
    KEYWORDS: Veeam, Tags
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

# To add new tags please update your line like this example.
# Later all tags will be automatically sorted and converted to lowercase
# $usedtags = @("MSSQL","ORACLE","Windows","EXAMPLE1", "EXAMPLE2");

$usedtags = @("MSSQL", "ORACLE", "Windows", "encrypted");

# Category name for the automatically created tags. This should be a
# free category, because this script automatically will create it. 
$tagcategory = "Backup-Job"

##########################################################################
###                                                                    ###
### PLEASE DO NOT CHANGE ANYTHING BELOW THIS BOX, BECAUSE ANY CHANGE   ###
### CAN BREAK THIS SCRIPT. BUT MAYBE YOU HAVE SOME IDEAS TO IMPROVE IT ###
###                                                                    ###
##########################################################################

### CODE Section

# Adding PS Snapins for Veeam and VMware
add-pssnapin VMware.VimAutomation.Core;
#Currently not used
#Add-PSSnapin VeeamPSSnapin;

# Connection to vCenter
Connect-VIServer -Server $config_vcenter -User $config_vcenter_user -Password $config_vcenter_pass;

# Formating the $usedtags variable
# 1. Sorting the array and converting to lowercase
# 2. Remove multiple entered tags
$usedtags = $usedtags | sort | % { $_.ToLower() }
$usedtags = $usedtags | Select-Object -Unique

# Define a function to build for all tag combinations. 
function Get-Tagnames($a) {
    #create an array to store output
    $l = @()
    #for any set of length n the maximum number of subsets is 2^n
    for ($i = 0; $i -lt [Math]::Pow(2,$a.Length); $i++)
    { 
        #temporary array to hold output
        [string[]]$out = New-Object string[] $a.length
        #iterate through each element
        for ($j = 0; $j -lt $a.Length; $j++)
        { 
            #start at the end of the array take elements, work your way towards the front
            if (($i -band (1 -shl ($a.Length - $j - 1))) -ne 0)
            {
                #store the subset in a temp array
                $out[$j] = $a[$j]
            }
            if($out[$j] -notlike "") {
                #if(!(($j -eq ($a.Length)-1))) {
                    $out[$j] = $out[$j] + "-"
                #}
            }
        }
        #add this combination into the array
        $l += -join $out
    }
    $jobtags = @()
    foreach($k IN $l) {
    #Removes a dash at the end and joins it into a tagname "JOB-tag1-tag2-..."
    if($k.Length -gt 0) {
            $k = $k.Substring(0,$k.Length-1)
            $jobtags += "JOB-" + $k
        }
    }
    # Sort the generated tags and return this as outcome of this fuction
    $l = $jobtags
    $l | Group-Object -Property Length| %{$_.Group | sort } | sort
    }

# Save generated tags into array $jobtags
$jobtags = Get-Tagnames($usedtags)

echo "*****************************************************";
echo "This combination was detected and will be now created";
echo $jobtags;
echo "*****************************************************";

# If configured Category for Backup-Job tags doesn't exist, it will be created
if(Get-TagCategory -Name $tagcategory -ErrorAction SilentlyContinue) {
    echo "Tag catagory $tagcategory already exists. SKIPPING";
}
else {
    echo "Tag catagory $tagcategory doesn't exist. CREATING";
    New-TagCategory -Name $tagcategory -Cardinality Single -EntityType VM -Description "VEEAM Automatic Backup Job Tags";
}

# For each tag combination create a own helper tag
$jobtags | foreach {
    # If helper tag doesn't exist create it otherwise delete it.
    if(Get-Tag -Name $_ -ErrorAction SilentlyContinue) {
        echo "Tag $_ already exists. SKIPPING";
    }
    else {
        echo "Tag $_ doesn't exist. CREATING";
        New-Tag -Name $_ -Description "VEEAM Automatic Backup Job $_" -Category "$tagcategory";
    }
    
}

# Getting VMs with one of this tags from vSphere
$vms = Get-VM -Tag $usedtags | Select Name,@{N="Tags";E={Get-TagAssignment -Entity $_ }}
#Loop for every VM in this array
foreach($vm in $vms) {
    #Make sure flags variable is not existing
    Remove-Variable -Name flags -ErrorAction SilentlyContinue
    $flags = @()
    $vmtags = $vm.Tags
    # Each tag a VM has needs to be checked if it is used in this script.
    foreach ($vmtag in $vmtags) {
        if($usedtags -contains $vmtag.Tag.Name) {
            $flags += $vmtag.Tag.Name.ToLower();
        }
    }
    # Sort all tags for a VM to create a tag combination
    $flags = $flags | sort
    # Joins all tags with a dash e.g. tag1-tag2-tag3 
    $flagsjoined = $flags -join '-'
    # Add Prefix to the tag combination e.g. JOB-tag1-tag2-tag3
    $flagsjoined = "JOB-" + $flagsjoined
    # If we are not able to assign a tag here then there is already a tag assigned. We will remove this
    # tag and assign a new one. this can happen, when a new tag is $usedtags or a new tag was assigned to VM  
    if(!(Get-VM -Name $vm.Name | New-TagAssignment –Tag $flagsjoined -ErrorAction SilentlyContinue)) {
        Get-VM -Name $vm.Name | Get-TagAssignment -Category $tagcategory | Remove-TagAssignment -Confirm:$false
        Get-VM -Name $vm.Name | New-TagAssignment –Tag $flagsjoined
        }
}
