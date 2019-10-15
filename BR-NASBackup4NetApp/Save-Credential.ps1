<# 
   .SYNOPSIS
   Save credentials securely into a xl file
   
   .DESCRIPTION
   Save credentials securely into a file for later reuse in e.g. scripts by loading the credentials.
   Because encryption is done for the current user the credentials can only decrypted by the current user.

   .INPUTS
   None. You cannot pipe objects to this script

   .EXAMPLE
   Run for the current user this script and save credentials to a file.

   PS> Save-Credentials.ps1

   The file named "credential.xml" is located in "C:\scripts\"
 
   .EXAMPLE
   Sometimes it is needed that later a powershell script which is
   running in "LOCAL SYSTEM" context to use such Credentials. For this
   we need to run this script in "LOCAL SYSTEM" security context.

   How we do it.
   1) Install psexec from https://docs.microsoft.com/en-us/sysinternals/downloads/psexec
   2) Start a powershell with psexec to run script in "LOCAL SYSTEM" security context:
      C:\Users\Administrator\Downloads\PSTools>PsExec64.exe -i -s powershell.exe -ExecutionPolicy Unrestricted -Command "& '<Path to script>\Save-Credential.ps1' "
   3) Move c:\scripts\credentials.xml to your folder to save such files.

   .Notes 
   Version:        1.0
   Author:         Marco Horstmann (marco.horstmann@veeam.com)
   Creation Date:  08.10.2019
   Purpose/Change: Initial script development
   
   .LINK https://github.com/VeeamHub/powershell/
   .LINK https://horstmann.in
 #>

$credential = Get-Credential

New-Item -Path "c:\" -Name "scripts" -ItemType "directory" -ErrorAction SilentlyContinue

$credential | Export-CliXml -Path "C:\scripts\credential.xml"
