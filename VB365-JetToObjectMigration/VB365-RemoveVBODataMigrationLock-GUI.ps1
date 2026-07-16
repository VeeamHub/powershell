<#
.SYNOPSIS
    GUI wrapper to remove the data migration lock from a Veeam Backup for
    Microsoft 365 repository.

.DESCRIPTION
    Presents a window to select a VBO repository, runs Remove-VBODataMigrationLock
    against it, and then shows the resulting MigrationLock state of the repository.
    Requires the Veeam.Archiver.PowerShell module (Veeam Backup for Microsoft 365).
    Run this script in a PowerShell session on the VB365 server.

.NOTES
    NAME:  VB365-JetToObjectMigration.ps1
	VERSION: 0.5
	AUTHOR: David Bewernick
	GITHUB: https://github.com/d-works
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Load the Veeam module --------------------------------------------------
try {
    Import-Module Veeam.Archiver.PowerShell -ErrorAction Stop
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Unable to load the Veeam Backup for Microsoft 365 PowerShell module.`n`n$($_.Exception.Message)",
        "Module Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    return
}

# enable the migration option (on VB365 server)
[Environment]::SetEnvironmentVariable("VEEAM_DATA_MIGRATION_ENABLED", "true")

# --- Retrieve the repositories ----------------------------------------------
try {
    $repositories = Get-VBORepository -ErrorAction Stop | Sort-Object Name
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Unable to retrieve repositories.`n`n$($_.Exception.Message)",
        "Repository Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    return
}

if (-not $repositories) {
    [System.Windows.Forms.MessageBox]::Show(
        "No repositories were found.",
        "No Repositories",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    return
}

# --- Build the form ---------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text          = "Remove VBO Data Migration Lock"
$form.Size          = New-Object System.Drawing.Size(520, 360)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox   = $false
$form.MinimizeBox   = $false

# Label for the repository selector
$lblRepo = New-Object System.Windows.Forms.Label
$lblRepo.Text     = "Select repository:"
$lblRepo.Location = New-Object System.Drawing.Point(15, 20)
$lblRepo.AutoSize = $true
$form.Controls.Add($lblRepo)

# ComboBox with the repositories
$cmbRepo = New-Object System.Windows.Forms.ComboBox
$cmbRepo.Location      = New-Object System.Drawing.Point(15, 45)
$cmbRepo.Size          = New-Object System.Drawing.Size(475, 24)
$cmbRepo.DropDownStyle = "DropDownList"
foreach ($repo in $repositories) {
    [void]$cmbRepo.Items.Add($repo.Name)
}
$cmbRepo.SelectedIndex = 0
$form.Controls.Add($cmbRepo)

# Button to start removing the lock
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text     = "Remove Migration Lock"
$btnRun.Location = New-Object System.Drawing.Point(15, 80)
$btnRun.Size     = New-Object System.Drawing.Size(180, 30)
$form.Controls.Add($btnRun)

# Output text box
$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location   = New-Object System.Drawing.Point(15, 125)
$txtOutput.Size       = New-Object System.Drawing.Size(475, 150)
$txtOutput.Multiline  = $true
$txtOutput.ReadOnly   = $true
$txtOutput.ScrollBars = "Vertical"
$txtOutput.Font       = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($txtOutput)

# OK button (closes the window)
$btnOk = New-Object System.Windows.Forms.Button
$btnOk.Text         = "OK"
$btnOk.Location     = New-Object System.Drawing.Point(415, 285)
$btnOk.Size         = New-Object System.Drawing.Size(75, 30)
$btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($btnOk)
$form.AcceptButton = $btnOk

# --- Button click logic -----------------------------------------------------
$btnRun.Add_Click({
    $selectedName = $cmbRepo.SelectedItem
    $repository   = $repositories | Where-Object { $_.Name -eq $selectedName } | Select-Object -First 1

    if (-not $repository) {
        $txtOutput.Text = "Could not resolve the selected repository."
        return
    }

    $btnRun.Enabled = $false
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $txtOutput.Text = "Removing data migration lock from '$($repository.Name)'..."
    $form.Refresh()

    try {
        Remove-VBODataMigrationLock -Repository $repository -ErrorAction Stop -Confirm:$false

        # Re-query the repository to show the resulting MigrationLock state
        $result = Get-VBORepository -Id $repository.Id | Select-Object Name, MigrationLock
        $txtOutput.Text = ($result | Format-List | Out-String).Trim()
    }
    catch {
        $txtOutput.Text = "An error occurred:`r`n$($_.Exception.Message)"
    }
    finally {
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
        $btnRun.Enabled = $true
    }
})

# --- Show the form ----------------------------------------------------------
[void]$form.ShowDialog()
$form.Dispose()
