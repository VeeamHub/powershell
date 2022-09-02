param(
    $jsonsrc = "internal"
)

write-host "Loading, if this is the first time you started superedit in this session, connection has to be made to VBR and this might take a while"
Add-Type -AssemblyName PresentationFramework
[xml]$xaml = @"
<Window 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="SuperEditv2" Height="450" Width="800" Title="SuperEdit">
    <Window.Resources>
        <Style TargetType="{x:Type GridViewColumnHeader}">
            <Setter Property="HorizontalContentAlignment" Value="Left" />
        </Style>
    </Window.Resources>
    <Grid>
        <CheckBox x:Name="selectall" Content="Select All" Margin="0,14,16,0" VerticalAlignment="Top" Height="25" IsChecked="True" HorizontalAlignment="Right" Width="70"/>
        <ComboBox x:Name="modselection" Margin="10,10,108,0" VerticalAlignment="Top" Height="25" DisplayMemberPath="Name" />
        <ComboBox x:Name="modkey" HorizontalAlignment="Left" Margin="10,0,0,10" VerticalAlignment="Bottom" Height="25" Width="220" DisplayMemberPath="Name"/>
        <ComboBox x:Name="modval" HorizontalAlignment="Left" Margin="240,0,0,10" Width="220" Height="25" VerticalAlignment="Bottom" Grid.ColumnSpan="3" />

        <Button Visibility="Hidden" x:Name="review" Content="Review" Margin="0,0,115,10"  Height="25" Width="100" VerticalAlignment="Bottom" HorizontalAlignment="Right" Grid.Column="2"/>
        <Button x:Name="execute" Content="Generate" Margin="0,0,10,10" Height="25" Width="100" VerticalAlignment="Bottom" HorizontalAlignment="Right" Grid.Column="2"/>
        <ListView x:Name="selectionlist" Margin="10,81,10,50">
            <ListView.View>
                <GridView>
                    <GridViewColumn x:Name="select" Header="Select" HeaderStringFormat="Select" Width="50" >
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <CheckBox IsChecked="{Binding Include}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn x:Name="name" Header="Name" HeaderStringFormat="Name" DisplayMemberBinding="{Binding Name}" Width="600" >

                    </GridViewColumn>
                </GridView>
            </ListView.View>
        </ListView>
        <TextBox x:Name="scriptout" Margin="0,0,116,10" Text="superedit-batch.ps1" TextWrapping="Wrap" Height="25" VerticalAlignment="Bottom" HorizontalAlignment="Right" Width="168"/>
        <TextBox x:Name="namefilter" Margin="128,44,10,0" TextWrapping="Wrap" VerticalAlignment="Top"/>
        <Label x:Name="lblnamefilter" Content="Name Filter" HorizontalAlignment="Left" Margin="10,40,0,0" VerticalAlignment="Top" RenderTransformOrigin="-0.184,0.04" Height="26" Width="118"/>
    </Grid>
</Window>

"@


$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)


$modselection = $window.FindName("modselection")
$selectall = $window.FindName("selectall")
$selectionlist = $window.FindName("selectionlist")
$modkey = $window.FindName("modkey")
$modval = $window.FindName("modval")
$execute = $window.FindName("execute")
$outpath = $window.FindName("scriptout")
$namefilter = $window.FindName("namefilter")


$modselectionitemsjson = @"
[{
		"Name": "Generic Backup Jobs",
        "ListExpression": "get-vbrjob | ? { `$_.jobtype -in @([Veeam.Backup.Model.EDbJobType]::Backup) }",
        "NamePath": "name",
		"IdPath": "id",
        "IdConvert": "string",
		"Actions": [{
				"Name": "Retention in points",
				"Values": [],
                "ValueExpression": "(1..99)",
                "ValueConvert": "int",
				"PreExpression": "# Retention Point Script
`$jobs = get-vbrjob
function Set-SECyclesRetention {
  param(`$job,`$val) 
  `$o = `$job | Get-VBRJobOptions
  `$o.BackupStorageOptions.RetentionType = [Veeam.Backup.Model.ERetentionType]::Cycles
  `$o.BackupStorageOptions.RetainCycles = `$val
  `$job | Set-VBRJobOptions -Options `$o
}

`$supereditval = ##val##
`$idlist = @()
",
				"ForEachExpression": "`$idlist += ##id##",
				"PostExpression": "
foreach (`$job in (`$jobs | ? { `$_.id -in `$idlist} )) {
    Set-SECyclesRetention -job `$job -val `$supereditval
}
"
			},{
				"Name": "Retention in days",
				"Values": [],
                "ValueExpression": "(1..99)",
                "ValueConvert": "int",
				"PreExpression": "# Retention Day Script
`$jobs = get-vbrjob
function Set-SEDaysRetention {
  param(`$job,`$val) 
  `$o = `$job | Get-VBRJobOptions
  `$o.BackupStorageOptions.RetentionType = [Veeam.Backup.Model.ERetentionType]::Days
  `$o.BackupStorageOptions.RetainDaysToKeep = `$val
  `$job | Set-VBRJobOptions -Options `$o
}


`$supereditval = ##val##
`$idlist = @()
",
				"ForEachExpression": "`$idlist += ##id##",
				"PostExpression": "
foreach (`$job in (`$jobs | ? { `$_.id -in `$idlist} )) {
    Set-SEDaysRetention -job `$job -val `$supereditval
}
"
			},
			{
				"Name": "Storage Block Size",
				"Values": [],
                "ValueConvert": "string",
                "ValueExpression": "([Veeam.Backup.Common.EKbBlockSize]::GetValues([Veeam.Backup.Common.EKbBlockSize]))",
                "PreExpression": "# BlockSize Edit
`$jobs = get-vbrjob
function Set-SEBlockSize {
  param(`$job,`$val) 
  `$o = `$job | Get-VBRJobOptions
  `$o.BackupStorageOptions.StgBlockSize = `$val
  `$job | Set-VBRJobOptions -Options `$o
}


`$supereditval = ##val##
`$idlist = @()
",
                "ForEachExpression": "`$idlist += ##id##",
				"PostExpression": "
foreach (`$job in (`$jobs | ? { `$_.id -in `$idlist} )) {
    Set-SEBlockSize -job `$job -val `$supereditval
}
"
			}
		]
	},
	{
        "Name": "Generic Simple Backup Copy Jobs",
        "ListExpression": "`get-vbrjob | ? { `$_.jobtype -in @([Veeam.Backup.Model.EDbJobType]::SimpleBackupCopyPolicy) }",
        "NamePath": "name",
		"IdPath": "id",
        "IdConvert": "string",
		"Actions": [{
				"Name": "Retention in points",
				"Values": [],
                "ValueExpression": "(1..99)",
                "ValueConvert": "int",
				"PreExpression": "# Retention Point Script
`$jobs = get-vbrjob
function Set-SECyclesRetention {
  param(`$job,`$val) 
  `$o = `$job | Get-VBRJobOptions
  `$o.BackupStorageOptions.RetentionType = [Veeam.Backup.Model.ERetentionType]::Cycles
  `$o.BackupStorageOptions.RetainCycles = `$val
  `$job | Set-VBRJobOptions -Options `$o
}

`$supereditval = ##val##
`$idlist = @()
",
				"ForEachExpression": "`$idlist += ##id##",
				"PostExpression": "
foreach (`$job in (`$jobs | ? { `$_.id -in `$idlist} )) {
    Set-SECyclesRetention -job `$job -val `$supereditval
}
"
			},{
				"Name": "Retention in days",
				"Values": [],
                "ValueExpression": "(1..99)",
                "ValueConvert": "int",
				"PreExpression": "# Retention Day Script
`$jobs = get-vbrjob
function Set-SEDaysRetention {
  param(`$job,`$val) 
  `$o = `$job | Get-VBRJobOptions
  `$o.BackupStorageOptions.RetentionType = [Veeam.Backup.Model.ERetentionType]::Days
  `$o.BackupStorageOptions.RetainDaysToKeep = `$val
  `$job | Set-VBRJobOptions -Options `$o
}


`$supereditval = ##val##
`$idlist = @()
",
				"ForEachExpression": "`$idlist += ##id##",
				"PostExpression": "
foreach (`$job in (`$jobs | ? { `$_.id -in `$idlist} )) {
    Set-SEDaysRetention -job `$job -val `$supereditval
}
"
			}
        ]
	},
    {
        "Name": "VMware Proxies",
        "ListExpression": "`get-vbrviproxy",
        "NamePath": "name",
		"IdPath": "id",
        "IdConvert": "string",
		"Actions": [{
				"Name": "Task Slot",
				"Values": [],
                "ValueExpression": "(1..99)",
                "ValueConvert": "int",
				"PreExpression": "# VI Proxy Tasks Slots
`$totallist = (get-vbrviproxy)
`$supereditval = ##val##
`$idlist = @()
",
				"ForEachExpression": "`$idlist += ##id##",
				"PostExpression": "
foreach (`$o in (`$totallist | ? { `$_.id -in `$idlist} )) {
    `$o | Set-VBRViProxy -MaxTasks `$supereditval
}
"
			}]
    }
]
"@ 

$modselectionitems = $modselectionitemsjson | ConvertFrom-Json


if ($jsonsrc -ne "internal") {
    $error = $false

    if ($jsonsrc -match "^http[s]?://") {
        write-host "Downloading script file from $jsonsrc"
        $data = invoke-webrequest $jsonsrc
        if ($data -ne "" -and $data.BaseResponse.StatusCode -eq "ok") {
            $convertfromjson = $data.Content | ConvertFrom-Json
            if ($convertfromjson) {
                $modselectionitems =  $convertfromjson
                write-host "Got Valid Remote JSON From $jsonsrc"
            } else {
                write-host "Conversion Failed for $jsonsrc"
                $error = $true
            }
        } else {
            write-host "Verify URL $jsonsrc"
            $error = $true
        }
    } elseif (Test-Path -Path $jsonsrc -PathType Leaf) {
        $convertfromjson = (Get-Content $jsonsrc) | ConvertFrom-Json
        if ($convertfromjson) {
            $modselectionitems =  $convertfromjson
            write-host "Got Valid Remote JSON From $jsonsrc"
        } else {
                write-host "Conversion Failed for $jsonsrc"
                $error = $true
        }
    } else {
            write-host "Verify $jsonsrc, it is not an url nor a path"
            $error = $true
    }
    if ($error) { write-host "Got error, using embedded json" }
}



$modselection.Items.Clear()

foreach($modselectionitem in $modselectionitems) {
    $m = new-object -TypeName psobject -Property @{Name=$modselectionitem.name; ;OriginalObject=$modselectionitem}
    $modselection.Items.add($m) | Out-Null
}

$modselection.SelectedIndex = 0




function Update-ValueList {
    $selected = $modkey.SelectedValue
    if ($selected) {
        $modval.Items.Clear()

        $values = $selected.OriginalObject.Values
        
        if (-not $values) {
            $values = @()
        }

        $valexpression = $selected.OriginalObject.ValueExpression
        if($valexpression -and $valexpression -ne "") {
            foreach ($newval in (Invoke-Expression -Command $valexpression)) {
                $values += $newval
            }
        } 

        foreach($val in $values) {
            $modval.items.add($val) | Out-Null
        }
        if (-not $modval.Items.IsEmpty) {
            $modval.SelectedIndex = 0
        }
        
    }
}

function Update-SelectAll {
    $c = $selectall.IsChecked
    foreach($item in $selectionlist.Items) {
        $item.Include = $c
    }
    $selectionlist.items.Refresh()
   
}

#update the selection table (the big thing in the middle)
function Update-SelectionList {
        param($updatelistonly=$false)

        $selectionlist.Items.Clear()
        $modselected = $modselection.SelectedValue.OriginalObject

        $npath = $modselected.NamePath
        $newlist = Invoke-Expression  $modselected.ListExpression
        
        $nf = $namefilter.Text

        foreach($item in $newlist) {
            $passedfilters = $true
            $name = $item."$npath"

            if($passedfilters -and $nf -ne "") {
                $passedfilters = ($name -match $nf)
            }

            if ($passedfilters) {
                $listitem = new-object -TypeName psobject -Property @{Name=$name;Include=$false;OriginalObject=$item}
                $selectionlist.Items.Add($listitem) | Out-Null
            }
        }

        if (-not $updatelistonly) {
            $modkey.Items.Clear()
            foreach($action in $modselected.Actions) {
                    $action = new-object -TypeName psobject -Property @{Name=$action.Name;Id=$selected.Id;SubId=$action.SubId;OriginalObject=$action}
                    $modkey.Items.Add($action) | Out-Null 
            }
            if (-not $modkey.Items.IsEmpty) {
                $modkey.SelectedIndex = 0
                Update-ValueList
            }
        }

        Update-SelectAll
}


function Update-SelectionListAfterNameChange {
    Update-SelectionList -updatelistonly $true  
}

function Convert-ToScriptOutput {
    param ($c,$v)

    switch ($c) {
      "string" {
        return ('"{0}"' -f $v)
      }
      "int" {
        return [int]$v
      }
      "bool" {
        return $v -eq $true
      }
    }
}

function Invoke-ExecutionEngine {
    $mod = $modkey.SelectedValue.OriginalObject
    $js = $modselectionitems[$modselection.SelectedIndex]
    
    $itemlist = $selectionlist.Items | ? { $_.Include }
   

    $selval = (Convert-ToScriptOutput -c $mod.ValueConvert -v $modval.SelectedValue)
    $expr = $mod.ForEachExpression

    $idpath =  $js.IdPath

    $script = @()
    $script += ("# Generated with SuperEdit v2 on {0} " -f (get-date).ToString())
    $script += ("#")
    $script += $mod.PreExpression  -replace "##val##","$selval"
    foreach ($litem in $itemlist) {
        $item = $litem.OriginalObject
        $objectid = (Convert-ToScriptOutput -c $js.IdConvert -v ($item."$idpath"))
       

        $script += ("# {0}" -f $litem.Name)
        
        $script += $mod.ForEachExpression -replace "##id##",$objectid -replace "##val##","$selval"
    }
    $script += $mod.PostExpression  -replace "##val##","$selval"
    
    $pspath = "scripts.ps1"
    if ($outpath.Text -ne "") {
        $pspath = $outpath.Text
    }

    $script -join "`n" | Set-Content $pspath
    [System.Windows.MessageBox]::Show("Script should be generated under $pspath") | out-null

}


#update now and in the future
Update-SelectionList 
$modselection.Add_SelectionChanged({Update-SelectionList})


Update-SelectAll
$selectall.Add_Checked({Update-SelectAll})
$selectall.Add_Unchecked({Update-SelectAll})
$modkey.Add_SelectionChanged({Update-ValueList})


$namefilter.Add_KeyDown({if ($_.Key -eq "Enter") {Update-SelectionListAfterNameChange}})



$execute.Add_Click({Invoke-ExecutionEngine})

 

$show = $window.ShowDialog()

