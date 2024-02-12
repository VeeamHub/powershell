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
    2.1
#>

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

#region Begin GUI{
$VBO365                          = New-Object system.Windows.Forms.Form
$VBO365.ClientSize               = '300,300'
$VBO365.text                     = "VBO365 Data Manager"
$VBO365.FormBorderStyle          = 'Fixed3D'
$VBO365.MaximizeBox              = $false

#region Labels {
$lblInfo                         = New-Object system.Windows.Forms.Label
$lblInfo.Text                    = "Use this free community tool to remove data`nor migrate data between repositories."
$lblInfo.AutoSize                = $true
$lblInfo.Location                = New-Object System.Drawing.Point(15,10)
$lblInfo.Font                    = 'Microsoft Sans Serif, 10'

$lblSourceServer                   = New-Object system.Windows.Forms.Label
$lblSourceServer.Text              = "Source Server:"
$lblSourceServer.Location          = New-Object System.Drawing.Point(15,50)

$lblSourceRepo                   = New-Object system.Windows.Forms.Label
$lblSourceRepo.Text              = "Source repository:"
$lblSourceRepo.Location          = New-Object System.Drawing.Point(15,75)

$lblObjectType                   = New-Object system.Windows.Forms.Label
$lblObjectType.Text              = "Select type:"
$lblObjectType.Location          = New-Object System.Drawing.Point(15,100)

$lblObject                       = New-Object system.Windows.Forms.Label
$lblObject.Text                  = "Select object:"
$lblObject.Location              = New-Object System.Drawing.Point(15,125)

$lblTargetRepo                   = New-Object system.Windows.Forms.Label
$lblTargetRepo.Text              = "Target repository:"
$lblTargetRepo.Location          = New-Object System.Drawing.Point(15,150)

$lblDisclaimer                   = New-Object system.Windows.Forms.Label
$lblDisclaimer.Text              = [char]0x00A9 + " 2019 VeeamHub`n`nDistributed under MIT license."
$lblDisclaimer.AutoSize          = $true
$lblDisclaimer.Location          = New-Object System.Drawing.Point(55,225)
$lblDisclaimer.Font              = 'Microsoft Sans Serif, 10'
#endregion Labels }

#region Input box {
$textBox                         = New-Object System.Windows.Forms.TextBox
$textBox.Location                = New-Object System.Drawing.Point(135,50)
$textBox.Size                    = New-Object System.Drawing.Size(150,20)
#endregion Input box}

#region Dropdown list {
$dropDownBoxType                 = New-Object System.Windows.Forms.ComboBox
$dropDownBoxType.Location        = New-Object System.Drawing.Size(135,100)
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
$cmbSourceRepo.Location          = New-Object System.Drawing.Point(135,75)

$cmbObject                       = New-Object system.Windows.Forms.ComboBox
$cmbObject.Width                 = 150
$cmbObject.Location              = New-Object System.Drawing.Point(135,125)

$cmbTargetRepo                   = New-Object system.Windows.Forms.ComboBox
$cmbTargetRepo.Width             = 150
$cmbTargetRepo.Location          = New-Object System.Drawing.Point(135,150)
#endregion Comboboxes }

#region Buttons {
$btnConnect                      = New-Object system.Windows.Forms.Button
$btnConnect.Text                 = "Connect"
$btnConnect.Width                = 60
$btnConnect.Height               = 30
$btnConnect.Location             = New-Object System.Drawing.Point(40,180)

$btnDelete                       = New-Object system.Windows.Forms.Button
$btnDelete.Text                  = "Delete"
$btnDelete.Width                 = 60
$btnDelete.Height                = 30
$btnDelete.Location              = New-Object System.Drawing.Point(110,180)

$btnMigrate                      = New-Object system.Windows.Forms.Button
$btnMigrate.Text                 = "Migrate"
$btnMigrate.Width                = 60
$btnMigrate.Height               = 30
$btnMigrate.Location             = New-Object System.Drawing.Point(180,180)
#endregion Buttons }

$VBO365.Controls.AddRange(@($lblInfo, $lblSourceServer, $lblObject, $lblObjectType, $lblSourceRepo, $lblTargetRepo, $lblDisclaimer, $textBox, $dropDownBoxType, $cmbObject, $cmbSourceRepo, $cmbTargetRepo, $btnConnect, $btnDelete, $btnMigrate))

#region gui events {
$reposList = Get-VBORepository | Sort-Object

foreach ($repos in $reposList) {
 [void] $cmbSourceRepo.Items.Add($repos.Name)
 [void] $cmbTargetRepo.Items.Add($repos.Name)
}

$cmbSourceRepo.Add_SelectedIndexChanged({
  $cmbObject.Items.Clear()
  $cmbObject.Text = ""
  $cmbTargetRepo.Text = ""

  $repo = Get-VBORepository -Name $cmbSourceRepo.SelectedItem | Sort-Object
  $objectsList = Get-VBOEntityData -Type $dropDownBoxType.SelectedItem -Repository $repo | Sort-Object

  foreach ($objects in $objectsList) {
   [void] $cmbObject.Items.Add($objects.DisplayName)
  }
})

$dropDownBoxType.Add_SelectedIndexChanged({
  $cmbObject.Items.Clear()
  $cmbObject.Text = ""
  $cmbTargetRepo.Text = ""

  $repo = Get-VBORepository -Name $cmbSourceRepo.SelectedItem | Sort-Object
  $objectsList = Get-VBOEntityData -Type $dropDownBoxType.SelectedItem -Repository $repo | Sort-Object

  foreach ($objects in $objectsList) {
   [void] $cmbObject.Items.Add($objects.DisplayName)
  }
})

$btnConnect.Add_Click({
  $vboServer = $textBox.Text
  if (!$vboServer) {
    [System.Windows.Forms.MessageBox]::Show("Please enter a server to connect.", "Error", 0, 48)
  } else {
    $disconnect = Disconnect-VBOServer
    Connect-VBOServer -Server $vboServer

    $cmbObject.Items.Clear()
    $cmbSourceRepo.Items.Clear()
    $cmbTargetRepo.Items.Clear()

    $cmbObject.Text = ""
    $cmbSourceRepo.Text = ""
    $cmbTargetRepo.Text = ""

    $reposList = Get-VBORepository | Sort-Object

    foreach ($repos in $reposList) {
      [void] $cmbSourceRepo.Items.Add($repos.Name)
      [void] $cmbTargetRepo.Items.Add($repos.Name)
    }
    [System.Windows.Forms.MessageBox]::Show("Server $vboServer connected successfully.", "Success", 0, 64)
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
      $repo = Get-VBORepository -Name $sourceRepo | Sort-Object
      $objectdata = Get-VBOEntityData -Type $dropDownBoxType.SelectedItem -Repository $repo -Name $object | Sort-Object
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
        $source = Get-VBORepository -Name $sourceRepo | Sort-Object
        $target = Get-VBORepository -Name $targetRepo | Sort-Object
        $objectdata = Get-VBOEntityData -Type $dropDownBoxType.SelectedItem -Repository $source -Name $object | Sort-Object
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