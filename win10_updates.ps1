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
    Version: 2.2
    Author: Hasselhuff
    Last Modified: 28 January 2020

.REFERENCES
    https://www.powershellgallery.com/packages/PSWindowsUpdate/2.1.1.2

#>

# Check to see if the host already has the PSWindowsUpdate Module installed
if ((Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules" -Filter PSWindowsUpdate.* -Force).exists){
    # Check the latest version of the module
    $installed = Get-Module -Name PSWindowsUpdate | Select -Property Version | Out-String -Stream | Select-Object -Skip 3
    # Check the version already installed
    $currentversion = Find-Module -Name PSWindowsUpdate| Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | findstr "."
    # Get today's date
    $date = Get-Date -Format MM/dd/yyyy
    # If the host has the module installed verify it is the latest released version of the module
    if ("$installed" -match "$currentversion" ){
        #Statement if host has the most up to date module
        Write-Host -ForegroundColor Green "Latest PSWindowsUpdate Module installed"
        Write-Host -ForegroundColor Cyan "Removing older versions of PSWindowsUpdate..."
        # Remove older versions of the module on the host if they exist excluding the latest version
        Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate\" -Exclude $currentversion | foreach($_){
            Write-Host -ForegroundColor Red "Cleaning:  $_"
            Remove-Item $_.fullname -Force -Recurse
            Write-Host -ForegroundColor Green "Removed:  $_"}
        Sleep 5
        Write-Host -ForegroundColor Cyan "Beginning Windows Update..."
        # Begin windows update
        Get-WUInstall -IgnoreUserInput -AcceptAll -Install -Download -IgnoreReboot
        # Get the history of windows updates on the host and subtract the headers and only select the install date portion
        $lastinstall = Get-WUHistory| Select -Property Date | Out-String -Stream | Select -Skip 3
        # Select the latest update
        $lastinstall1 = $lastinstall | Select -First 1
        # Edit the string to only display mm/dd/yyyy
        $lastinstall1 = $lastinstall1.Substring(0,10)
        # Eliminate white space in case the date only was like the following: m/dd/yyyy or mm/d/yyyy or m/d/yyyy
        $lastinstall1= $lastinstall1.trim()
        # Check to see if there was any updates installed when script was ran
        if ("$date" -match "$lastinstall1"){
            # If updates were installed show the installed update titles
            $updates = Get-WUHistory| Select -Property Date,Title | Out-String -Stream | Select-String -Pattern "1/21/2020"
            Write-Host -ForegroundColor White "Installed updates:`n$updates"
            Write-Host -ForegroundColor Green "Windows Update Complete! Computer must restart to apply updates. Have a nice day!"}
        Else{
            Write-Host -ForegroundColor Green "No update needed. Your computer is up to date!"}}
    # Path if the host has an outdated PSWindowsUpdate Module
    else{ 
        Write-Host -ForegroundColor Red "PSWindowsUpdate Module out of date"
        Write-Host -ForegroundColor Cyan "Installing latest version of PSWindowsUpdate Module..."
        # Set execution policy to allow installing of module
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
            $updates = Get-WUHistory| Select -Property Date,Title | Out-String -Stream | Select-String -Pattern "1/21/2020"
            Write-Host -ForegroundColor White "Installed updates:`n$updates"
            Write-Host -ForegroundColor Green "Windows Update Complete! Computer must restart to apply updates. Have a nice day!"}
        Else{
            Write-Host -ForegroundColor Green "No update needed. Your computer is up to date!"}
        }}
# Path if host did not have PSWIndowsUpdate Module installed
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
        $updates = Get-WUHistory| Select -Property Date,Title | Out-String -Stream | Select-String -Pattern "$date"
        Write-Host -ForegroundColor White "Installed updates:`n$updates"
        Write-Host -ForegroundColor Green "Windows Update Complete! Computer must restart to apply updates. Have a nice day!"}
    Else{
        Write-Host -ForegroundColor Green "No update needed. Your computer is up to date!"}}
