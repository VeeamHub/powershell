param(
    [switch]$nogui
)
Add-PSSnapIn veeampssnapin



class NasMultiplexSelectClass {
    [string]$Name
    [string]$Value
    NasMultiplexSelectClass([string]$iName,[string]$iValue){
        $this.Name = $iName
        $this.Value = $iValue
    }
    [string] ToString() {
        return $this.Name
    }   
}
function Sync-NasMultiplexDialogBase {
    param($cmbsample,$inpbase,$altbox)


    $val = $cmbsample.SelectedValue.Value
    if ($val -match "^([a-z0-9-]+)/(.*)$") {
        $s = Get-VBRNASServer  -Id  $Matches[1]
        if ($s) {
            if ($s.Processingmode -eq [Veeam.Backup.PowerShell.Cmdlets.VBRNASProcessingMode]::StorageSnapshot) {
                $altbox.IsEnabled=$true
            } else {
                $altbox.IsEnabled=$false
            }

            if ($s.Type -eq [Veeam.Backup.PowerShell.Cmdlets.VBRNASServerType]::SMB) {
                if($s.Path -match "^(\\\\.*\\)[^\\]+[\\]?$") {
                    $inpbase.Text = $Matches[1]
                }

            } else {
                $inpbase.Text = $s.Path
            }
        } else {
            $inpbase.Text = $Matches[2]
        }
    } else {
        $inpbase.Text = ""
    }

    
}

function Add-NasMultiplexShares {
    param(
    [Veeam.Backup.PowerShell.Cmdlets.VBRNASBackupJob]$targetjob,
    [Veeam.Backup.PowerShell.Cmdlets.VBRNASBackupJobObject]$refobject,
    [string]$prefix,
    [string[]]$arrshares,
    [string]$altpath='{0}{1}\.snapshot'
    )

    $newshares = @()
    foreach($path in $arrshares) {
        $fullpath = ("{0}{1}" -f $prefix,$path)

        $newshare = $null
        $s = $refobject.Server

        #splatting https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting?view=powershell-5.1
        $splattingcall = @{
            Path=$fullpath
            cacherepository=$s.CacheRepository
            AccessCredentials=$s.AccessCredentials
            BackupIOControlLevel=$s.BackupIOControlLevel
            EnableDirectBackupFailover=$s.DirectBackupFailoverEnabled
            ProcessingMode=[Veeam.Backup.PowerShell.Cmdlets.VBRNASProcessingMode]::Direct
            ProxyMode=$s.ProxyMode
        }
        if ($s.ProcessingMode -eq [Veeam.Backup.PowerShell.Cmdlets.VBRNASProcessingMode]::VSSSnapshot) {
            $splattingcall.ProcessingMode = [Veeam.Backup.PowerShell.Cmdlets.VBRNASProcessingMode]::VSSSnapshot
        } elseif ($s.ProcessingMode -eq [Veeam.Backup.PowerShell.Cmdlets.VBRNASProcessingMode]::StorageSnapshot -and $altpath -ne "") {
            $splattingcall.ProcessingMode = [Veeam.Backup.PowerShell.Cmdlets.VBRNASProcessingMode]::StorageSnapshot
            $splattingcall.StorageSnapshotPath = ($altpath -f $prefix,$path)
        } 
        

        if ($s.SelectedProxyServer.Count -gt 0) {
            $splattingcall.SelectedProxyServer = $s.SelectedProxyServer
        }


        $newshare = Add-VBRNASSMBServer @splattingcall
       
        if ($newshare) {
            $newshares += $newshare
        } else {
            write-error "something went wrong for $fullpath"
        }
    }

    $allobjects = $targetjob.BackupObject

  

    foreach($ns in $newshares) {
        $splattingcall = @{
            server=$ns
            path=$ns.path
            inclusionmask=$refobject.InclusionMask
        }
        $bo = New-VBRNASBackupJobObject @splattingcall
        if ($bo) { $allobjects += $bo }

    }



    Set-VBRNASBackupJob -Job $targetjob -BackupObject $allobjects
}

function Start-NasMultiplexDialog {
    Add-Type -AssemblyName PresentationFramework
    [xml]$dialog = @"
<Window 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:NASMultiplex"

        Title="NASMultiPlex" x:Name="Window" Height="450" Width="800" MinWidth="800" MinHeight="450">
    <Grid>
        <Button Content="Add Shares" Margin="0,0,24,20" HorizontalAlignment="Right" Width="75" Height="20" VerticalAlignment="Bottom" Name="btnaddshares"/>
        <Grid Height="110" Margin="10,10,10,0" VerticalAlignment="Top">
            <ComboBox Margin="124,8,10,0" VerticalAlignment="Top" Height="21" Name="cmbtarget"/>
            <ComboBox Margin="124,34,10,0" VerticalAlignment="Top" Height="21" Name="cmbsample"/>
            <Label Content="Target Job" Margin="10,7,653,0" VerticalAlignment="Top"/>
            <Label Content="Sample Share" Margin="10,33,653,0" VerticalAlignment="Top"/>
            <Label Content="Base" Margin="10,60,653,0" VerticalAlignment="Top"/>
            <TextBox Height="23" Margin="124,0,10,27" TextWrapping="Wrap"  Text="\\share\" VerticalAlignment="Bottom" Name="inpbase"/>
            <Label Content="Altpath" Margin="10,86,653,-1" VerticalAlignment="Top" Height="25"/>
            <TextBox Height="23" Margin="124,0,10,-1" TextWrapping="Wrap" Text="{}{0}{1}\.snapshot" IsEnabled="false" VerticalAlignment="Bottom" x:Name="inpaltpath"/>
        </Grid>
        <TextBox Margin="20,137,20,61" TextWrapping="Wrap" AcceptsReturn="True" Text="share1" Name="inpshares" VerticalScrollBarVisibility="Visible" ScrollViewer.CanContentScroll="True"        />
    </Grid>
</Window>
"@

    $jobs = Get-VBRNASBackupJob

    $reader = (New-Object System.Xml.XmlNodeReader $dialog)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $cmbtarget = $window.FindName("cmbtarget")
    $cmbsample = $window.FindName("cmbsample")
    $inpbase = $window.FindName("inpbase")
    $inpshares = $window.FindName("inpshares")
    $inpaltpath = $window.FindName("inpaltpath")
    $cmbtarget.Add_SelectionChanged({
        $j = @($jobs | ? { $_.id -eq $cmbtarget.SelectedValue.Value })[0]
        $cmbsample.Items.Clear()
        
        
        foreach ($bo in @($j.BackupObject)) {
            $cmbsample.Items.Add([NasMultiplexSelectClass]::New($bo.Path,("{0}/{1}" -f $bo.Server.Id,$bo.Path)))  | Out-Null
        }

        $cmbsample.SelectedIndex = 0
        Sync-NasMultiplexDialogBase -cmbsample $cmbsample -inpbase $inpbase -altbox $inpaltpath
    })

    $cmbsample.Add_SelectionChanged({
        Sync-NasMultiplexDialogBase -cmbsample $cmbsample -inpbase $inpbase -altbox $inpaltpath
    })
    foreach ($j in $jobs) {
        $o=[NasMultiplexSelectClass]::New($j.Name,($j.id))
        $cmbtarget.Items.Add($o) | Out-Null
    }
    if ($cmbtarget.Items.Count -gt 0) {
        $cmbtarget.SelectedIndex = 0
    }

    $btnaddshares = $window.FindName("btnaddshares")
    $btnaddshares.Add_Click({
        $prefix = $inpbase.Text.trim()
        $shares = $inpshares.Text.split("`n") | % { $_.trim() } | ? { $_ -ne "" }
        $targetjob = (Get-VBRNASBackupJob -Id $cmbtarget.SelectedValue.Value)
        $refobject = $null

        if ($targetjob) {
            if ($cmbsample.SelectedValue.Value -match "^([a-z0-9-]+)/(.*)$") {
                $refobject = $targetjob.BackupObject | ? { $_.Path -eq $Matches[2] -and $_.Server.Id -eq $Matches[1] }
                if ($refobject) {
                    $btnaddshares.IsEnabled = $false
                    write-host $inpaltpath.Text.trim()
                    Add-NasMultiplexShares -targetjob  $targetjob -refobject $refobject -prefix $prefix -arrshares $shares -altpath $inpaltpath.Text.trim()
                    [System.Windows.MessageBox]::Show("Added Shares")
                    $btnaddshares.IsEnabled = $true
                } else {
                    Write-Error "Should not happen but couldn't find backupobject in target job"
                }
            } else {
                Write-Error "Should not happen but couldn't find backupobject"
            }
        } else {
            Write-Error "Should not happen but could not find targetjob"
        }
        
    })
    $window.ShowDialog() | Out-Null
}

if(-not $nogui) {
    Start-NasMultiplexDialog
}