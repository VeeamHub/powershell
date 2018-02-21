$script:VeeamHubVersion = "0.0.1"

function Get-VeeamHubVersion {
	return $script:VeeamHubVersion
}
Export-ModuleMember -Function Get-VeeamHubVersion
