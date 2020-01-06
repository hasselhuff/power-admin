#Stop Windows Update Service
$ErrorActionPreference = "Stop"
$ServiceStartType = (Get-WmiObject win32_Service -Filter "Name='Wuauserv'").StartMode
$Destination = "$env:TEMP\StoredService.txt"

# Create $Destination file if it does not already exist
If (-not (Test-Path $Destination)) { 

    New-Item -Path $Destination -ItemType File
    
}

$ServiceStartType | Out-file -FilePath $Destination -Force

If ($ServiceStartType -match "Disabled"){

    Set-Service Wuauserv -StartupType Manual
    Write-Output "The Windows Update service startup type has been Changed from Disabled to Manual on $Env:COMPUTERNAME."       

}

Write-Output "Stopping Windows Update service on $Env:COMPUTERNAME"
Stop-Service -Name wuauserv -Force

# Start Windows Update Service
$ErrorActionPreference = "Stop"
$Destination = "$env:TEMP\StoredService.txt"
$ServiceStartType = (Get-Content $Destination)
$ServiceObject = Get-Service -Name Wuauserv

If($ServiceStartType -match "Auto"){

    Write-Output "The Windows Update Service startup type is set to Automatic on $Env:COMPUTERNAME"
    Exit 0

}

Try {

    Set-Service Wuauserv -StartupType $ServiceStartType

} Catch {

     Write-Output "The Windows Update Service could not be reverted back to it's original state on $Env:COMPUTERNAME`n"
    $_
    Exit 0

}

Write-Output "The Windows Update Service startup type has been reverted back to $ServiceStartType on $Env:COMPUTERNAME"

If (Test-Path $Destination) {
    
    Remove-Item $Destination -Force
        
}