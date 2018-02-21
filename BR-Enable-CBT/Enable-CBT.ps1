$Spec = New-Object VMware.Vim.VirtualMachineConfigSpec 
$Spec.ChangeTrackingEnabled = $true


$VMs = @((Get-View -ViewType VirtualMachine) | Where-Object {$_.Config.ChangeTrackingEnabled -eq $false} `
  | Select-Object *, @{Name="Change Block Tracking";Expression={if ($_.Config.ChangeTrackingEnabled) { "enabled" } else { "disabled" }}} `
  | Sort Name `
)

Foreach ($VMView in $VMs) {
  $isTemplate = $VMView.Config.Template -eq $True
  if ($isTemplate) {
    Set-Template $VMView.Name -ToVM
  }
  $VM = Get-VM $VMView.Name
  $VM.ExtensionData.ReconfigVM($Spec) 
  $Snap = $VM | New-Snapshot -Name 'Disable CBT' 
  Remove-Snapshot $Snap -Confirm:$False
  if ($isTemplate) {
    Set-VM $VM -ToTemplate -Confirm:$False
  }
}
