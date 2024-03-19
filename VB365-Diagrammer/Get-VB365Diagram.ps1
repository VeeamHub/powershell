function Get-VB365Diagram {
    <#
    .SYNOPSIS
        Diagram the configuration of Veeam Backup for Microsoft 365 infrastructure in PDF/SVG/DOT/PNG formats using PSGraph and Graphviz.
    .DESCRIPTION
        This script will connect to the VB365 server and build a diagram of the Implemented Component of the Veeam Infrastructure.
    .PARAMETER Target
        Specifies the IP/FQDN of the system to connect.
        Multiple targets may be specified, separated by a comma.
    .PARAMETER Port
        Specifies a optional port to connect to Veeam VB365 Service.
        By default, port will be set to 9191
    .PARAMETER Credential
        Specifies the stored credential of the target system.
    .PARAMETER Username
        Specifies the username for the target system.
    .PARAMETER Password
        Specifies the password for the target system.
    .PARAMETER Format
        Specifies the output format of the diagram.
        The supported output formats are base64, pdf, png, dot & svg.
    .PARAMETER OutputFolderPath
        Specifies the folder path to save the diagram.
    .PARAMETER Filename
        Specifies a filename for the diagram.
    .PARAMETER EnableEdgeDebug
        Control to enable edge debugging ( Dummy Edge and Node lines ).
    .PARAMETER EnableSubGraphDebug
        Control to enable subgraph debugging ( Subgraph Lines ).
    .PARAMETER EnableErrorDebug
        Control to enable error debugging.
    .PARAMETER AuthorName
        Allow to set footer signature Author Name.
    .PARAMETER CompanyName
        Allow to set footer signature Company Name.
    .PARAMETER Logo
        Allow to change the Veeam logo to a custom one.
        Image should be 400px x 100px or less in size.
    .PARAMETER SignatureLogo
        Allow to change the Vb365.Diagrammer signature logo to a custom one.
        Image should be 120px x 130px or less in size.
    .PARAMETER Signature
        Allow the creation of footer signature.
        AuthorName and CompanyName must be set to use this property.
    .PARAMETER WatermarkText
        Allow to add a watermark to the output image (Not supported in svg format).
    .PARAMETER WatermarkColor
        Allow to specified the color used for the watermark text. Default: Green.
    .EXAMPLE
        PS> Get-VB365Diagram -Target veeam-vb365.domain.local -Username 'domain\username' -Password password -Format png -OutputFolderPath C:\Users\jocolon\ -Filename Out.png

                Directory: C:\Users\jocolon


            Mode                 LastWriteTime         Length Name
            ----                 -------------         ------ ----
            -a----         3/19/2024   9:40 AM         281579 Out.png

        PS >

    .NOTES
        Version:        0.1.0
        Author(s):      Jonathan Colon
        Twitter:        @jcolonfzenpr
        Github:         rebelinux
    .LINK
        https://github.com/rebelinux/Diagrammer.Core
    #>

    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSUseShouldProcessForStateChangingFunctions',
        ''
    )]

    [CmdletBinding(
        PositionalBinding = $false,
        DefaultParameterSetName = 'Credential'
    )]
    param (

        [Parameter(
            Position = 0,
            Mandatory = $true,
            HelpMessage = 'Please provide the IP/FQDN of the system'
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('Server', 'IP')]
        [String] $Target,

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Please provide credentials to connect to the system',
            ParameterSetName = 'Credential'
        )]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $Credential,

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Please provide the username to connect to the target system',
            ParameterSetName = 'UsernameAndPassword'
        )]
        [ValidateNotNullOrEmpty()]
        [String] $Username,

        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Please provide the password to connect to the target system',
            ParameterSetName = 'UsernameAndPassword'
        )]
        [ValidateNotNullOrEmpty()]
        [String] $Password,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Allow to set the VB365 service port'
        )]
        [int] $Port = 9191,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Please provide the diagram output format'
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('pdf', 'svg', 'png', 'dot', 'base64')]
        [string] $Format = 'pdf',

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Please provide the path to the diagram output file'
        )]
        [ValidateScript( {
                if (Test-Path -Path $_) {
                    $true
                }
                else {
                    throw "Path $_ not found!"
                }
            })]
        [string] $OutputFolderPath = [System.IO.Path]::GetTempPath(),

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Please provide the path to the custom logo used for Signature'
        )]
        [ValidateScript( {
                if (Test-Path -Path $_) {
                    $true
                }
                else {
                    throw "File $_ not found!"
                }
            })]
        [string] $SignatureLogo,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Please provide the path to the custom logo'
        )]
        [ValidateScript( {
                if (Test-Path -Path $_) {
                    $true
                }
                else {
                    throw "File $_ not found!"
                }
            })]
        [string] $Logo,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Specify the diagram output file name path'
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                if ($Format.count -lt 2) {
                    $true
                }
                else {
                    throw "Format value must be unique if Filename is especified."
                }
                if ($Format -eq 'base64') {
                    throw "The base64 format by default output to stdout. Please call the script without Filename attribure"
                }
                if (-Not $_.EndsWith($Format)) {
                    throw "The file specified in the path argument must be of type $Format"
                }
                return $true
            })]
        [String] $Filename,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Allow to enable edge debugging ( Dummy Edge and Node lines)'
        )]
        [Switch] $EnableEdgeDebug = $false,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Allow to enable subgraph debugging ( Subgraph Lines )'
        )]
        [Switch] $EnableSubGraphDebug = $false,
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Allow to enable error debugging'
        )]
        [Switch] $EnableErrorDebug = $false,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Allow to set footer signature Author Name'
        )]
        [string] $AuthorName,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Allow to set footer signature Company Name'
        )]
        [string] $CompanyName,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Allow the creation of footer signature'
        )]
        [Switch] $Signature = $false,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Allow to add a watermark to the output image (Not supported in svg format)'
        )]
        [string] $WaterMarkText,

        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Allow to specified the color used for the watermark text. Default: Green'
        )]
        [string] $WaterMarkColor = 'Green'
    )


    begin {

        #---------------------------------------------------------------------------------------------#
        #                                       Helper Modules                                        #
        #---------------------------------------------------------------------------------------------#
        function ConvertTo-FileSizeString {
            <#
            .SYNOPSIS
            Used by Diagrammer to convert bytes automatically to GB, TB etc. based on size.
            .DESCRIPTION
            .NOTES
                Version:        0.4.0
                Author:         LEE DAILEY
            .EXAMPLE
                ConvertTo-FileSizeString -Size $Input
            #>
            [CmdletBinding()]
            [OutputType([String])]
            Param
            (
                [Parameter (
                    Position = 0,
                    Mandatory)]
                [int64]
                $Size
            )
        
            switch ($Size) {
                { $_ -gt 1TB }
                { [string]::Format("{0:0} TB", $Size / 1TB); break }
                { $_ -gt 1GB }
                { [string]::Format("{0:0} GB", $Size / 1GB); break }
                { $_ -gt 1MB }
                { [string]::Format("{0:0} MB", $Size / 1MB); break }
                { $_ -gt 1KB }
                { [string]::Format("{0:0} KB", $Size / 1KB); break }
                { $_ -gt 0 }
                { [string]::Format("{0} B", $Size); break }
                { $_ -eq 0 }
                { "0 KB"; break }
                default
                { "0 KB" }
            }
        } # end

        #---------------------------------------------------------------------------------------------#
        #                                  Main Module Start Here                                     #
        #---------------------------------------------------------------------------------------------#
        
        # Import Veeam VB365 module
        Import-Module "C:\Program Files\Veeam\Backup365\Veeam.Archiver.PowerShell\Veeam.Archiver.PowerShell.psd1" -Verbose:$false 

        if ($Modules = Get-Module -ListAvailable -Name Veeam.Archiver.PowerShell) {
            try {
                Write-Verbose "Trying to import Veeam VB365 module."
                $Modules | Import-Module -WarningAction SilentlyContinue
            }
            catch {
                throw "Failed to load Veeam VB365 modules. Install VB365 Management Console to install the Veeam.Archiver.PowerShell module"
            }
        } else {
            throw "Failed to load Veeam VB365 modules. Install VB365 Management Console to install the Veeam.Archiver.PowerShell module"
        }

        if ($Modules = Get-Module -ListAvailable -Name Diagrammer.Core) {
            try {
                Write-Verbose "Trying to import Diagrammer.Core module."
                $Modules | Import-Module -WarningAction SilentlyContinue
            }
            catch {
                throw "Failed to load Diagrammer.Core modules. Install module from PSGALLERY: Install-Module -Name Diagrammer.Core"
            }
        } else {
            throw "Failed to load Diagrammer.Core modules. Install module from PSGALLERY: Install-Module -Name Diagrammer.Core"
        }

        if (-Not ((Get-Module -ListAvailable -Name Diagrammer.Core).Version.ToString() -ge 0.1.9)) {
            throw "Diagrammer.Core module version 0.1.9 or greater required. Update module from PSGALLERY: Update-Module -Name Diagrammer.Core"
        }

        # If Username and Password parameters used, convert specified Password to secure string and store in $Credential
        #@tpcarman
        if (($Username -and $Password)) {
            $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)
        }

        #---------------------------------------------------------------------------------------------#
        #              Used by Diagrammer to establish conection to Veeam VB365 Server                #
        #---------------------------------------------------------------------------------------------#

        Write-Verbose "Establishing initial connection to Backup Server for Microsoft 365: $($Target)."

        #Monkey patch
        Disconnect-VBOServer

        try {
            Write-Verbose "Connecting to $($Target) with $($Credential.USERNAME) credentials"
            Connect-VBOServer -Server $Target -Credential $Credential -Port $Port
        }
        catch {
            Write-Verbose $_.Exception.Message
            Throw "Failed to connect to Veeam VB365 Server Host $($Target):$($port) with username $($Credential.USERNAME)"
        }

        Write-Verbose "Successfully connected to $($Target):$($Port) Backup Server."

        # Variable translating Icon to Image Path ($IconPath)
        $script:Images = @{
            "VB365_Server"             = "VBR_server.png"
            "VB365_Proxy_Server"       = "Proxy_Server.png"
            "VB365_Proxy"              = "Veeam_Proxy.png"
            "VBR_LOGO"                 = "Veeam_logo.png"
            "VB365_LOGO_Footer"        = "verified_recoverability.png"
            "VB365_Repository"         = "VBO_Repository.png"
            "VB365_Windows_Repository" = "Windows_Repository.png"
            "VB365_Object_Repository"  = "Object_Storage.png"
            "VB365_Object_Support"     = "Object Storage support.png"
            "Veeam_Repository"         = "Veeam_Repository.png"
            "VB365_On_Premises"        = "SMB.png"
            "VB365_Microsoft_365"      = "Cloud.png"
            "Microsoft_365"            = "Microsoft_365.png"
            "Datacenter"               = "Datacenter.png"
            "VB365_Restore_Portal"     = "Web_console.png"
            "VB365_User_Group"         = "User_Group.png"
            "VB365_User"               = "User.png"
        }

        if (($Format -ne "base64") -and !(Test-Path $OutputFolderPath)) {
            Write-Error "OutputFolderPath '$OutputFolderPath' is not a valid folder path."
            break
        }

        if ($Signature -and (([string]::IsNullOrEmpty($AuthorName)) -or ([string]::IsNullOrEmpty($CompanyName)))) {
            throw "Get-VB365Diagram: AuthorName and CompanyName must be defined if the Signature option is specified"
        }

        $MainDiagramLabel = 'Backup for Microsoft 365'

        $IconDebug = $false

        if ($EnableEdgeDebug) {
            $EdgeDebug = @{style = 'filled'; color = 'red' }
            $IconDebug = $true
        }
        else { $EdgeDebug = @{style = 'invis'; color = 'red' } }

        if ($EnableSubGraphDebug) {
            $SubGraphDebug = @{style = 'dashed'; color = 'red' }
            $NodeDebug = @{color = 'black'; style = 'red'; shape = 'plain' }
            $IconDebug = $true
        }
        else {
            $SubGraphDebug = @{style = 'invis'; color = 'gray' }
            $NodeDebug = @{color = 'transparent'; style = 'transparent'; shape = 'point' }
        }

        $IconPath = Join-Path $PSScriptRoot 'icons'

        # Validate Custom logo
        if ($Logo) {
            $CustomLogo = Test-Logo -LogoPath (Get-ChildItem -Path $Logo).FullName -IconPath $IconPath -ImagesObj $Images
        }
        else {
            $CustomLogo = "VBR_LOGO"
        }
        # Validate Custom Signature Logo
        if ($SignatureLogo) {
            $CustomSignatureLogo = Test-Logo -LogoPath (Get-ChildItem -Path $SignatureLogo).FullName -IconPath $IconPath -ImagesObj $Images
        }

        $MainGraphAttributes = @{
            pad       = 1
            rankdir   = 'top-to-bottom'
            overlap   = 'false'
            splines   = 'line'
            penwidth  = 1.5
            fontname  = "Segoe Ui Black"
            fontcolor = '#005f4b'
            fontsize  = 32
            style     = "dashed"
            labelloc  = 't'
            imagepath = $IconPath
            nodesep   = .60
            ranksep   = .75
        }
    }

    process {

        # Graph default atrributes
        $script:Graph = Graph -Name VeeamVB365 -Attributes $MainGraphAttributes {
            # Node default theme
            Node @{
                label      = ''
                shape      = 'none'
                labelloc   = 't'
                style      = 'filled'
                fillColor  = '#71797E'
                fontsize   = 14;
                imagescale = $true
            }
            # Edge default theme
            Edge @{
                style     = 'dashed'
                dir       = 'both'
                arrowtail = 'dot'
                color     = '#71797E'
                penwidth  = 3
                arrowsize = 1
            }

            # Signature Section
            if ($Signature) {
                Write-Verbose "Generating diagram signature"
                if ($CustomSignatureLogo) {
                    $Signature = (Get-DiaHTMLTable -ImagesObj $Images -Rows "Author: $($AuthorName)", "Company: $($CompanyName)" -TableBorder 2 -CellBorder 0 -Align 'left' -Logo $CustomSignatureLogo -IconDebug $IconDebug)
                }
                else {
                    $Signature = (Get-DiaHTMLTable -ImagesObj $Images -Rows "Author: $($AuthorName)", "Company: $($CompanyName)" -TableBorder 2 -CellBorder 0 -Align 'left' -Logo "VB365_LOGO_Footer" -IconDebug $IconDebug)
                }
            }
            else {
                Write-Verbose "No diagram signature specified"
                $Signature = " "
            }

            #---------------------------------------------------------------------------------------------#
            #                             Graphviz Clusters (SubGraph) Section                            #
            #               SubGraph can be use to bungle the Nodes together like a single entity         #
            #                     SubGraph allow you to have a graph within a graph                       #
            #                PSgraph: https://psgraph.readthedocs.io/en/latest/Command-SubGraph/          #
            #                      Graphviz: https://graphviz.org/docs/attrs/cluster/                     #
            #---------------------------------------------------------------------------------------------#

            # Subgraph OUTERDRAWBOARD1 used to draw the footer signature (bottom-right corner)
            SubGraph OUTERDRAWBOARD1 -Attributes @{Label = $Signature; fontsize = 24; penwidth = 1.5; labelloc = 'b'; labeljust = "r"; style = $SubGraphDebug.style; color = $SubGraphDebug.color } {
                # Subgraph MainGraph used to draw the main drawboard.
                SubGraph MainGraph -Attributes @{Label = (Get-DiaHTMLLabel -ImagesObj $Images -Label $MainDiagramLabel -IconType $CustomLogo -IconDebug $IconDebug -IconWidth 250 -IconHeight 80); fontsize = 24; penwidth = 0; labelloc = 't'; labeljust = "c" } {

                    if (Get-VBOVersion) {

                        #-----------------------------------------------------------------------------------------------#
                        #                                Graphviz Node Section                                          #
                        #                 Nodes are Graphviz elements used to define a object entity                    #
                        #                Nodes can have attribues like Shape, HTML Labels, Styles etc..                 #
                        #               PSgraph: https://psgraph.readthedocs.io/en/latest/Command-Node/                 #
                        #                     Graphviz: https://graphviz.org/doc/info/shapes.html                       #
                        #-----------------------------------------------------------------------------------------------#

                        $ServerVersion = @{
                            'Version' = try { (Get-VBOVersion).ProductVersion } catch { 'Unknown' }
                        }

                        $ServerConfigRestAPI = Get-VBORestAPISettings
                        if ($ServerConfigRestAPI.IsServiceEnabled) {
                            $ServerVersion.Add('RestAPI Port', $ServerConfigRestAPI.HTTPSPort)
                        }

                        # VB365 Server Object
                        $VeeamBackupServer = ((Get-VBOServerComponents -Name Server).ServerName).ToString().ToUpper().Split(".")[0]
                        Node VB365Server @{Label = Get-DiaNodeIcon -Rows $ServerVersion -ImagesObj $Images -Name $VeeamBackupServer -IconType "VB365_Server" -Align "Center" -IconDebug $IconDebug; shape = 'plain'; fillColor = 'transparent'; fontsize = 14 }

                        $RestorePortal = Get-VBORestorePortalSettings
                        if ($RestorePortal.IsServiceEnabled) {
                            $RestorePortalURL = @{
                                'Portal URI' = $RestorePortal.PortalUri
                            }
                            Node VB365RestorePortal @{Label = Get-DiaNodeIcon -Rows $RestorePortalURL -ImagesObj $Images -Name 'Self-Service Portal' -IconType "VB365_Restore_Portal" -Align "Center" -IconDebug $IconDebug; shape = 'plain'; fillColor = 'transparent'; fontsize = 14 }
                        }

                        # Proxy Graphviz Cluster
                        $Proxies = Get-VBOProxy -WarningAction SilentlyContinue | Sort-Object -Property Hostname
                        if ($Proxies) {
                            $ProxiesInfo = @()

                            $Proxies | ForEach-Object {
                                $inobj = @{
                                    'Type' = $_.Type
                                    'Port' = "TCP/$($_.Port)"
                                }
                                $ProxiesInfo += $inobj
                            }

                            SubGraph ProxyServer -Attributes @{Label = (Get-DiaHTMLLabel -ImagesObj $Images -Label "Backup Proxies" -IconType "VB365_Proxy" -SubgraphLabel -IconDebug $IconDebug); fontsize = 18; penwidth = 1.5; labelloc = 'b'; style = 'dashed,rounded' } {

                                Node Proxies @{Label = (Get-DiaHTMLNodeTable -ImagesObj $Images -inputObject ($Proxies.HostName | ForEach-Object { $_.split('.')[0] }) -Align "Center" -iconType "VB365_Proxy_Server" -columnSize 3 -IconDebug $IconDebug -MultiIcon -AditionalInfo $ProxiesInfo); shape = 'plain'; fillColor = 'transparent'; fontsize = 14; fontname = "Tahoma" }
                            }
                        }
                        else {
                            SubGraph ProxyServer -Attributes @{Label = (Get-DiaHTMLLabel -ImagesObj $Images -Label "Backup Proxies" -IconType "VB365_Proxy" -SubgraphLabel -IconDebug $IconDebug); fontsize = 18; penwidth = 1.5; labelloc = 't'; style = 'dashed,rounded' } {

                                Node -Name Proxies -Attributes @{Label = 'No Backup Proxies'; shape = "rectangle"; labelloc = 'c'; fixedsize = $true; width = "3"; height = "2"; fillColor = 'transparent'; penwidth = 0 }
                            }
                        }

                        # Restore Operator Graphviz Cluster
                        $RestoreOperators = try { Get-VBORbacRole | Sort-Object -Property Name } catch { Out-Null }
                        $Organizations = Get-VBOOrganization | Sort-Object -Property Name
                        if ($RestoreOperators) {
                            $RestoreOperatorsInfo = @()

                            $RestoreOperators | ForEach-Object {
                                $OrgId = $_.OrganizationId
                                $inobj = @{
                                    'Organization' = Switch ([string]::IsNullOrEmpty(($Organizations | Where-Object { $_.Id -eq $OrgId }))) {
                                        $true { 'Unknown' }
                                        $false { ($Organizations | Where-Object { $_.Id -eq $OrgId }).Name }
                                        default { 'Unknown' }
                                    }
                                }
                                $RestoreOperatorsInfo += $inobj
                            }

                            SubGraph RestoreOp -Attributes @{Label = (Get-DiaHTMLLabel -ImagesObj $Images -Label "Restore Operators" -IconType "VB365_User_Group" -SubgraphLabel -IconDebug $IconDebug); fontsize = 18; penwidth = 1.5; labelloc = 'b'; style = 'dashed,rounded' } {

                                Node RestoreOperators @{Label = (Get-DiaHTMLNodeTable -ImagesObj $Images -inputObject $RestoreOperators.Name -Align "Center" -iconType "VB365_User" -columnSize 3 -IconDebug $IconDebug -MultiIcon -AditionalInfo $RestoreOperatorsInfo); shape = 'plain'; fillColor = 'transparent'; fontsize = 14; fontname = "Tahoma" }
                            }
                        }
                        else {
                            SubGraph RestoreOp -Attributes @{Label = (Get-DiaHTMLLabel -ImagesObj $Images -Label "Restore Operators" -IconType "VB365_User_Group" -SubgraphLabel -IconDebug $IconDebug); fontsize = 18; penwidth = 1.5; labelloc = 'b'; style = 'dashed,rounded' } {

                                Node -Name RestoreOperators -Attributes @{Label = 'No Restore Operators'; shape = "rectangle"; labelloc = 'c'; fixedsize = $true; width = "3"; height = "2"; fillColor = 'transparent'; penwidth = 0 }
                            }
                        }

                        # Repositories Graphviz Cluster
                        $Repositories = Get-VBORepository | Sort-Object -Property Name
                        if ($Repositories) {
                            $RepositoriesInfo = @()

                            foreach ($Repository in $Repositories) {
                                if ($Repository.ObjectStorageRepository.Name) {
                                    $ObjStorage = $Repository.ObjectStorageRepository.Name
                                }
                                else {
                                    $ObjStorage = 'None'
                                }
                                $inobj = [ordered] @{
                                    # 'Path' = $Repository.Path
                                    'Capacity'      = ConvertTo-FileSizeString $Repository.Capacity
                                    'Free Space'    = ConvertTo-FileSizeString $Repository.FreeSpace
                                    'ObjectStorage' = $ObjStorage
                                }
                                $RepositoriesInfo += $inobj
                            }

                            SubGraph Repos -Attributes @{Label = (Get-DiaHTMLLabel -ImagesObj $Images -Label "Backup Repositories" -IconType "VB365_Repository" -SubgraphLabel -IconDebug $IconDebug); fontsize = 18; penwidth = 1.5; labelloc = 'b'; style = 'dashed,rounded' } {

                                Node Repositories @{Label = (Get-DiaHTMLNodeTable -ImagesObj $Images -inputObject $Repositories.Name -Align "Center" -iconType "VB365_Windows_Repository" -columnSize 3 -IconDebug $IconDebug -MultiIcon -AditionalInfo $RepositoriesInfo); shape = 'plain'; fillColor = 'transparent'; fontsize = 14; fontname = "Tahoma" }
                            }
                        }
                        else {
                            SubGraph Repos -Attributes @{Label = (Get-DiaHTMLLabel -ImagesObj $Images -Label "Backup Repositories" -IconType "VB365_Repository" -SubgraphLabel -IconDebug $IconDebug); fontsize = 18; penwidth = 1.5; labelloc = 't'; style = 'dashed,rounded' } {

                                Node -Name Repositories -Attributes @{Label = 'No Backup Repositories'; shape = "rectangle"; labelloc = 'c'; fixedsize = $true; width = "3"; height = "2"; fillColor = 'transparent'; penwidth = 0 }
                            }
                        }
                        # Object Repositories Graphviz Cluster
                        $ObjectRepositories = Get-VBOObjectStorageRepository | Sort-Object -Property Name
                        if ($ObjectRepositories) {

                            $ObjectRepositoriesInfo = @()

                            $ObjectRepositories | ForEach-Object {
                                $inobj = @{
                                    'Type'         = $_.Type
                                    'Folder'       = $_.Folder
                                    'Immutability' = Switch ($_.EnableImmutability) {
                                        'true' { 'Yes' }
                                        'false' { 'No' }
                                        default { 'Unknown' }
                                    }
                                }
                                $ObjectRepositoriesInfo += $inobj
                            }

                            SubGraph ObjectRepos -Attributes @{Label = (Get-DiaHTMLLabel -ImagesObj $Images -Label "Object Repositories" -IconType "VB365_Object_Support" -SubgraphLabel -IconDebug $IconDebug); fontsize = 18; penwidth = 1.5; labelloc = 't'; style = 'dashed,rounded' } {

                                Node ObjectRepositories @{Label = (Get-DiaHTMLNodeTable -ImagesObj $Images -inputObject $ObjectRepositories.Name -Align "Center" -iconType "VB365_Object_Repository" -columnSize 3 -IconDebug $IconDebug -MultiIcon -AditionalInfo $ObjectRepositoriesInfo); shape = 'plain'; fillColor = 'transparent'; fontsize = 14; fontname = "Tahoma" }
                            }
                        }
                        else {
                            SubGraph ObjectRepos -Attributes @{Label = (Get-DiaHTMLLabel -ImagesObj $Images -Label "Object Repositories" -IconType "VB365_Object_Support" -SubgraphLabel -IconDebug $IconDebug); fontsize = 18; penwidth = 1.5; labelloc = 't'; style = 'dashed,rounded' } {

                                Node -Name ObjectRepositories -Attributes @{Label = 'No Object Repositories'; shape = "rectangle"; labelloc = 'c'; fixedsize = $true; width = "3"; height = "2"; fillColor = 'transparent'; penwidth = 0 }
                            }
                        }

                        # Organization Graphviz Cluster
                        $Organizations = Get-VBOOrganization | Sort-Object -Property Name
                        SubGraph Organizations -Attributes @{Label = (Get-DiaHTMLLabel -ImagesObj $Images -Label "Organizations" -IconType "VB365_On_Premises" -SubgraphLabel -IconDebug $IconDebug); fontsize = 18; penwidth = 1.5; labelloc = 't'; style = 'dashed,rounded' } {

                            # On-Premises Organization Graphviz Cluster
                            if (($Organizations | Where-Object { $_.Type -eq 'OnPremises' })) {
                                $OrganizationsInfo = @()

                                ($Organizations | Where-Object { $_.Type -eq 'OnPremises' }) | ForEach-Object {
                                    $inobj = @{
                                        'Users'    = "Licensed: $($_.LicensingOptions.LicensedUsersCount) - Trial: $($_.LicensingOptions.TrialUsersCount)"
                                        'BackedUp' = Switch ($_.IsBackedUp) {
                                            'true' { 'Yes' }
                                            'false' { 'No' }
                                            default { 'Unknown' }
                                        }
                                    }
                                    $OrganizationsInfo += $inobj
                                }

                                SubGraph OnPremise -Attributes @{Label = (Get-DiaHTMLLabel -ImagesObj $Images -Label "On-premises" -IconType "VB365_On_Premises" -SubgraphLabel -IconDebug $IconDebug); fontsize = 18; penwidth = 1.5; labelloc = 't'; style = 'dashed,rounded' } {

                                    Node OnpremisesOrg @{Label = (Get-DiaHTMLNodeTable -ImagesObj $Images -inputObject ($Organizations | Where-Object { $_.Type -eq 'OnPremises' }).Name -Align "Center" -iconType "Datacenter" -columnSize 3 -IconDebug $IconDebug -MultiIcon -AditionalInfo $OrganizationsInfo); shape = 'plain'; fillColor = 'transparent'; fontsize = 14; fontname = "Tahoma" }
                                }
                            }

                            # Microsoft 365 Organization Graphviz Cluster
                            if ($Organizations | Where-Object { $_.Type -eq 'Office365' }) {
                                $OrganizationsInfo = @()

                                ($Organizations | Where-Object { $_.Type -eq 'Office365' }) | ForEach-Object {
                                    $inobj = @{
                                        'Users'    = "Licensed: $($_.LicensingOptions.LicensedUsersCount) - Trial: $($_.LicensingOptions.TrialUsersCount)"
                                        'BackedUp' = Switch ($_.IsBackedUp) {
                                            'true' { 'Yes' }
                                            'false' { 'No' }
                                            default { 'Unknown' }
                                        }
                                    }
                                    $OrganizationsInfo += $inobj
                                }
                                SubGraph Microsoft365 -Attributes @{Label = (Get-DiaHTMLLabel -ImagesObj $Images -Label "Microsoft 365" -IconType "VB365_Microsoft_365" -SubgraphLabel -IconDebug $IconDebug); fontsize = 18; penwidth = 1.5; labelloc = 't'; style = 'dashed,rounded' } {

                                    Node Microsoft365Org @{Label = (Get-DiaHTMLNodeTable -ImagesObj $Images -inputObject ($Organizations | Where-Object { $_.Type -eq 'Office365' }).Name -Align "Center" -iconType "Microsoft_365" -columnSize 3 -IconDebug $IconDebug -MultiIcon -AditionalInfo $OrganizationsInfo); shape = 'plain'; fillColor = 'transparent'; fontsize = 14; fontname = "Tahoma" }
                                }
                            }
                        }

                        # Veeam VB365 elements point of connection (Dummy Nodes!)
                        $Node = @('VB365ServerPointSpace', 'VB365ProxyPoint', 'VB365ProxyPointSpace', 'VB365RepoPoint')
                        Node $Node -NodeScript { $_ } @{Label = { $_ } ; fontcolor = $NodeDebug.color; fillColor = $NodeDebug.style; shape = $NodeDebug.shape }

                        $NodeStartEnd = @('VB365StartPoint', 'VB365EndPointSpace')
                        Node $NodeStartEnd -NodeScript { $_ } @{Label = { $_ } ; fontcolor = $NodeDebug.color; shape = 'point'; fixedsize = 'true'; width = .2 ; height = .2 }

                        #---------------------------------------------------------------------------------------------#
                        #                             Graphviz Rank Section                                           #
                        #                     Rank allow to put Nodes on the same group level                         #
                        #         PSgraph: https://psgraph.readthedocs.io/en/stable/Command-Rank-Advanced/            #
                        #                     Graphviz: https://graphviz.org/docs/attrs/rank/                         #
                        #---------------------------------------------------------------------------------------------#

                        # Put the dummy node in the same rank to be able to create a horizontal line
                        Rank VB365ServerPointSpace, VB365ProxyPoint, VB365ProxyPointSpace, VB365RepoPoint, VB365StartPoint, VB365EndPointSpace

                        if ($RestorePortal.IsServiceEnabled) {
                            # Put the VB365Server and the VB365RestorePortal in the same level to align it horizontally
                            Rank VB365RestorePortal, VB365Server
                        }

                        #---------------------------------------------------------------------------------------------#
                        #                             Graphviz Edge Section                                           #
                        #                   Edges are Graphviz elements use to interconnect Nodes                     #
                        #                 Edges can have attribues like Shape, Size, Styles etc..                     #
                        #              PSgraph: https://psgraph.readthedocs.io/en/latest/Command-Edge/                #
                        #                      Graphviz: https://graphviz.org/docs/edges/                             #
                        #---------------------------------------------------------------------------------------------#

                        # Connect the Dummy Node in a straight line
                        # VB365StartPoint --- VB365ServerPointSpace --- VB365ProxyPoint --- VB365ProxyPointSpace --- VB365RepoPoint --- VB365EndPointSpace
                        Edge -From VB365StartPoint -To VB365ServerPointSpace @{minlen = 10; arrowtail = 'none'; arrowhead = 'none'; style = 'filled' }
                        Edge -From VB365ServerPointSpace -To VB365ProxyPoint @{minlen = 10; arrowtail = 'none'; arrowhead = 'none'; style = 'filled' }
                        Edge -From VB365ProxyPoint -To VB365ProxyPointSpace @{minlen = 10; arrowtail = 'none'; arrowhead = 'none'; style = 'filled' }
                        Edge -From VB365ProxyPointSpace -To VB365RepoPoint @{minlen = 10; arrowtail = 'none'; arrowhead = 'none'; style = 'filled' }
                        Edge -From VB365RepoPoint -To VB365EndPointSpace @{minlen = 10; arrowtail = 'none'; arrowhead = 'none'; style = 'filled' }

                        # Connect Veeam Backup server to the Dummy line
                        Edge -From VB365Server -To VB365ServerPointSpace @{minlen = 2; arrowtail = 'dot'; arrowhead = 'none'; style = 'dashed' }

                        # Connect Veeam Backup server to RetorePortal
                        if ($RestorePortal.IsServiceEnabled) {
                            Edge -From VB365RestorePortal -To VB365Server @{minlen = 2; arrowtail = 'dot'; arrowhead = 'normal'; style = 'dashed'; color = '#DF8c42' }
                        }
                        # Connect Veeam Backup Server to Organization Graphviz Cluster
                        if ($Organizations | Where-Object { $_.Type -eq 'OnPremises' }) {
                            Edge -To VB365Server -From OnpremisesOrg @{minlen = 2; arrowtail = 'dot'; arrowhead = 'normal'; style = 'dashed'; color = '#DF8c42' }
                        }
                        elseif ($Organizations | Where-Object { $_.Type -eq 'Office365' }) {
                            Edge -To VB365Server -From Microsoft365Org @{minlen = 2; arrowtail = 'dot'; arrowhead = 'normal'; style = 'dashed'; color = '#DF8c42' }
                        }
                        else {
                            SubGraph Organizations -Attributes @{Label = (Get-DiaHTMLLabel -ImagesObj $Images -Label "Organizations" -IconType "VB365_On_Premises" -SubgraphLabel -IconDebug $IconDebug); fontsize = 18; penwidth = 1.5; labelloc = 't'; style = 'dashed,rounded' } {
                                Node -Name DummyNoOrganization -Attributes @{Label = 'No Organization'; shape = "rectangle"; labelloc = 'c'; fixedsize = $true; width = "3"; height = "2"; fillColor = 'transparent'; penwidth = 0 }
                            }
                            Edge -To VB365Server -From DummyNoOrganization @{minlen = 2; arrowtail = 'dot'; arrowhead = 'normal'; style = 'dashed'; color = '#DF8c42' }
                        }

                        # Connect Veeam RestorePortal to the Restore Operators
                        Edge -From VB365ServerPointSpace -To RestoreOperators @{minlen = 2; arrowtail = 'none'; arrowhead = 'dot'; style = 'dashed' }

                        # Connect Veeam Proxies Server to the Dummy line
                        Edge -From VB365ProxyPoint -To Proxies @{minlen = 2; arrowtail = 'none'; arrowhead = 'dot'; style = 'dashed' }

                        # Connect Veeam Repository to the Dummy line
                        Edge -From VB365RepoPoint -To Repositories @{minlen = 2; arrowtail = 'none'; arrowhead = 'dot'; style = 'dashed' }

                        # Connect Veeam Object Repository to the Dummy line
                        Edge -To VB365RepoPoint -From ObjectRepositories @{minlen = 2; arrowtail = 'dot'; arrowhead = 'none'; style = 'dashed' }

                        # End results example
                        #
                        #------------------------------------------------------------------------------------------------------------------------------------
                        #
                        #------------------------------------------------------------------------------------------------------------------------------------
                        #                               |---------------------------------------------------|                        ^
                        #                               |  |---------------------------------------------|  |                        |
                        #                               |  |      Subgraph Logo |      Organization      |  |                        |
                        #                               |  |---------------------------------------------|  |               MainGraph Cluster Board
                        #        ----------------------o|  |   Onpremise Table  |  Microsoft 365 Table   |  |
                        #        |                      |  |---------------------------------------------|  |
                        #        |                      |---------------------------------------------------|
                        #        |                                 Organization Graphviz Cluster
                        #        |
                        #       \-/
                        #        |
                        # |--------------|
                        # |     ICON     |
                        # |--------------|
                        # | VB365 Server | <--- Graphviz Node Example
                        # |--------------|
                        # |   Version:   |
                        # |--------------|
                        #       O                                                                                                          Dummy Nodes
                        #       |                                                                                                               |
                        #       |                                                                                                               |
                        #       |                                                                                                              \|/
                        # VB365StartPoint --- VB365ServerPointSpace --- VB365ProxyPoint --- VB365ProxyPointSpace --- VB365RepoPoint --- VB365EndPointSpace
                        #                                                      |
                        #                                                      | <--- Graphviz Edge Example
                        #                                                      |
                        #                                                      O
                        #                                   |------------------------------------|
                        #                                   |  |------------------------------|  |
                        #                                   |  |      ICON    |     ICON      |  |
                        #                                   |  |------------------------------|  |
                        #                                   |  | Proxy Server | Proxy Server  |  | <--- Graphviz Cluster Example
                        #                                   |  |------------------------------|  |
                        #                                   |  | Subgraph Logo | Backup Proxy |  |
                        #                                   |  |------------------------------|  |
                        #                                   |------------------------------------|
                        #                                           Proxy Graphviz Cluster
                        #
                        #--------------------------------------------------------------------------------------------------------------------------------------
                        #                                                                                                       |---------------------------|
                        #                                                                                                       |---------                  |
                        #                                                                                                       |        |    Author Name   |
                        #                                                                                      Signature -----> |  Logo  |                  |
                        #                                                                                                       |        |    Company Name  |
                        #                                                                                                       |---------                  |
                        #                                                                                                       |---------------------------|
                        #--------------------------------------------------------------------------------------------------------------------------------------
                        #                                                                                                                    ^
                        #                                                                                                                    |
                        #                                                                                                                    |
                        #                                                                                                      OUTERDRAWBOARD1 Cluster Board
                    }
                }
            }
        }
    }
    end {
        #Export  the Diagram
        if ($Graph) {
            Export-Diagrammer -GraphObj ($Graph | Select-String -Pattern '"([A-Z])\w+"\s\[label="";style="invis";shape="point";]' -NotMatch) -ErrorDebug $EnableErrorDebug -Format $Format -Filename $Filename -OutputFolderPath $OutputFolderPath -IconPath $IconPath -WaterMarkText $WatermarkText -WaterMarkColor $WaterMarkColor
        }
        else {
            Write-Verbose "No Graph object found. Disabling diagram section"
        }
    }
}
