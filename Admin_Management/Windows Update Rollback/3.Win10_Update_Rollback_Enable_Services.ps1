# Re-enable all the previously disabled services after updates are completed
$Disabled_Services = Get-Content -Path C:\Temp\Disabled_Services.txt
 
Foreach ($d_service in $Disabled_Services){
    Write-Host "Starting Service: $d_service" -ForegroundColor Green
    Set-Service -Name $d_service -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name $service -ErrorAction SilentlyContinue
    }

Remove-Item -Path C:\Temp\Disabled_Services.txt -Force