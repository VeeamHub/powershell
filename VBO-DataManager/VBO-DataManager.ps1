<# 
.NAME
    Veeam Backup for Microsoft Office 365 Data Manager
.SYNOPSIS
    Leverage this free tool to manage Veeam Backup for Microsoft Office 365 data.
.DESCRIPTION
    Free tool to move or remove Veeam Backup for Microsoft Office 365 data.
.LICENSE
    Released under the MIT license.
.LINK
    http://www.github.com/nielsengelen
    http://www.github.com/VeeamHub
.VERSION
    2.0
#>

Add-Type -AssemblyName System.Windows.Forms 
[System.Windows.Forms.Application]::EnableVisualStyles()

Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

#region Begin GUI{ 
$VBO365                          = New-Object system.Windows.Forms.Form
$VBO365.ClientSize               = '300,250'
$VBO365.text                     = "VBO365 Data Manager"
$VBO365.FormBorderStyle          = 'Fixed3D'
$VBO365.MaximizeBox              = $false

#region Labels {
$lblInfo                         = New-Object system.Windows.Forms.Label
$lblInfo.Text                    = "Use this free community tool to remove data`nor migrate data between repositories."
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
$lblObject.Text                  = "Select object:"
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

$cmbObject                       = New-Object system.Windows.Forms.ComboBox
$cmbObject.Width                 = 150
$cmbObject.Location              = New-Object System.Drawing.Point(135,100)

$cmbTargetRepo                   = New-Object system.Windows.Forms.ComboBox
$cmbTargetRepo.Width             = 150
$cmbTargetRepo.Location          = New-Object System.Drawing.Point(135,125)
#endregion Comboboxes }

#region Buttons {
$btnDelete                       = New-Object system.Windows.Forms.Button
$btnDelete.Text                  = "Delete"
$btnDelete.Width                 = 80
$btnDelete.Height                = 30
$btnDelete.Location              = New-Object System.Drawing.Point(50,160)

$btnMigrate                      = New-Object system.Windows.Forms.Button
$btnMigrate.Text                 = "Migrate"
$btnMigrate.Width                = 80
$btnMigrate.Height               = 30
$btnMigrate.Location             = New-Object System.Drawing.Point(170,160)
#endregion Buttons }

$VBO365.Controls.AddRange(@($lblInfo, $lblObject, $lblObjectType, $lblSourceRepo, $lblTargetRepo, $lblDisclaimer, $dropDownBoxType, $cmbObject, $cmbSourceRepo, $cmbTargetRepo, $btnDelete, $btnMigrate))

#region gui events {
$reposList = Get-VBORepository

foreach ($repos in $reposList) {
 [void] $cmbSourceRepo.Items.Add($repos.Name)
 [void] $cmbTargetRepo.Items.Add($repos.Name)
}

$cmbSourceRepo.Add_SelectedIndexChanged({
  $cmbObject.Items.Clear()
  $cmbObject.Text = ""
  $cmbTargetRepo.Text = ""

  $repo = Get-VBORepository -Name $cmbSourceRepo.SelectedItem
  $objectsList = Get-VBOEntityData -Type $dropDownBoxType.SelectedItem -Repository $repo

  foreach ($objects in $objectsList) {
   [void] $cmbObject.Items.Add($objects.DisplayName)
  }
})

$dropDownBoxType.Add_SelectedIndexChanged({
  $cmbObject.Items.Clear()
  $cmbObject.Text = ""
  $cmbTargetRepo.Text = ""

  $repo = Get-VBORepository -Name $cmbSourceRepo.SelectedItem
  $objectsList = Get-VBOEntityData -Type $dropDownBoxType.SelectedItem -Repository $repo

  foreach ($objects in $objectsList) {
   [void] $cmbObject.Items.Add($objects.DisplayName)
  }
})

$btnDelete.Add_Click({
  $sourceRepo = $cmbSourceRepo.SelectedItem

  if (!$sourceRepo) {
    [System.Windows.Forms.MessageBox]::Show("Please select a source repository.", "Error", 0, 48)
  } else {
    $object = $cmbObject.SelectedItem

    if (!$object) {
      [System.Windows.Forms.MessageBox]::Show("No object selected.", "Error" , 0, 48)
    } else {
      $repo = Get-VBORepository -Name $sourceRepo
      $objectdata = Get-VBOEntityData -Type $dropDownBoxType.SelectedItem -Repository $repo -Name $object
      $type = $dropDownBoxType.SelectedItem

      if ($type -eq 'User') {
         try {
           Remove-VBOEntityData -Repository $repo -User $objectdata
         } catch {
           [System.Windows.Forms.MessageBox]::Show("Failed to remove data.", "Error" , 0, 48)
         }
      } elseif ($type -eq 'Group') {
         try {
           Remove-VBOEntityData -Repository $repo -Group $objectdata
         } catch {
           [System.Windows.Forms.MessageBox]::Show("Failed to remove data.", "Error" , 0, 48)
         }
      } elseif ($type -eq 'Site') {
         try {
           Remove-VBOEntityData -Repository $repo -Site $objectdata
         } catch {
           [System.Windows.Forms.MessageBox]::Show("Failed to remove data.", "Error" , 0, 48)
         }
      }

      $cmbObject.Items.Clear()
      $cmbObject.Text = ""
      $cmbSourceRepo.Text = ""
      $cmbTargetRepo.Text = ""

      [System.Windows.Forms.MessageBox]::Show("Data has been removed.", "Success", 0, 64)
    }
  }
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
      $object = $cmbObject.SelectedItem

      if (!$object) {
        [System.Windows.Forms.MessageBox]::Show("No object selected.", "Error" , 0, 48)
      } else {
        $source = Get-VBORepository -Name $sourceRepo
        $target = Get-VBORepository -Name $targetRepo
        $objectdata = Get-VBOEntityData -Type $dropDownBoxType.SelectedItem -Repository $source -Name $object
        $type = $dropDownBoxType.SelectedItem

        if ($type -eq 'User') {
          try {
            Move-VBOEntityData -From $source -To $target -User $objectdata
          } catch {
           [System.Windows.Forms.MessageBox]::Show("Failed to move data.", "Error" , 0, 48)
          }
        } elseif ($type -eq 'Group') {
          try {
            Move-VBOEntityData -From $source -To $target -Group $objectdata
          } catch {
           [System.Windows.Forms.MessageBox]::Show("Failed to move data.", "Error" , 0, 48)
          }
        } elseif ($type -eq 'Site') {
          try {
            Move-VBOEntityData -From $source -To $target -Site $objectdata
          } catch {
           [System.Windows.Forms.MessageBox]::Show("Failed to move data.", "Error" , 0, 48)
          }
        }

        $cmbObject.Items.Clear()
        $cmbObject.Text = ""
        $cmbSourceRepo.Text = ""
        $cmbTargetRepo.Text = ""

        [System.Windows.Forms.MessageBox]::Show("Data has been moved.", "Success", 0, 64)
      }
    }
  }
})
#endregion End GUI }

[void]$VBO365.ShowDialog()