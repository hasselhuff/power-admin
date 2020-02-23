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
    Version: 2.2.1
    Author: Hasselhuff
    Last Modified: 23 February 2020

.REFERENCES
    https://www.powershellgallery.com/packages/PSWindowsUpdate/2.1.1.2

#>

# Defining function to install the PSWindowsUpdate module
function install-pswindowsupdate ($currentversion) {
    Write-Host -ForegroundColor Cyan "Installing latest version of PSWindowsUpdate Module..."
    # Set execution policy to allow installing of module
    Set-ExecutionPolicy RemoteSigned CurrentUser -Force
    Install-PackageProvider -Name NuGet -MinimumVersion $currentversion -Force
    Install-Module -Name PSWindowsUpdate -Force
    Import-Module PSWindowsUpdate -Force
    }

# Defining Windows Update function "install-windows-update"
function install-windows-update ($date) {
    Write-Host -ForegroundColor Cyan "Begining Windows Update..."
    Get-WUInstall -IgnoreUserInput -AcceptAll -Install -Download -IgnoreReboot
    # Get the history of windows updates on the host and subtract the headers and only select the install date portion
    $last_install = Get-WUHistory| Select -Property Date | Out-String -Stream | Select -Skip 3
    # Select the latest update
    $last_install_string = $last_install | Select -First 1
    # Edit the string to only display mm/dd/yyyy
    $last_install_date = $last_install_string.Substring(0,10)
    # Eliminate white space in case the date only was like the following: m/dd/yyyy or mm/d/yyyy or m/d/yyyy
    $last_install_date = $last_install_date.trim()
    # Check to see if there was any updates installed when script was ran
    if ("$date" -match "$last_install_date"){
        # If updates were installed show the installed update titles
        $updates = Get-WUHistory| Select -Property Date,Title | Out-String -Stream | Select-String -Pattern "$date"
        Write-Host -ForegroundColor White "Installed updates:`n$updates"
        Write-Host -ForegroundColor Green "Windows Update Complete! Computer must restart to apply updates. Have a nice day!"}
    else{
        Write-Host -ForegroundColor Green "No update needed. Your computer is up to date!"}}

# Defining function for removing older versions of PSWindowsUpdate
function remove-old-pswindowsupdate ($currentversion){
    Write-Host -ForegroundColor Cyan "Removing older versions of PSWindowsUpdate..."
    # Remove older versions of the module on the host if they exist excluding the latest version
    if ((Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate\" -Exclude $currentversion).Exists -eq $null){
    Write-Host -ForegroundColor Green "No older versions present"}
else{
    Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate\" -Exclude $currentversion | foreach($_){
    Write-Host -ForegroundColor Red "Cleaning:  $_"
    Remove-Item $_.fullname -Recurse -Force
    Write-Host -ForegroundColor Green "Removed:  $_"}}}

######################################################################################################################################
########################################                Begin Script            ######################################################
######################################################################################################################################

# Check to see if the host already has the PSWindowsUpdate Module installed
if ((Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules" -Filter PSWindowsUpdate.* -Force).exists){
    # Check the latest version of the module
    ## Outputing the property, converting to a string, and then removing the headers to isolate the value
    $installed = Get-Module -Name PSWindowsUpdate | Select -Property Version | Out-String -Stream | Select-Object -Skip 3
    # Check the version available to download, converting to a string, and then removing the headers to isolate the value
    $currentversion = Find-Module -Name PSWindowsUpdate | Select -Property Version | Out-String -Stream | Select-Object -Skip 3
    # Get today's date
    $date = Get-Date -Format MM/dd/yyyy
### If the host has the module installed verify it is the latest released version of the module
    if ("$installed" -match "$currentversion" ){
        #Statement if host has the most up to date module
        Write-Host -ForegroundColor Green "Latest PSWindowsUpdate Module installed"}
        Sleep 5
        # Begin windows update
        install-windows-update}

 ## Path if the host has an outdated PSWindowsUpdate Module
    else{ 
        Write-Host -ForegroundColor Red "PSWindowsUpdate Module out of date"
        install-pswindowsupdate
        remove-old-pswindowsupdate
        Sleep 5
        install-windows-update
        }}
####################################################################################################################################
# Path if host did not have PSWindowsUpdate Module installed
else {
    Write-Host -ForegroundColor Red "PSWindowsUpdate Module not installed"
    install-pswindowsupdate
    install-windows-update}
