function Get-VBORestoreSessionLog {
    [CmdletBinding()]
    param (
      [Parameter(Mandatory)]
      [ValidateSet ('Exchange', 'OneDrive', 'SharePoint')]
      [string]$JobTypeFilter
    )
    
    begin {
      
      try {
      #Import required PowerShell module
      Import-Module Veeam.Archiver.PowerShell
      }
  
      catch{
        Write-Host "Unable to load Veeam Archiver PowerShell module; exiting function."
        break
      }
  
    }
    
    process {
      
      #Gather all VBO restore sessions
      $RestoreSessions = Get-VBORestoreSession | Where-Object { $_.Type -eq $JobTypeFilter }
  
      #Filter to sessions where log shows items were opened
      $FilterSessions = $RestoreSessions | Where-Object { $_.Log.Title -match 'opened' }
  
      #Capture session log results
      $SessionResults = foreach ($CurrentSession in $FilterSessions) {
  
        $FilterLogs = $CurrentSession.Log | Where-Object { $PSItem.Title -match 'opened' }
  
        foreach ($CurrentLog in $FilterLogs) {
  
          [PSCustomObject] @{
  
            'InitiatedBy'         = $CurrentSession.InitiatedBy
            'SessionName'         = $CurrentSession.Name
            'SessionStartTime'    = $CurrentSession.StartTime
            'ItemName'            = $CurrentLog.ItemName
            'ItemSize'            = $CurrentLog.ItemSize
            'SourceName'          = $CurrentLog.SourceName
            'LogEntryID'          = $CurrentLog.USN
            'LogDetail'           = $CurrentLog.Title
            'LogItemCreationTime' = $CurrentLog.CreationTime
            'LogItemEndTime'      = $CurrentLog.EndTime
            'SessionStatus'       = $CurrentSession.Status
            'SessionResult'       = $CurrentSession.Result
            'ProcessedObjects'    = $CurrentSession.ProcessedObjects
  
          } #end DataOutputResult object
  
        }
              
      }
  
    }
    
    end {
      
      $SessionResults
  
    }
    
  }