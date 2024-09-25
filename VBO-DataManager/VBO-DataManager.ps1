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
    2.2
#>

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1"

#region Begin GUI{
$VBO365                          = New-Object system.Windows.Forms.Form
$VBO365.ClientSize               = '300,320'
$VBO365.text                     = "VBO365 Data Manager"
$VBO365.FormBorderStyle          = 'Fixed3D'
$VBO365.MaximizeBox              = $false

#region Labels {
$lblInfo                         = New-Object system.Windows.Forms.Label
$lblInfo.Text                    = "Use this free community tool to remove data`nor migrate data between repositories."
$lblInfo.AutoSize                = $true
$lblInfo.Location                = New-Object System.Drawing.Point(15,10)
$lblInfo.Font                    = 'Microsoft Sans Serif, 10'

$lblSourceServer                 = New-Object system.Windows.Forms.Label
$lblSourceServer.Text            = "Source Server:"
$lblSourceServer.Location        = New-Object System.Drawing.Point(15,50)

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
$lblDisclaimer.Text              = [char]0x00A9 + " 2019 VeeamHub`nDistributed under MIT license."
$lblDisclaimer.AutoSize          = $true
$lblDisclaimer.Location          = New-Object System.Drawing.Point(55,280)
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

#[void]$dropDownBoxType.Items.Add( " ")
[void]$dropDownBoxType.Items.Add("User")
[void]$dropDownBoxType.Items.Add("Group")
[void]$dropDownBoxType.Items.Add("Site")
[void]$dropDownBoxType.Items.Add("Team")

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

#region Checkboxes {
$chkMailbox                   = New-Object System.Windows.Forms.CheckBox
$chkMailbox.Size              = New-Object System.Drawing.Size(70,20)
$chkMailbox.Location          = New-Object System.Drawing.Point(10,180)
$chkMailbox.Text              = "Mailbox"
$chkMailbox.Checked           = $true
$chkMailbox.Visible           = $false

$chkArchiveMailbox            = New-Object System.Windows.Forms.CheckBox
$chkArchiveMailbox.Size       = New-Object System.Drawing.Size(70,20)
$chkArchiveMailbox.Location   = New-Object System.Drawing.Point(90,180)
$chkArchiveMailbox.Text       = "Archive"
$chkArchiveMailbox.Checked    = $true
$chkArchiveMailbox.Visible    = $false

$chkOneDrive                  = New-Object System.Windows.Forms.CheckBox
$chkOneDrive.Size             = New-Object System.Drawing.Size(80,20)
$chkOneDrive.Location         = New-Object System.Drawing.Point(170,180)
$chkOneDrive.Text             = "OneDrive"
$chkOneDrive.Checked          = $true
$chkOneDrive.Visible          = $false

$chkSite                      = New-Object System.Windows.Forms.CheckBox
$chkSite.Size                 = New-Object System.Drawing.Size(70,20)
$chkSite.Location             = New-Object System.Drawing.Point(250,180)
$chkSite.Text                 = "Site"
$chkSite.Checked              = $true
$chkSite.Visible              = $false

$chkGrpSite                   = New-Object System.Windows.Forms.CheckBox
$chkGrpSite.Size              = New-Object System.Drawing.Size(80,20)
$chkGrpSite.Location          = New-Object System.Drawing.Point(10,210)
$chkGrpSite.Text              = "Group Site"
$chkGrpSite.Checked           = $true
$chkGrpSite.Visible           = $false

$chkGrpMailbox                = New-Object System.Windows.Forms.CheckBox
$chkGrpMailbox.Size           = New-Object System.Drawing.Size(100,20)
$chkGrpMailbox.Location       = New-Object System.Drawing.Point(90,210)
$chkGrpMailbox.Text           = "Group Mailbox"
$chkGrpMailbox.Checked        = $true
$chkGrpMailbox.Visible        = $false

#endregion Checkboxes }

#region Buttons {
$btnConnect                      = New-Object system.Windows.Forms.Button
$btnConnect.Text                 = "Connect"
$btnConnect.Width                = 60
$btnConnect.Height               = 30
$btnConnect.Location             = New-Object System.Drawing.Point(40,230)

$btnDelete                       = New-Object system.Windows.Forms.Button
$btnDelete.Text                  = "Delete"
$btnDelete.Width                 = 60
$btnDelete.Height                = 30
$btnDelete.Location              = New-Object System.Drawing.Point(110,230)

$btnMigrate                      = New-Object system.Windows.Forms.Button
$btnMigrate.Text                 = "Migrate"
$btnMigrate.Width                = 60
$btnMigrate.Height               = 30
$btnMigrate.Location             = New-Object System.Drawing.Point(180,230)
#endregion Buttons }

#region functions {
  function Set-CheckboxDisplay {
    if ($DropDownBoxType.SelectedItem -eq "User") {
      $chkMailbox.Visible = $true
      $chkArchiveMailbox.Visible = $true
      $chkOneDrive.Visible = $true
      $chkSite.Visible = $true
      $chkGrpSite.Visible = $false
      $chkGrpMailbox.Visible = $false
    } elseif ($DropDownBoxType.SelectedItem -eq "Group") {
      $chkMailbox.Visible = $true
      $chkMailbox.Checked = $false
      $chkArchiveMailbox.Visible = $true
      $chkArchiveMailbox.Checked = $false
      $chkOneDrive.Visible = $true
      $chkOneDrive.Checked = $false
      $chkSite.Visible = $true
      $chkSite.Checked = $false
      $chkGrpSite.Visible = $true
      $chkGrpMailbox.Visible = $true

      $chkMailbox.Add_Click({[System.Windows.Forms.MessageBox]::Show("This will delete all  mailboxes of group members.", "Warning" , 0, 48).AutoSize})
      $chkArchiveMailbox.Add_Click({[System.Windows.Forms.MessageBox]::Show("This will delete all archive mailboxes of group members.", "Warning" , 0, 48).AutoSize})
      $chkOneDrive.Add_Click({[System.Windows.Forms.MessageBox]::Show("This will delete all OneDrives of group members.", "Warning" , 0, 48).AutoSize})
      $chkSite.Add_Click({[System.Windows.Forms.MessageBox]::Show("This will delete all personal sites of group members.", "Warning" , 0, 48).AutoSize})
    } else {
      $chkMailbox.Visible = $false
      $chkArchiveMailbox.Visible = $false
      $chkOneDrive.Visible = $false
      $chkSite.Visible = $false
      $chkGrpSite.Visible = $false
      $chkGrpMailbox.Visible = $false
    }
  }
  function Clear-Fields([boolean]$clearSourceRepo = $false) {
    $cmbObject.Items.Clear()
    $cmbObject.Text = ""
    $cmbTargetRepo.Text = ""

    if ($clearSourceRepo -eq $true){
      $cmbSourceRepo.Text = ""
    }
  }

#}

$VBO365.Controls.AddRange(@($lblInfo, $lblSourceServer, $lblObject, $lblObjectType, $lblSourceRepo, $lblTargetRepo, $lblDisclaimer, $textBox, $dropDownBoxType, $cmbObject, $cmbSourceRepo, $cmbTargetRepo, $btnConnect, $btnDelete, $btnMigrate, $chkMailbox, $chkArchiveMailbox, $chkOneDrive, $chkSite, $chkGrpSite, $chkGrpMailbox))

#region gui events {
$reposList = Get-VBORepository | Sort-Object

foreach ($repos in $reposList) {
 [void] $cmbSourceRepo.Items.Add($repos.Name)
 [void] $cmbTargetRepo.Items.Add($repos.Name)
}

$cmbSourceRepo.Add_SelectedIndexChanged({
  Clear-Fields
  Set-CheckboxDisplay

  $repo = Get-VBORepository -Name $cmbSourceRepo.SelectedItem | Sort-Object
  $objectsList = Get-VBOEntityData -Type $dropDownBoxType.SelectedItem -Repository $repo | Sort-Object

  foreach ($objects in $objectsList) {
   [void] $cmbObject.Items.Add($objects.DisplayName)
  }
})

$dropDownBoxType.Add_SelectedIndexChanged({
  Clear-Fields
  Set-CheckboxDisplay

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

    $cmbSourceRepo.Items.Clear()
    $cmbTargetRepo.Items.Clear()
    Clear-Fields -clearSourceRepo:$true

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
      $objectdata = Get-VBOEntityData -Type $dropDownBoxType.SelectedItem -Repository $repo -Name $object
      $type = $dropDownBoxType.SelectedItem

      try {
        if ($chkMailbox.Checked -eq $true -and $chkArchiveMailbox.Checked -eq $true -and $chkSite.Checked -eq $true -and $chkSite.Checked -eq $true -and $type -eq 'User') {
          Remove-VBOEntityData -Repository $repo -User $objectdata -Confirm:$False
        } elseif ($chkGrpMailbox -eq $true -and $chkGrpSite -eq $true -and $type -eq 'Group') {
          Remove-VBOEntityData -Repository $repo -Group $objectdata -Confirm:$False
        } elseif ($type -eq 'Site') {
          Remove-VBOEntityData -Repository $repo -Site $objectdata -Confirm:$False
        } elseif ($type -eq 'Team') {
          Remove-VBOEntityData -Repository $repo -Team $objectdata -Confirm:$False
        }else {
          switch ($type) {
            {$type -eq "User" -and $chkMailbox.Checked -eq $true} {Remove-VBOEntityData -Repository $repo -User $objectdata -Mailbox -Confirm:$False}
            {$type -eq "User" -and $chkArchiveMailbox.Checked -eq $true} {Remove-VBOEntityData -Repository $repo -User $objectdata -ArchiveMailbox -Confirm:$False}
            {$type -eq "User" -and $chkOneDrive.Checked -eq $true} {Remove-VBOEntityData -Repository $repo -User $objectdata -OneDrive -Confirm:$False}
            {$type -eq "User" -and $chkSite.Checked -eq $true} {Remove-VBOEntityData -Repository $repo -User $objectdata -Sites -Confirm:$False}
            {$type -eq "Group" -and $chkMailbox.Checked -eq $true} {Remove-VBOEntityData -Repository $repo -Group $objectdata -Mailbox -Confirm:$False}
            {$type -eq "Group" -and $chkArchiveMailbox.Checked -eq $true} {Remove-VBOEntityData -Repository $repo -Group $objectdata -ArchiveMailbox -Confirm:$False}
            {$type -eq "Group" -and $chkOneDrive.Checked -eq $true} {Remove-VBOEntityData -Repository $repo -Group $objectdata -OneDrive -Confirm:$False}
            {$type -eq "Group" -and $chkSite.Checked -eq $true} {Remove-VBOEntityData -Repository $repo -Group $objectdata -Sites -Confirm:$False}
            {$type -eq "Group" -and $chkGrpMailbox.Checked -eq $true} {Remove-VBOEntityData -Repository $repo -Group $objectdata -GroupMailbox -Confirm:$False}
            {$type -eq "Group" -and $chkGrpSite.Checked -eq $true} {Remove-VBOEntityData -Repository $repo -Group $objectdata -GroupSite -Confirm:$False}
            #Default {}
            }
        }
      } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to remove $type $objectData.`nPlease try again.", "Error" , 0, 48).AutoSize
      }

      Clear-Fields -clearSourceRepo:$true

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

        Clear-Fields -clearSourceRepo:$true

        [System.Windows.Forms.MessageBox]::Show("Data has been moved.", "Success", 0, 64)
      }
    }
  }
})
#endregion End GUI }

[void]$VBO365.ShowDialog()
