param(
    $jsonsrc = "internal",
    $cachejsonsrc = ""
)

#tls errors otherwise
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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
        <ComboBox x:Name="modval" HorizontalAlignment="Left" Margin="240,0,0,10" Width="220" Height="25" VerticalAlignment="Bottom" Grid.ColumnSpan="3"  />

        <Button Visibility="Hidden" x:Name="review" Content="Review" Margin="0,0,115,10"  Height="25" Width="100" VerticalAlignment="Bottom" HorizontalAlignment="Right" Grid.Column="2"/>
        <Button x:Name="execute" Content="Generate" Margin="0,0,10,10" Height="25" Width="100" VerticalAlignment="Bottom" HorizontalAlignment="Right" Grid.Column="2"/>
        <ListView x:Name="selectionlist" Margin="10,107,10,50">
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
        <Label x:Name="lblsupereidtagfilter" Content="SE Tag Filter" HorizontalAlignment="Left" Margin="10,66,0,0" VerticalAlignment="Top" RenderTransformOrigin="-0.184,0.04" Height="26" Width="118"/>
        <ComboBox x:Name="tagfilter" Margin="128,70,10,0" VerticalAlignment="Top" DisplayMemberPath="Name"/>
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
$tagfilter = $window.FindName("tagfilter")


$modselectionitemsjson = @"
[{
		"Name": "Generic Backup Jobs",
        "ListExpression": "get-vbrjob | ? { `$_.jobtype -in @([Veeam.Backup.Model.EDbJobType]::Backup) }",
        "TagPath": "description",
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
`$superedittag = ##tag##
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

`$superedittag = ##tag##
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

`$superedittag = ##tag##
`$supereditval = ##val##
`$idlist = @()
",
                "ForEachExpression": "`$idlist += ##id##",
				"PostExpression": "
foreach (`$job in (`$jobs | ? { `$_.id -in `$idlist} )) {
    Set-SEBlockSize -job `$job -val `$supereditval
}
"
			},
			{
				"Name": "Staggered startup time (min)",
				"Values": [],
                "ValueConvert": "string",
                "ValueExpression": "(1..60)",
                "PreExpression": "# Staggered startup time
`$jobs = get-vbrjob
function Set-SEStaggeredTime {
  param(`$job,`$i,`$minutes,`$start) 
  `$starttime = `$start.addMinutes(`$i*`$minutes)
  `$job | Set-VBRJobSchedule -Daily -At `$starttime
}

`$superedittag = ##tag##
`$supereditval = ##val##
`$idlist = @()
",
                "ForEachExpression": "`$idlist += ##id##",
				"PostExpression": "
`$i=0
`$minutes=`$supereditval
`$start = (get-date -Hour 22 -Minute 0 -Second 0 -Millisecond 0)
foreach (`$job in (`$jobs | ? { `$_.id -in `$idlist} )) {
    Set-SEStaggeredTime -job `$job -i `$i -minutes `$minutes -start `$start
    `$i = `$i+1
}
"
			}
		]
	},
	{
        "Name": "Generic Simple Backup Copy Jobs",
        "ListExpression": "`get-vbrjob | ? { `$_.jobtype -in @([Veeam.Backup.Model.EDbJobType]::SimpleBackupCopyPolicy) }",
        "TagPath": "description",
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
`$superedittag = ##tag##
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

`$superedittag = ##tag##
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
        "TagPath": "description",
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
`$superedittag = ##tag##
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


if ($cachejsonsrc -ne "" -and $jsonsrc -ne "internal") {
    if (-not (Test-Path -PathType Leaf $jsonsrc)) {
        write-host "Caching script file from $cachejsonsrc"
        $data = invoke-webrequest $cachejsonsrc
        if ($data -ne "" -and $data.BaseResponse.StatusCode -eq "ok") {
            $windowsfile = $data.Content  -replace "`r?`n","`r`n" 
            $convertfromjson = $windowsfile | ConvertFrom-Json
            if ($convertfromjson) {
                write-host "Conversion succeeded, writing the cache.."
                $windowsfile | set-content -Path $jsonsrc
            }
        }
    }
}

if ($jsonsrc -ne "internal") {
    $goterror = $false

    if ($jsonsrc -match "^http[s]?://") {
        write-host "Downloading script file from $jsonsrc"
        $data = invoke-webrequest $jsonsrc
        if ($data -ne "" -and $data.BaseResponse.StatusCode -eq "ok") {
            $convertfromjson = $data.Content  -replace "`r?`n","`r`n" | ConvertFrom-Json
            if ($convertfromjson) {
                $modselectionitems =  $convertfromjson
                write-host "Got Valid Remote JSON From $jsonsrc"
            } else {
                write-host "Conversion Failed for $jsonsrc"
                $goterror = $true
            }
        } else {
            write-host "Verify URL $jsonsrc"
            $goterror = $true
        }
    } elseif (Test-Path -Path $jsonsrc -PathType Leaf) {
        $convertfromjson = (Get-Content $jsonsrc) | ConvertFrom-Json
        if ($convertfromjson) {
            $modselectionitems =  $convertfromjson
            write-host "Got Valid Local JSON From $jsonsrc"
        } else {
                write-host "Conversion Failed for $jsonsrc"
                $goterror = $true
        }
    } else {
            write-host "Verify $jsonsrc, it is not an url nor a path"
            $goterror = $true
    }
    if ($goterror) { write-host "Got error, using embedded json" }
}



$modselection.Items.Clear()

foreach($modselectionitem in $modselectionitems) {
    $m = new-object -TypeName psobject -Property @{Name=$modselectionitem.name; ;OriginalObject=$modselectionitem}
    $modselection.Items.add($m) | Out-Null
}

$modselection.SelectedIndex = 0



#sample "fsdfds [location:antwerp]  sfds [support:gold]"
$global:tagmatch = [regex]::new("\[([a-z0-9A-Z]+):([a-z0-9A-Z]+)\]")
function Get-SuperEditTags {
    param($text)
    $tags = @{}
    $matches = $global:tagmatch.Matches($text)
    foreach($match in $matches) {
        $tags[$match.Groups[1].Value] = $match.Groups[2].value
    }
    return $tags
}



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


$global:globaltaglist = @{}

#update the selection table (the big thing in the middle)
function Update-SelectionList {
        param($updatelistonly=$false)

        $selectionlist.Items.Clear()
        $modselected = $modselection.SelectedValue.OriginalObject

        $npath = $modselected.NamePath
        $tpath = $modselected.TagPath
        $newlist = Invoke-Expression  $modselected.ListExpression
        
        $nf = $namefilter.Text
        # @{"cat1"=@("tag1","tag2");"cat2"=@("tag3","tag4")}
        
        $taglistupdate = $false

        foreach($item in $newlist) {
            $passedfilters = $true
            $name = $item."$npath"
            $tagfield = $item."$tpath"
            
            $itemtags = @{}

            if ($tagfield -and $tagfield -ne "") {
                 $itemtags = Get-SuperEditTags -text $tagfield
           

                 foreach($tagkey in $itemtags.Keys) {
                    $itemtagval = $itemtags[$tagkey]

                    if ($global:globaltaglist.ContainsKey($tagkey)) {
                        if($itemtagval -notin $global:globaltaglist[$tagkey]) {
                            $global:globaltaglist[$tagkey] += $itemtagval
                            $taglistupdate = $true
                        }
                    } else {
                        $global:globaltaglist[$tagkey] = @($itemtagval)
                        $taglistupdate = $true
                    }
                 }

                 
            }
             

            if($passedfilters -and $nf -ne "") {
                $passedfilters = ($name -match $nf)
            }

           
            if ($passedfilters -and (-not $tagfilter.Items.IsEmpty)) {
                $tf = $tagfilter.SelectedValue
                if ($tf -and $tf.Category -ne "" -and $tf.Tag -ne "") {
                    if ($itemtags.ContainsKey($tf.Category)) {
                        if ($itemtags[$tf.Category] -ne $tf.Tag ) {
                            $passedfilters = $false
                        }
                    } else {
                        $passedfilters = $false
                    }
                }
            }

            if ($passedfilters) {
                $listitem = new-object -TypeName psobject -Property @{Name=$name;Include=$false;Tags=$itemtags;OriginalObject=$item}
                $selectionlist.Items.Add($listitem) | Out-Null
            }
        }
       
        if (-not $updatelistonly) {
            $modkey.Items.Clear()
            foreach($action in $modselected.Actions) {
                    $action = new-object -TypeName psobject -Property @{Name=$action.Name;OriginalObject=$action}
                    $modkey.Items.Add($action) | Out-Null 
            }
            if (-not $modkey.Items.IsEmpty) {
                $modkey.SelectedIndex = 0
                Update-ValueList
            }
            
            if ($taglistupdate) {
                $tagfilter.items.Clear()
                $tagfilter.items.add((new-object -TypeName psobject -Property @{Name=("No Tag Filter");Category="";Tag=""})) | out-null
                foreach($tagcat in ($global:globaltaglist.keys | Sort-Object)) {
                    foreach($tag in ($global:globaltaglist[$tagcat]| Sort-Object)) {
                        $tagfilter.items.add((new-object -TypeName psobject -Property @{Name=("$tagcat : $tag");Category=$tagcat;Tag=$tag}))  | out-null
                    }
                }
            }
        }

        
        Update-SelectAll
}


function Update-SelectionListAfterFilterChange {
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
    
    
    $seltag = ""
    $selectedtagfilter = $tagfilter.SelectedValue
    if ($selectedtagfilter -and $selectedtagfilter.Category -ne "" -and $selectedtagfilter.Tag -ne "") {
        $seltag = ("[{0}:{1}]" -f $selectedtagfilter.Category,$selectedtagfilter.Tag )
    }

    $seltag = (Convert-ToScriptOutput -c "string" -v $seltag)

    $expr = $mod.ForEachExpression

    $idpath =  $js.IdPath

    $script = @()
    $script += ("# Generated with SuperEdit v2 on {0} " -f (get-date).ToString())
    $script += ("#")
    $script += $mod.PreExpression 
    foreach ($litem in $itemlist) {
        $item = $litem.OriginalObject
        $objectid = (Convert-ToScriptOutput -c $js.IdConvert -v ($item."$idpath"))
       

        $script += ("# {0}" -f $litem.Name)
        
        $script += $mod.ForEachExpression -replace "##id##",$objectid
    }
    $script += $mod.PostExpression  
   

    $pspath = "scripts.ps1"
    if ($outpath.Text -ne "") {
        $pspath = $outpath.Text
    }

    $joined = $script -join "`n" 
    $joined -replace "##val##","$selval"  -replace "##tag##","$seltag" | Set-Content $pspath
    [System.Windows.MessageBox]::Show("Script should be generated under $pspath") | out-null

}


#update now and in the future
Update-SelectionList 
$modselection.Add_SelectionChanged({Update-SelectionList})


Update-SelectAll
$selectall.Add_Checked({Update-SelectAll})
$selectall.Add_Unchecked({Update-SelectAll})
$modkey.Add_SelectionChanged({Update-ValueList})


$namefilter.Add_KeyDown({if ($_.Key -eq "Enter") {Update-SelectionListAfterFilterChange }})
$tagfilter.Add_selectionChanged({Update-SelectionListAfterFilterChange})



$execute.Add_Click({Invoke-ExecutionEngine})

 

$show = $window.ShowDialog()

