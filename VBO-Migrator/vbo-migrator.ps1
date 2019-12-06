<# 
.NAME
    Veeam Backup for Microsoft Office 365 Data Migrator
.SYNOPSIS
    Leverage this free tool to move Veeam Backup for Microsoft Office 365 data between repositories in bulk.
.DESCRIPTION
    Free tool to move Veeam Backup for Microsoft Office 365 data.
.LICENSE
    Released under the MIT license.
.LINK
    http://www.github.com/nielsengelen
    http://www.github.com/VeeamHub
.VERSION
    1.0
.CREATORS
    Niels Engelen (niels.engelen@veeam.com)
    Tim Smith (tim.smith@veeam.com)
#>

Add-Type -AssemblyName System.Windows.Forms 
[System.Windows.Forms.Application]::EnableVisualStyles()

Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

#region Begin GUI{ 
$VBO365                          = New-Object system.Windows.Forms.Form
$VBO365.ClientSize               = '300,250'
$VBO365.text                     = "VBO365 Data Mover"
$VBO365.FormBorderStyle          = 'Fixed3D'
$VBO365.MaximizeBox              = $false

#region Labels {
$lblInfo                         = New-Object system.Windows.Forms.Label
$lblInfo.Text                    = "Use this free community tool to `nmigrate data between repositories."
$lblInfo.AutoSize                = $true
$lblInfo.Location                = New-Object System.Drawing.Point(15,10)
$lblInfo.Font                    = 'Microsoft Sans Serif, 10'

$lblSourceRepo                   = New-Object system.Windows.Forms.Label
$lblSourceRepo.Text              = "Source repository:"
$lblSourceRepo.Location          = New-Object System.Drawing.Point(15,50)

$lblObjectType                   = New-Object system.Windows.Forms.Label
$lblObjectType.Text              = "Select type:"
$lblObjectType.Location          = New-Object System.Drawing.Point(15,75)

$lblObject                       = New-Object system.Windows.Forms.Label
$lblObject.Text                  = "Number of objects:"
$lblObject.Location              = New-Object System.Drawing.Point(15,100)

$lblTargetRepo                   = New-Object system.Windows.Forms.Label
$lblTargetRepo.Text              = "Target repository:"
$lblTargetRepo.Location          = New-Object System.Drawing.Point(15,125)

$lblDisclaimer                   = New-Object system.Windows.Forms.Label
$lblDisclaimer.Text              = [char]0x00A9 + " 2019 VeeamHub`n`nDistributed under MIT license."
$lblDisclaimer.AutoSize          = $true
$lblDisclaimer.Location          = New-Object System.Drawing.Point(55,200)
$lblDisclaimer.Font              = 'Microsoft Sans Serif, 10'
#endregion Labels }

#region Dropdown list {
$dropDownBoxType                 = New-Object System.Windows.Forms.ComboBox
$dropDownBoxType.Location        = New-Object System.Drawing.Size(135,75)
$dropDownBoxType.Size            = New-Object System.Drawing.Size(150,20) 
$dropDownBoxType.DropDownStyle   = 'DropDownList'

[void]$dropDownBoxType.Items.Add("User")
[void]$dropDownBoxType.Items.Add("Group")
[void]$dropDownBoxType.Items.Add("Site")

$dropDownBoxType.SelectedItem    = $dropDownBoxType.Items[0]
#endregion Dropdown list }

#region Comboboxes
$cmbSourceRepo                   = New-Object system.Windows.Forms.ComboBox
$cmbSourceRepo.Width             = 150
$cmbSourceRepo.Location          = New-Object System.Drawing.Point(135,50)

$cmbObject                       = New-Object system.Windows.Forms.Label
$cmbObject.Text                  = $objectsList.count
$cmbObject.Location              = New-Object System.Drawing.Point(135,100)

$cmbTargetRepo                   = New-Object system.Windows.Forms.ComboBox
$cmbTargetRepo.Width             = 150
$cmbTargetRepo.Location          = New-Object System.Drawing.Point(135,125)
#endregion Comboboxes }

#region Buttons {
$btnMigrate                      = New-Object system.Windows.Forms.Button
$btnMigrate.Text                 = "Migrate"
$btnMigrate.Width                = 80
$btnMigrate.Height               = 30
$btnMigrate.Location             = New-Object System.Drawing.Point(170,160)
#endregion Buttons }

$VBO365.Controls.AddRange(@($lblInfo, $lblObject, $lblObjectType, $lblSourceRepo, $lblTargetRepo, $lblDisclaimer, $dropDownBoxType, $cmbObject, $cmbSourceRepo, $cmbTargetRepo, $btnMigrate))

#region gui events {
$reposList = Get-VBORepository

foreach ($repos in $reposList) {
 [void] $cmbSourceRepo.Items.Add($repos.Name)
 [void] $cmbTargetRepo.Items.Add($repos.Name)
}

$cmbSourceRepo.Add_SelectedIndexChanged({
  $cmbTargetRepo.Text = ""
  $repo = Get-VBORepository -Name $cmbSourceRepo.SelectedItem
  $objectsList = Get-VBOEntityData -Type $dropDownBoxType.SelectedItem -Repository $repo
  $cmbObject.Text = $objectsList.count
})

$dropDownBoxType.Add_SelectedIndexChanged({
  $cmbTargetRepo.Text = ""
  $repo = Get-VBORepository -Name $cmbSourceRepo.SelectedItem
  $objectsList = Get-VBOEntityData -Type $dropDownBoxType.SelectedItem -Repository $repo
  $cmbObject.Text = $objectsList.count
})


$btnMigrate.Add_Click({
  $sourceRepo = $cmbSourceRepo.SelectedItem
  $targetRepo = $cmbTargetRepo.SelectedItem

  if (!$sourceRepo) {
    [System.Windows.Forms.MessageBox]::Show("Please select a source repository.", "Error", 0, 48)
  } elseif (!$targetRepo) {
    [System.Windows.Forms.MessageBox]::Show("Please select a target repository.", "Error", 0, 48)
  } else {
    if ($sourceRepo -eq $targetRepo) {
      [System.Windows.Forms.MessageBox]::Show("Source and target repository are the same.", "Error" , 0, 48)
    } else {
      $source = Get-VBORepository -Name $sourceRepo
      $target = Get-VBORepository -Name $targetRepo
      $objectdata = Get-VBOEntityData -Type $dropDownBoxType.SelectedItem -Repository $source 
      $type = $dropDownBoxType.SelectedItem

      if ($type -eq 'User') {
        foreach ($object in $objectdata) {
          try {
            Move-VBOEntityData -From $source -To $target -User $object -RunAsync -confirm:$false
          } catch {
           [System.Windows.Forms.MessageBox]::Show("Failed to move data.", "Error" , 0, 48)
          }
        }
      } elseif ($type -eq 'Group') {
        foreach ($object in $objectdata) {
          try {
            Move-VBOEntityData -From $source -To $target -Group $object -RunAsync -confirm:$false
          } catch {
           [System.Windows.Forms.MessageBox]::Show("Failed to move data.", "Error" , 0, 48)
          }
        }
      } elseif ($type -eq 'Site') {
        foreach ($object in $objectdata) {
          try {
            Move-VBOEntityData -From $source -To $target -Site $object -RunAsync -confirm:$false
          } catch {
           [System.Windows.Forms.MessageBox]::Show("Failed to move data.", "Error" , 0, 48)
          }
        }
      }

      $cmbObject.Text = $objectsList.count
      $cmbSourceRepo.Text = ""
      $cmbTargetRepo.Text = ""
      
      [System.Windows.Forms.MessageBox]::Show("Data is moving. Please check progress in VBO Console.", "Success", 0, 64)
    }
  }
})
#endregion End GUI }

[void]$VBO365.ShowDialog()
