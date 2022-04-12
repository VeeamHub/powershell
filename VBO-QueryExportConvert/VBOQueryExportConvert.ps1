#The machine running the restore sessions must have a 64-bit version of both Microsoft Outlook & Word (version 2010, 2013, or 2016 installed).
[string]$ExportPath = 'ExportSharePath'
[string]$MailQuery = 'QueryStringHere'

<#
#Uncomment this block for per job restores of the latest restore point:
[string]$JobName = 'JobName'
$Job = Get-VBOJob -Name $JobName
$RestoreSession = Start-VBOExchangeItemRestoreSession -LatestState -Job $Job
#>

<#
#Uncomment this block for per org restores of the latest restore point:
[string]$OrgName = 'OrgName'
$Org = Get-VBOOrganization  -Name $OrgName
$RestoreSession = Start-VBOExchangeItemRestoreSession -LatestState -Organization $Org
#>

#Continuation after a restore session is started
$Database = Get-VEXDatabase -Session $RestoreSession
$MailItems = Get-VEXItem -Database $Database -Query $MailQuery

#This will export all mail items from the query as individual .MSG items to the path set in the $ExportPath variable
Export-VEXItem -Item $MailItems -To $ExportPath #-Force

#Save exported MSG files as .doc files then save as .pdf files
$MSOutlook = New-Object -ComObject Outlook.Application
$MSWord = New-Object -ComObject Word.Application

Get-ChildItem -Path $ExportPath -Filter *.msg? | ForEach-Object {

  $MSGFullName = $_.FullName
  $DOCFullName = $MSGFullName -replace '\.msg$', '.doc'
  $PDFFullName = $MSGFullName -replace '\.msg$', '.pdf'

  $MSG = $MSOutlook.CreateItemFromTemplate($MSGFullName)
  $MSG.SaveAs($DOCFullName, 4)

  $DOC = $MSWord.Documents.Open($DOCFullName)
  $DOC.SaveAs([ref] $PDFFullName, [ref] 17)

  $DOC.Close()
}