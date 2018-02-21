if (Get-PSSnapin -Registered -Name VeeamPSSnapIn -ErrorAction SilentlyContinue) {
    Add-PSSnapin -Name VeeamPSSnapIn
    }

Disconnect-VBRServer -ErrorAction SilentlyContinue
Connect-VBRServer -Server <Veeam Server>

if (Get-VBRServer) {
    Add-VBRvCenter -Name <vCenter Server> -Description My vCenter" -User "Administrator@vSphere.local" -Password "Passw0rd!" -Verbose
    }