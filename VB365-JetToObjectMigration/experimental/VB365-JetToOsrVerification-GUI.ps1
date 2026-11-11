<#
.SYNOPSIS
	GUI wrapper to verify a Jet to Object Storage Repository migration by comparing inventory reports.

.DESCRIPTION
    This script validates a JET-to-Object-Storage migration by generating inventory
    reports for both the source (JET) and target (object storage) repositories and
    comparing them for discrepancies. It provides a graphical front end for selection.

    The script asks the operator to select:
    - The Organization to verify.
    - The validation scope: an entire Organization or a single Job.
    - The source repository (a JET/block repository that is not backed by object storage).
    - The target repository (a repository backed by object storage).

    It then uses Get-VBORepositoryInventoryReport to produce inventory reports for the
    latest restore point on both repositories (including all versions and deleted items)
    and compares the following data types between source and target:
    - Mailboxes
    - SharePoint Sites
    - Teams
    - OneDrive

    Any mismatch in item counts or identifiers is reported, indicating that the migration
    may not have copied all data successfully.

    Prerequisites:
    - Run on a VB365 server (or a host with the VB365 PowerShell module installed).
    - PowerShell 7 is required (the script uses the ternary operator).
  

.OUTPUTS
	Inventory reports written to the selected report path and a pass/fail verification result with any detected
	differences shown in the output box.

.NOTES
	NAME:  VB365-JetToOsrVerification-GUI.ps1
	VERSION: 0.5
	AUTHOR: TBD, David Bewernick
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

# Force the endpoint handshake to complete now, while only the Veeam stack is loaded.
$null = Get-VBOOrganization -ErrorAction SilentlyContinue

# Now load the WinForms assemblies on top of the already-initialised gRPC stack.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------------------
# Build the form
# ---------------------------------------------------------------------------
$form                 = New-Object System.Windows.Forms.Form
$form.Text            = "VB365 - Jet to Object Storage Verification"
$form.Size            = New-Object System.Drawing.Size(960, 680)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox     = $false

$font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Font = $font

# --- Output box (colored) ----------------------------------------------------
$txtOutput            = New-Object System.Windows.Forms.RichTextBox
$txtOutput.ReadOnly   = $true
$txtOutput.Location   = New-Object System.Drawing.Point(15, 400)
$txtOutput.Size       = New-Object System.Drawing.Size(915, 230)
$txtOutput.Font       = New-Object System.Drawing.Font("Consolas", 9)
$txtOutput.BackColor  = [System.Drawing.Color]::White
$form.Controls.Add($txtOutput)

# GUI logging helpers (mirror INFO / SUCCESS / WARNING colors of the original script).
function Write-Log {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")][string]$Level = "INFO"
    )
    $colors = @{
        "INFO"    = [System.Drawing.Color]::Black
        "SUCCESS" = [System.Drawing.Color]::Green
        "WARNING" = [System.Drawing.Color]::DarkOrange
        "ERROR"   = [System.Drawing.Color]::Red
    }
    $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $txtOutput.SelectionStart  = $txtOutput.TextLength
    $txtOutput.SelectionLength = 0
    $txtOutput.SelectionColor  = $colors[$Level]
    $txtOutput.AppendText("[$stamp] [$Level] $Message`r`n")
    $txtOutput.SelectionColor  = $txtOutput.ForeColor
    $txtOutput.ScrollToCaret()
    $txtOutput.Refresh()
}
function Write-LogInfo($Message)    { Write-Log -Message $Message -Level "INFO" }
function Write-LogSuccess($Message) { Write-Log -Message $Message -Level "SUCCESS" }
function Write-LogWarning($Message) { Write-Log -Message $Message -Level "WARNING" }
function Write-LogError($Message)   { Write-Log -Message $Message -Level "ERROR" }

# Print comparison differences into the output box as a formatted table.
function Format-ComparisonDifferences {
    param(
        [Parameter(Mandatory=$true)][object]$DiffObject,
        [Parameter(Mandatory=$true)][string]$DataType
    )
    Write-LogWarning "$DataType data mismatch detected! Differences:"
    $table = $DiffObject | Select-Object @{Name="Repository";Expression={
                 switch ($_.SideIndicator) {
                     "=>" { "Target" }
                     "<=" { "Source" }
                 }
             }}, * | Select-Object -ExcludeProperty SideIndicator | Format-Table -AutoSize | Out-String
    $txtOutput.AppendText($table.TrimEnd() + "`r`n")
    $txtOutput.ScrollToCaret()
    $txtOutput.Refresh()
}

# Compare data between source and target inventories.
function Compare-InventoryData {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyString()][AllowNull()][string]$SourceInventoryReport,
        [Parameter(Mandatory=$true)][AllowEmptyString()][AllowNull()][string]$TargetInventoryReport,
        [Parameter(Mandatory=$true)][string]$DataType,
        [Parameter(Mandatory=$true)][string[]]$CompareProperties
    )
    $SourceInventoryReportIsMissing = [string]::IsNullOrEmpty($SourceInventoryReport)
    $TargetInventoryReportIsMissing = [string]::IsNullOrEmpty($TargetInventoryReport)

    if (-not $SourceInventoryReportIsMissing -and -not $TargetInventoryReportIsMissing) {
        Write-LogInfo "Comparing $DataType..."
        $sourceCsv = Import-Csv -Path $SourceInventoryReport
        $targetCsv = Import-Csv -Path $TargetInventoryReport
        $diff = Compare-Object -ReferenceObject $sourceCsv -DifferenceObject $targetCsv -Property $CompareProperties
        return $diff
    } else {
        $missingReports = @()
        if ($SourceInventoryReportIsMissing) { $missingReports += "Source" }
        if ($TargetInventoryReportIsMissing) { $missingReports += "Target" }
        $missingText = $missingReports -join " and "

        if ((-not $SourceInventoryReportIsMissing -and $TargetInventoryReportIsMissing) -or ($SourceInventoryReportIsMissing -and -not $TargetInventoryReportIsMissing)) {
            if (-not $SourceInventoryReportIsMissing) { $presentReport = "Source" }
            if (-not $TargetInventoryReportIsMissing) { $presentReport = "Target" }
            Write-LogWarning "$DataType report found only in $presentReport inventory, but is missing in $missingText inventory. Skipping $DataType comparison. This may happen e.g. when you were migrating data for specific Job, but verifying data for whole Organization."
        } else {
            Write-LogInfo "No $DataType report found in $missingText inventory. Skipping $DataType comparison."
        }
        return $null
    }
}

# --- Report path -------------------------------------------------------------
$lblReport          = New-Object System.Windows.Forms.Label
$lblReport.Text     = "Report path:"
$lblReport.Location = New-Object System.Drawing.Point(15, 20)
$lblReport.Size     = New-Object System.Drawing.Size(160, 22)
$form.Controls.Add($lblReport)

$txtReport          = New-Object System.Windows.Forms.TextBox
$txtReport.Location = New-Object System.Drawing.Point(180, 17)
$txtReport.Size     = New-Object System.Drawing.Size(650, 22)
$txtReport.Text     = "C:\VBOMigrationReports"
$form.Controls.Add($txtReport)

$btnBrowse          = New-Object System.Windows.Forms.Button
$btnBrowse.Text     = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(835, 16)
$btnBrowse.Size     = New-Object System.Drawing.Size(95, 24)
$form.Controls.Add($btnBrowse)

# --- Organization ------------------------------------------------------------
$lblOrg          = New-Object System.Windows.Forms.Label
$lblOrg.Text     = "Organization:"
$lblOrg.Location = New-Object System.Drawing.Point(15, 60)
$lblOrg.Size     = New-Object System.Drawing.Size(160, 22)
$form.Controls.Add($lblOrg)

$cmbOrg               = New-Object System.Windows.Forms.ComboBox
$cmbOrg.DropDownStyle = "DropDownList"
$cmbOrg.Location      = New-Object System.Drawing.Point(180, 57)
$cmbOrg.Size          = New-Object System.Drawing.Size(750, 22)
$form.Controls.Add($cmbOrg)

# --- Validation type ---------------------------------------------------------
$lblType          = New-Object System.Windows.Forms.Label
$lblType.Text     = "Validation type:"
$lblType.Location = New-Object System.Drawing.Point(15, 100)
$lblType.Size     = New-Object System.Drawing.Size(160, 22)
$form.Controls.Add($lblType)

$cmbType               = New-Object System.Windows.Forms.ComboBox
$cmbType.DropDownStyle = "DropDownList"
$cmbType.Location      = New-Object System.Drawing.Point(180, 97)
$cmbType.Size          = New-Object System.Drawing.Size(750, 22)
[void]$cmbType.Items.Add("Organization")
[void]$cmbType.Items.Add("Job")
$cmbType.SelectedIndex = 0
$form.Controls.Add($cmbType)

# --- Job (shown when validation type = Job) ----------------------------------
$lblJob          = New-Object System.Windows.Forms.Label
$lblJob.Text     = "Job:"
$lblJob.Location = New-Object System.Drawing.Point(15, 140)
$lblJob.Size     = New-Object System.Drawing.Size(160, 22)
$form.Controls.Add($lblJob)

$cmbJob               = New-Object System.Windows.Forms.ComboBox
$cmbJob.DropDownStyle = "DropDownList"
$cmbJob.Location      = New-Object System.Drawing.Point(180, 137)
$cmbJob.Size          = New-Object System.Drawing.Size(750, 22)
$form.Controls.Add($cmbJob)

# --- Source repository -------------------------------------------------------
$lblSource          = New-Object System.Windows.Forms.Label
$lblSource.Text     = "Source Repository:"
$lblSource.Location = New-Object System.Drawing.Point(15, 180)
$lblSource.Size     = New-Object System.Drawing.Size(160, 22)
$form.Controls.Add($lblSource)

$cmbSource               = New-Object System.Windows.Forms.ComboBox
$cmbSource.DropDownStyle = "DropDownList"
$cmbSource.Location      = New-Object System.Drawing.Point(180, 177)
$cmbSource.Size          = New-Object System.Drawing.Size(750, 22)
$form.Controls.Add($cmbSource)

# --- Target repository -------------------------------------------------------
$lblTarget          = New-Object System.Windows.Forms.Label
$lblTarget.Text     = "Target Repository:"
$lblTarget.Location = New-Object System.Drawing.Point(15, 220)
$lblTarget.Size     = New-Object System.Drawing.Size(160, 22)
$form.Controls.Add($lblTarget)

$cmbTarget               = New-Object System.Windows.Forms.ComboBox
$cmbTarget.DropDownStyle = "DropDownList"
$cmbTarget.Location      = New-Object System.Drawing.Point(180, 217)
$cmbTarget.Size          = New-Object System.Drawing.Size(750, 22)
$form.Controls.Add($cmbTarget)

# --- Buttons -----------------------------------------------------------------
$btnRefresh          = New-Object System.Windows.Forms.Button
$btnRefresh.Text     = "Refresh"
$btnRefresh.Location = New-Object System.Drawing.Point(180, 260)
$btnRefresh.Size     = New-Object System.Drawing.Size(120, 30)
$form.Controls.Add($btnRefresh)

$btnVerify          = New-Object System.Windows.Forms.Button
$btnVerify.Text     = "Verify Migration"
$btnVerify.Location = New-Object System.Drawing.Point(310, 260)
$btnVerify.Size     = New-Object System.Drawing.Size(150, 30)
$form.Controls.Add($btnVerify)

$btnQuit          = New-Object System.Windows.Forms.Button
$btnQuit.Text     = "Quit"
$btnQuit.Location = New-Object System.Drawing.Point(470, 260)
$btnQuit.Size     = New-Object System.Drawing.Size(120, 30)
$form.Controls.Add($btnQuit)

$lblOutput          = New-Object System.Windows.Forms.Label
$lblOutput.Text     = "Output:"
$lblOutput.Location = New-Object System.Drawing.Point(15, 375)
$lblOutput.Size     = New-Object System.Drawing.Size(160, 22)
$form.Controls.Add($lblOutput)

# ---------------------------------------------------------------------------
# Data loading / event logic
# ---------------------------------------------------------------------------

# Toggle the Job field based on the validation type.
function Update-FieldVisibility {
    $isJob = ($cmbType.SelectedItem -eq "Job")
    $lblJob.Visible = $isJob
    $cmbJob.Visible = $isJob
}

# Populate the organization-dependent lists (jobs / source / target repositories).
function Load-OrgDependentData {
    $cmbJob.Items.Clear()
    $cmbSource.Items.Clear()
    $cmbTarget.Items.Clear()

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

        # Object storage target repositories holding data for the selected organization
        $script:targetRepos = @(Get-VBORepository |
            Where-Object { ($_.ObjectStorageRepository -ne $null) -and
                           ((Get-VBOEntityData -Repository $_ -Type Organization -Name $organization.Name) -ne $null) } |
            Sort-Object Name)
        foreach ($r in $script:targetRepos) { [void]$cmbTarget.Items.Add($r.Name) }
        if ($cmbTarget.Items.Count -gt 0) { $cmbTarget.SelectedIndex = 0 }

        Write-LogInfo ("Loaded {0} job(s), {1} source and {2} target repository(ies) for organization '{3}'." -f `
            $script:jobs.Count, $script:sourceRepos.Count, $script:targetRepos.Count, $organization.Name)
    }
    catch {
        Write-LogError ("Error loading data for organization: {0}" -f $_.Exception.Message)
    }
}

# Load organizations.
function Load-InitialData {
    $cmbOrg.Items.Clear()
    try {
        $script:orgs = @(Get-VBOOrganization | Sort-Object Name)
        foreach ($o in $script:orgs) { [void]$cmbOrg.Items.Add($o.Name) }
        Write-LogInfo ("Loaded {0} organization(s)." -f $script:orgs.Count)
        if ($cmbOrg.Items.Count -gt 0) {
            $cmbOrg.SelectedIndex = 0   # triggers Load-OrgDependentData
        }
    }
    catch {
        Write-LogError ("Error loading organizations: {0}" -f $_.Exception.Message)
    }
}

# --- Wire up events ----------------------------------------------------------
$cmbType.Add_SelectedIndexChanged({ Update-FieldVisibility })
$cmbOrg.Add_SelectedIndexChanged({ Load-OrgDependentData })
$btnRefresh.Add_Click({ Load-InitialData })
$btnQuit.Add_Click({ $form.Close() })

$btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the report output path"
    if (Test-Path $txtReport.Text) { $dialog.SelectedPath = $txtReport.Text }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtReport.Text = $dialog.SelectedPath
    }
})

$btnVerify.Add_Click({
    # Validate selections
    if ($cmbOrg.SelectedItem -eq $null)    { Write-LogWarning "Please select an organization."; return }
    if ($cmbSource.SelectedItem -eq $null) { Write-LogWarning "Please select a source repository."; return }
    if ($cmbTarget.SelectedItem -eq $null) { Write-LogWarning "Please select a target repository."; return }
    if ([string]::IsNullOrWhiteSpace($txtReport.Text)) { Write-LogWarning "Please specify a report path."; return }

    $reportPath       = $txtReport.Text
    $organization     = $script:orgs[$cmbOrg.SelectedIndex]
    $sourceRepository = $script:sourceRepos[$cmbSource.SelectedIndex]
    $targetRepository = $script:targetRepos[$cmbTarget.SelectedIndex]
    $isJob            = ($cmbType.SelectedItem -eq "Job")

    if ($isJob) {
        if ($cmbJob.SelectedItem -eq $null) { Write-LogWarning "Please select a job."; return }
        $selectedJob               = $script:jobs[$cmbJob.SelectedIndex]
        $validationType            = "Job"
        $inventoryDataIdColumnName = "Backup Job Id"
    }
    else {
        $validationType            = "Organization"
        $inventoryDataIdColumnName = "Organization Id"
    }

    $btnVerify.Enabled  = $false
    $btnRefresh.Enabled = $false
    try {
        if (-not (Test-Path $reportPath)) {
            Write-LogInfo "Creating report path '$reportPath'..."
            New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
        }

        # Verify Data Migration (compare inventory reports)
        $latestRestorePoint = Get-VBORestorePoint -Repository $sourceRepository -Latest

        Write-LogInfo "Generating inventory reports for source repository..."
        if ($validationType -eq "Organization") {
            $sourceInventory = Get-VBORepositoryInventoryReport -OutputPath $reportPath -BackupTime $latestRestorePoint.BackupTime -Repository $sourceRepository -Organization $organization -IncludeAllVersions -IncludeDeleted
        } else {
            $sourceInventory = Get-VBORepositoryInventoryReport -OutputPath $reportPath -BackupTime $latestRestorePoint.BackupTime -Repository $sourceRepository -Job $selectedJob -IncludeAllVersions -IncludeDeleted
        }

        Write-LogInfo "Generating inventory reports for target repository..."
        if ($validationType -eq "Organization") {
            $targetInventory = Get-VBORepositoryInventoryReport -OutputPath $reportPath -BackupTime $latestRestorePoint.BackupTime -Repository $targetRepository -Organization $organization -IncludeAllVersions -IncludeDeleted
        } else {
            $targetInventory = Get-VBORepositoryInventoryReport -OutputPath $reportPath -BackupTime $latestRestorePoint.BackupTime -Repository $targetRepository -Job $selectedJob -IncludeAllVersions -IncludeDeleted
        }

        # Compare Mailboxes
        $mailDiff = Compare-InventoryData -SourceInventoryReport ($sourceInventory ? $sourceInventory.MailboxesReport : $null) -TargetInventoryReport ($targetInventory ? $targetInventory.MailboxesReport : $null) -DataType "Mailboxes" -CompareProperties @($inventoryDataIdColumnName, "Mailbox ID", "Mailbox Name", "Mailbox Folder Count", "Mailbox Item Count")

        # Compare SharePoint Sites
        $websDiff = Compare-InventoryData -SourceInventoryReport ($sourceInventory ? $sourceInventory.RootWebsReport : $null) -TargetInventoryReport ($targetInventory ? $targetInventory.RootWebsReport : $null) -DataType "SharePoint Sites" -CompareProperties @($inventoryDataIdColumnName, "Site ID", "Root Site ID", "Root Site URL", "Root Site Hierarchy Item Version Count")

        # Compare Teams
        $teamsDiff = Compare-InventoryData -SourceInventoryReport ($sourceInventory ? $sourceInventory.TeamsReport : $null) -TargetInventoryReport ($targetInventory ? $targetInventory.TeamsReport : $null) -DataType "Teams" -CompareProperties @($inventoryDataIdColumnName, "Team ID", "Team Name", "Team Channel Message Count", "Team Tab Count", "Team Channel Count", "Team File Count", "Team User Count")

        # Compare OneDrive
        $oneDrivesDiff = Compare-InventoryData -SourceInventoryReport ($sourceInventory ? $sourceInventory.OneDrivesReport : $null) -TargetInventoryReport ($targetInventory ? $targetInventory.OneDrivesReport : $null) -DataType "OneDrive" -CompareProperties @($inventoryDataIdColumnName, "Account Name", "OneDrive Item Count")

        # Print all differences, if any
        $hasDiff = $false
        if ($mailDiff)      { Format-ComparisonDifferences -DiffObject $mailDiff      -DataType "Mailboxes";  $hasDiff = $true }
        if ($websDiff)      { Format-ComparisonDifferences -DiffObject $websDiff      -DataType "SharePoint"; $hasDiff = $true }
        if ($teamsDiff)     { Format-ComparisonDifferences -DiffObject $teamsDiff     -DataType "Teams";      $hasDiff = $true }
        if ($oneDrivesDiff) { Format-ComparisonDifferences -DiffObject $oneDrivesDiff -DataType "OneDrive";   $hasDiff = $true }

        if ($hasDiff) {
            Write-LogError "Data verification failed! See above for details on mismatches."
        } else {
            Write-LogSuccess "Data verification completed successfully. No differences found."
        }
    }
    catch {
        Write-LogError ("Verification error: {0}" -f $_.Exception.Message)
    }
    finally {
        $btnVerify.Enabled  = $true
        $btnRefresh.Enabled = $true
    }
})

# ---------------------------------------------------------------------------
# Initialize and show
# ---------------------------------------------------------------------------
Update-FieldVisibility
Load-InitialData

[void]$form.ShowDialog()
$form.Dispose()
