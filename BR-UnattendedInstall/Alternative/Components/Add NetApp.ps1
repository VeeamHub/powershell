if (Get-PSSnapin -Registered -Name VeeamPSSnapIn -ErrorAction SilentlyContinue) {
    Add-PSSnapin -Name VeeamPSSnapIn
    }

Disconnect-VBRServer -ErrorAction SilentlyContinue
Connect-VBRServer -Server <Veeam Server>

if (Get-VBRServer) {
    Add-NetAppHost -Name NetApp Filer-Description My NetApp" -UserName "admin" -Password "Passw0rd!"
    }