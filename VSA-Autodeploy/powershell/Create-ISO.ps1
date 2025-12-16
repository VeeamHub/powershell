# Run sequentially
$jsonFiles = @(
    ".\viaproxy.json",
    ".\dhcp.json",
    ".\vhr.json"
)

foreach ($config in $jsonFiles) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Processing: $config" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    .\autodeploy.ps1 -ConfigFile $config
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: $config failed with exit code $LASTEXITCODE" -ForegroundColor Red
    }
}
