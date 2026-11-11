<#
.SYNOPSIS
	GUI wrapper to start the job based migration of Jet Repositories to Object Storage Repositories

.DESCRIPTION
  This script needs to be run on the VB365 Controller. It provides a graphical front end for selecting the
  organization, validation type (Organization / Job), source and target repository and whether the job should be
  switched over to the target repository during migration. The selections mirror the original console script
  (VB365-JetToOsrMigration.ps1). All status output is written into the output text box at the bottom of the window.

.OUTPUTS
	Starts the Start-VBODataMigration process for the selected scope, switches over to the new target (if requested)
	and leaves the job disabled. Before re-enabling the job, the migration needs to be verified by using the
	verification script.

.NOTES
	NAME:  VB365-JetToOsrMigration-GUI.ps1
	VERSION: 0.5
	AUTHOR: David Bewernick
	GITHUB: https://github.com/d-works
#>

# ---------------------------------------------------------------------------
# Pre-requisites
# ---------------------------------------------------------------------------
# IMPORTANT: load the Veeam module BEFORE the WinForms assemblies. In PowerShell 7
# the Veeam module performs its service endpoint handshake over gRPC. If WinForms /
# System.Drawing are loaded first, they win assembly binding for shared dependencies
# and the handshake fails with "Failed to perform endpoint handshake". Loading the
# Veeam stack first (and forcing the handshake to complete) avoids the conflict.

# If VBO is installed in a different path, please replace it with your own path.
Import-Module 'C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell.dll'

# enable the migration option (on VB365 server)
[Environment]::SetEnvironmentVariable("VEEAM_DATA_MIGRATION_ENABLED", "true")

# Force the endpoint handshake to complete now, while only the Veeam stack is loaded.
$null = Get-VBOOrganization -ErrorAction SilentlyContinue

# Now load the WinForms assemblies on top of the already-initialised gRPC stack.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------------------
# Build the form
# ---------------------------------------------------------------------------
$form                 = New-Object System.Windows.Forms.Form
$form.Text            = "VB365 - Jet to Object Storage Migration"
$form.Size            = New-Object System.Drawing.Size(640, 640)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox     = $false

$font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Font = $font

# --- Output box --------------------------------------------------------------
$txtOutput            = New-Object System.Windows.Forms.TextBox
$txtOutput.Multiline  = $true
$txtOutput.ScrollBars = "Vertical"
$txtOutput.ReadOnly   = $true
$txtOutput.Location   = New-Object System.Drawing.Point(15, 360)
$txtOutput.Size       = New-Object System.Drawing.Size(595, 220)
$txtOutput.Font       = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($txtOutput)

function Write-Log {
    param([string]$Message)
    $stamp = (Get-Date).ToString("HH:mm:ss")
    $txtOutput.AppendText("[$stamp] $Message`r`n")
    $txtOutput.Refresh()
}

# --- Organization ------------------------------------------------------------
$lblOrg          = New-Object System.Windows.Forms.Label
$lblOrg.Text     = "Organization:"
$lblOrg.Location = New-Object System.Drawing.Point(15, 20)
$lblOrg.Size     = New-Object System.Drawing.Size(160, 22)
$form.Controls.Add($lblOrg)

$cmbOrg               = New-Object System.Windows.Forms.ComboBox
$cmbOrg.DropDownStyle = "DropDownList"
$cmbOrg.Location      = New-Object System.Drawing.Point(180, 17)
$cmbOrg.Size          = New-Object System.Drawing.Size(430, 22)
$form.Controls.Add($cmbOrg)

# --- Validation type ---------------------------------------------------------
$lblType          = New-Object System.Windows.Forms.Label
$lblType.Text     = "Validation type:"
$lblType.Location = New-Object System.Drawing.Point(15, 60)
$lblType.Size     = New-Object System.Drawing.Size(160, 22)
$form.Controls.Add($lblType)

$cmbType               = New-Object System.Windows.Forms.ComboBox
$cmbType.DropDownStyle  = "DropDownList"
$cmbType.Location      = New-Object System.Drawing.Point(180, 57)
$cmbType.Size          = New-Object System.Drawing.Size(430, 22)
[void]$cmbType.Items.Add("Organization")
[void]$cmbType.Items.Add("Job")
$cmbType.SelectedIndex = 0
$form.Controls.Add($cmbType)

# --- Job (shown when validation type = Job) ----------------------------------
$lblJob          = New-Object System.Windows.Forms.Label
$lblJob.Text     = "Job:"
$lblJob.Location = New-Object System.Drawing.Point(15, 100)
$lblJob.Size     = New-Object System.Drawing.Size(160, 22)
$form.Controls.Add($lblJob)

$cmbJob               = New-Object System.Windows.Forms.ComboBox
$cmbJob.DropDownStyle = "DropDownList"
$cmbJob.Location      = New-Object System.Drawing.Point(180, 97)
$cmbJob.Size          = New-Object System.Drawing.Size(430, 22)
$form.Controls.Add($cmbJob)

# --- Source repository (shown when validation type = Organization) -----------
$lblSource          = New-Object System.Windows.Forms.Label
$lblSource.Text     = "Source Repository:"
$lblSource.Location = New-Object System.Drawing.Point(15, 140)
$lblSource.Size     = New-Object System.Drawing.Size(160, 22)
$form.Controls.Add($lblSource)

$cmbSource               = New-Object System.Windows.Forms.ComboBox
$cmbSource.DropDownStyle = "DropDownList"
$cmbSource.Location      = New-Object System.Drawing.Point(180, 137)
$cmbSource.Size          = New-Object System.Drawing.Size(430, 22)
$form.Controls.Add($cmbSource)

# --- Target repository -------------------------------------------------------
$lblTarget          = New-Object System.Windows.Forms.Label
$lblTarget.Text     = "Target Repository:"
$lblTarget.Location = New-Object System.Drawing.Point(15, 180)
$lblTarget.Size     = New-Object System.Drawing.Size(160, 22)
$form.Controls.Add($lblTarget)

$cmbTarget               = New-Object System.Windows.Forms.ComboBox
$cmbTarget.DropDownStyle = "DropDownList"
$cmbTarget.Location      = New-Object System.Drawing.Point(180, 177)
$cmbTarget.Size          = New-Object System.Drawing.Size(430, 22)
$form.Controls.Add($cmbTarget)

# --- Switch job checkbox -----------------------------------------------------
$chkSwitch          = New-Object System.Windows.Forms.CheckBox
$chkSwitch.Text     = "Switch job to target repository during migration"
$chkSwitch.Location = New-Object System.Drawing.Point(180, 215)
$chkSwitch.Size     = New-Object System.Drawing.Size(430, 22)
$form.Controls.Add($chkSwitch)

# --- Buttons -----------------------------------------------------------------
$btnRefresh          = New-Object System.Windows.Forms.Button
$btnRefresh.Text     = "Refresh"
$btnRefresh.Location = New-Object System.Drawing.Point(180, 250)
$btnRefresh.Size     = New-Object System.Drawing.Size(120, 30)
$form.Controls.Add($btnRefresh)

$btnStart          = New-Object System.Windows.Forms.Button
$btnStart.Text     = "Start Migration"
$btnStart.Location = New-Object System.Drawing.Point(310, 250)
$btnStart.Size     = New-Object System.Drawing.Size(150, 30)
$form.Controls.Add($btnStart)

$btnQuit          = New-Object System.Windows.Forms.Button
$btnQuit.Text     = "Quit"
$btnQuit.Location = New-Object System.Drawing.Point(470, 250)
$btnQuit.Size     = New-Object System.Drawing.Size(120, 30)
$form.Controls.Add($btnQuit)

$lblOutput          = New-Object System.Windows.Forms.Label
$lblOutput.Text     = "Output:"
$lblOutput.Location = New-Object System.Drawing.Point(15, 335)
$lblOutput.Size     = New-Object System.Drawing.Size(160, 22)
$form.Controls.Add($lblOutput)

# ---------------------------------------------------------------------------
# Data loading / event logic
# ---------------------------------------------------------------------------

# Toggle the Job vs Source Repository fields based on the validation type.
function Update-FieldVisibility {
    $isJob = ($cmbType.SelectedItem -eq "Job")
    $lblJob.Visible    = $isJob
    $cmbJob.Visible    = $isJob
    $lblSource.Visible = -not $isJob
    $cmbSource.Visible = -not $isJob
}

# Populate the organization-dependent lists (jobs / source repositories).
function Load-OrgDependentData {
    $cmbJob.Items.Clear()
    $cmbSource.Items.Clear()

    if ($cmbOrg.SelectedItem -eq $null) { return }

    $organization = $script:orgs[$cmbOrg.SelectedIndex]

    try {
        # Jobs for the selected organization
        $script:jobs = @(Get-VBOJob -Organization $organization | Sort-Object Name)
        foreach ($j in $script:jobs) { [void]$cmbJob.Items.Add($j.Name) }
        if ($cmbJob.Items.Count -gt 0) { $cmbJob.SelectedIndex = 0 }

        # Jet based source repositories holding data for the selected organization
        $script:sourceRepos = @(Get-VBORepository |
            Where-Object { ($_.ObjectStorageRepository -eq $null) -and
                           ((Get-VBOEntityData -Repository $_ -Type Organization -Name $organization.Name) -ne $null) } |
            Sort-Object Name)
        foreach ($r in $script:sourceRepos) { [void]$cmbSource.Items.Add($r.Name) }
        if ($cmbSource.Items.Count -gt 0) { $cmbSource.SelectedIndex = 0 }

        Write-Log ("Loaded {0} job(s) and {1} source repository(ies) for organization '{2}'." -f `
            $script:jobs.Count, $script:sourceRepos.Count, $organization.Name)
    }
    catch {
        Write-Log ("ERROR loading data for organization: {0}" -f $_.Exception.Message)
    }
}

# Load organizations and target repositories (org independent).
function Load-InitialData {
    $cmbOrg.Items.Clear()
    $cmbTarget.Items.Clear()

    try {
        $script:orgs = @(Get-VBOOrganization | Sort-Object Name)
        foreach ($o in $script:orgs) { [void]$cmbOrg.Items.Add($o.Name) }

        $script:targetRepos = @(Get-VBORepository |
            Where-Object { $_.ObjectStorageRepository -ne $null } | Sort-Object Name)
        foreach ($r in $script:targetRepos) { [void]$cmbTarget.Items.Add($r.Name) }
        if ($cmbTarget.Items.Count -gt 0) { $cmbTarget.SelectedIndex = 0 }

        Write-Log ("Loaded {0} organization(s) and {1} target repository(ies)." -f `
            $script:orgs.Count, $script:targetRepos.Count)

        if ($cmbOrg.Items.Count -gt 0) {
            $cmbOrg.SelectedIndex = 0   # triggers Load-OrgDependentData
        }
    }
    catch {
        Write-Log ("ERROR loading initial data: {0}" -f $_.Exception.Message)
    }
}

# --- Wire up events ----------------------------------------------------------
$cmbType.Add_SelectedIndexChanged({ Update-FieldVisibility })
$cmbOrg.Add_SelectedIndexChanged({ Load-OrgDependentData })
$btnRefresh.Add_Click({ Load-InitialData })
$btnQuit.Add_Click({ $form.Close() })

$btnStart.Add_Click({
    # Validate selections
    if ($cmbOrg.SelectedItem -eq $null) { Write-Log "Please select an organization."; return }
    if ($cmbTarget.SelectedItem -eq $null) { Write-Log "Please select a target repository."; return }

    $organization     = $script:orgs[$cmbOrg.SelectedIndex]
    $targetRepository = $script:targetRepos[$cmbTarget.SelectedIndex]
    $isJob            = ($cmbType.SelectedItem -eq "Job")
    $switchJob        = $chkSwitch.Checked

    if ($isJob) {
        if ($cmbJob.SelectedItem -eq $null) { Write-Log "Please select a job."; return }
        $selectedJob      = $script:jobs[$cmbJob.SelectedIndex]
        $sourceRepository = $selectedJob.Repository
        $proxy            = $selectedJob.Repository.Proxy
    }
    else {
        if ($cmbSource.SelectedItem -eq $null) { Write-Log "Please select a source repository."; return }
        $sourceRepository = $script:sourceRepos[$cmbSource.SelectedIndex]
        $proxy            = $sourceRepository.Proxy
    }

    # Confirm before starting
    $scope = if ($isJob) { "Job '$($selectedJob.Name)'" } else { "Organization '$($organization.Name)'" }
    $msg   = "Start migration for {0}?`r`nFrom: {1}`r`nTo:   {2}`r`nSwitch job to target: {3}" -f `
                $scope, $sourceRepository.Name, $targetRepository.Name, $switchJob
    $answer = [System.Windows.Forms.MessageBox]::Show($msg, "Confirm Migration",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-Log "Migration cancelled by user."
        return
    }

    $btnStart.Enabled = $false
    try {
        # disable the retention for the proxy
        Write-Log "Disabling retention for the proxy..."
        Set-VBOConfigurationParameter -XPath "/Veeam/Archiver/RepositoryConfig" -Key "RetentionDisabled" -Value "True" -Proxy $proxy

        Write-Log ("Starting migration ({0}) From '{1}' To '{2}' (SwitchJob={3})..." -f `
            $scope, $sourceRepository.Name, $targetRepository.Name, $switchJob)

        if ($isJob) {
            if ($switchJob) {
                Start-VBODataMigration -Job $selectedJob -From $sourceRepository -To $targetRepository -SwitchJobToTargetRepository -Confirm:$false -RunAsync
            }
            else {
                Start-VBODataMigration -Job $selectedJob -From $sourceRepository -To $targetRepository -Confirm:$false -RunAsync
            }
        }
        else {
            if ($switchJob) {
                Start-VBODataMigration -Organization $organization -From $sourceRepository -To $targetRepository -SwitchJobToTargetRepository -Confirm:$false -RunAsync
            }
            else {
                Start-VBODataMigration -Organization $organization -From $sourceRepository -To $targetRepository -Confirm:$false -RunAsync
            }
        }

        Write-Log "Migration started (running asynchronously)."
        Write-Log "To check the status, run 'Get-VBODataMigration' in a console after setting VEEAM_DATA_MIGRATION_ENABLED=true."
        Write-Log "Remember to validate source and target before re-enabling the job and re-enabling retention."
    }
    catch {
        Write-Log ("ERROR starting migration: {0}" -f $_.Exception.Message)
    }
    finally {
        $btnStart.Enabled = $true
    }
})

# ---------------------------------------------------------------------------
# Initialize and show
# ---------------------------------------------------------------------------
Update-FieldVisibility
Load-InitialData

[void]$form.ShowDialog()
$form.Dispose()
