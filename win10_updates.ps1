<#
.SYNOPSIS
    Allow Windows Updates to be forced via powershell on hosts that are running PowerShell 5.1 or newer.

.DESCRIPTION
    Downloads the PSWindowsUpdate package from NuGet.
    Does not install "already pending but not downloaded" updates.

.EXAMPLE
    # Run powershell as administrator and type path to this script.

Description
-----------
    Checks to see if host has PSWindowsUpdate module and automatically installs if the repository is not found.
    Removes older versions if a newer version of PSWindowsUpdate is available.
    Notifies on stdout if a reboot is required or if computer is already up to date.

.NOTES
    Name:  win10_updates.ps1
    Version: 2.1
    Author: Hasselhuff
    Last Modified: 16 January 2020

.REFERENCES
    https://www.powershellgallery.com/packages/PSWindowsUpdate/2.1.1.2

#>

if ((Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules" -Filter PSWindowsUpdate.* -Force).exists){
    $installed = Get-Module -Name PSWindowsUpdate | Select -Property Version | Out-String -Stream | Select-Object -Skip 3
    $currentversion = Find-Module -Name PSWindowsUpdate | Select -Property Version | Out-String -Stream | Select-Object -Skip 3
    $date = Get-Date -Format MM/dd/yyyy
    if ("$installed" -match "$currentversion" ){
        Write-Host -ForegroundColor Green "Latest PSWindowsUpdate Module installed"
        Write-Host -ForegroundColor Cyan "Removing older versions of PSWindowsUpdate..."
        Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate\" -Exclude $currentversion | foreach($_){
        Write-Host -ForegroundColor Red "Cleaning:  $_"
        Remove-Item $_.fullname -Force -Recurse
        Write-Host -ForegroundColor Green "Removed:  $_"}
        Sleep 5
        Write-Host -ForegroundColor Cyan "Beginning Windows Update..."
        Get-WUInstall -IgnoreUserInput -AcceptAll -Install -Download -IgnoreReboot
        $lastinstall = Get-WUHistory| Select -Property Date | Out-String -Stream | Select -Skip 3
        $lastinstall1 = $lastinstall | Select -First 1
        $lastinstall1 = $lastinstall1.Substring(0,10)
        $lastinstall1= $lastinstall1.trim()
        if ("$date" -match "$lastinstall1"){
            Write-Host -ForegroundColor Green "Windows Update Complete! Computer must restart to apply updates. Have a nice day!"}
        Else{
            Write-Host -ForegroundColor Green "No update needed. Your computer is up to date!"}}
    else{ 
        Write-Host -ForegroundColor Red "PSWindowsUpdate Module out of date"
        Write-Host -ForegroundColor Cyan "Installing latest version of PSWindowsUpdate Module..."
        Set-ExecutionPolicy Bypass Process -Force
        Install-PackageProvider -Name NuGet -MinimumVersion $latest -Force
        Install-Module -Name PSWindowsUpdate -Force
        Import-Module PSWindowsUpdate -Force
        Write-Host -ForegroundColor Cyan "Removing older versions of PSWindowsUpdate..."
        Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate\" -Exclude $currentversion | foreach($_){
        Write-Host -ForegroundColor Red "Cleaning:  $_"
        Remove-Item $_.fullname -Force -Recurse
        Write-Host -ForegroundColor Green "Removed:  $_"}
        Sleep 5
        Write-Host -ForegroundColor Cyan "Beginning Windows Update..."
        Get-WUInstall -IgnoreUserInput -AcceptAll -Install -Download -IgnoreReboot
        $lastinstall = Get-WUHistory| Select -Property Date | Out-String -Stream | Select -Skip 3
        $lastinstall1 = $lastinstall | Select -First 1
        $lastinstall1 = $lastinstall1.Substring(0,10)
        $lastinstall1= $lastinstall1.trim()
        if ("$date" -match "$lastinstall1"){
            Write-Host -ForegroundColor Green "Windows Update Complete! Computer must restart to apply updates. Have a nice day!"}
        Else{
            Write-Host -ForegroundColor Green "No update needed. Your computer is up to date!"}
        }}
else {
    Write-Host -ForegroundColor Red "PSWindowsUpdate Module not installed"
    Write-Host -ForegroundColor Cyan "Installing latest version of PSWindowsUpdate Module..."
    Sleep 2
    Set-ExecutionPolicy Bypass Process -Force
    Install-PackageProvider -Name NuGet -MinimumVersion $latest -Force
    Install-Module -Name PSWindowsUpdate -Force
    Import-Module PSWindowsUpdate -Force
    Write-Host -ForegroundColor Cyan "Beginning Windows Update..."
    Sleep 2
    Get-WUInstall -IgnoreUserInput -AcceptAll -Install -Download -IgnoreReboot
    $lastinstall = Get-WUHistory| Select -Property Date | Out-String -Stream | Select -Skip 3
    $lastinstall1 = $lastinstall | Select -First 1
    $lastinstall1 = $lastinstall1.Substring(0,10)
    $lastinstall1= $lastinstall1.trim()
    if ("$date" -match "$lastinstall1"){
        Write-Host -ForegroundColor Green "Windows Update Complete! Computer must restart to apply updates. Have a nice day!"}
    Else{
        Write-Host -ForegroundColor Green "No update needed. Your computer is up to date!"}}
