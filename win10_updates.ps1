<#
.SYNOPSIS
    Allow Windows Updates to be forced via powershell on hosts that are running PowerShell 5.1 or newer.

.DESCRIPTION
    Downloads the PSWindowsUpdate package from NuGet.
    Does not install:
        - "Already pending but not downloaded" updates.
        - Optional Cumulative updates.

.EXAMPLE
    # Run powershell as administrator and type path to this script.

Description
-----------
    - Checks to see if host has NuGet package provider, PSWindowsUpdate and PendingReboot modules installed. If not it proceeds to install them, and if the host
      does have them it updates to the latest versions while removing the older versions.
    - Lists the updates it installes on stdout
    - Notifies on stdout if a reboot is required or if computer is already up to date.
    - Creates universal functions to install package providers and modules by just using the name (functions not stored globally)
    - PSWindowsUpdate module adds new global functions to check Windows Update history as well as selective download options

.NOTES
    Name:  win10_updates.ps1
    Version: 2.5.1
    Author: Hasselhuff
    Last Modified: 09 March 2020

.REFERENCES
    https://www.nuget.org/
    https://www.powershellgallery.com/packages/PSWindowsUpdate/2.1.1.2
    https://www.powershellgallery.com/packages/PendingReboot/0.9.0.6

#>

# Create function to check/ install/ update a Package Provider
# Example of useage:  Install-NewProvider -ProviderName NuGet
function Install-NewProvider{
    # Setup Parameter for command
    param ([string]$ProviderName)

if (($Installed_Provider = Get-PackageProvider -Name $ProviderName ) -eq $null){
    Write-Host -ForegroundColor Cyan "Installing $ProviderName Package Provider..."
    Set-ExecutionPolicy Bypass Process -Force
    Install-PackageProvider -Name $ProviderName -Force}
    # If Provider is installed check to see if it requires an update
else{
    $Installed_Provider = Get-PackageProvider -Name $ProviderName | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    $Available_Provider = Find-PackageProvider -Name $ProviderName | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    if("$Installed_Provider" -eq "$Available_Provider"){
        Write-Host -ForegroundColor Green "Latest version of $ProviderName installed ..."}
    else{
        Write-Host -ForegroundColor Cyan "Updating version of $ProviderName"
        Set-ExecutionPolicy Bypass Process -Force
        Install-PackageProvider -Name $ProviderName -Force}}}

# Create function to install a module
# Example of useage:  Install-NewModule -ModuleName PSWindowsUpdate
function Install-NewModule{
    # Setup Parameter for command
    param ([string]$ModuleName)

    # Install the desired module
    Set-ExecutionPolicy Bypass Process -Force
    Install-Module -Name $ModuleName -Force
    Import-Module $ModuleName -Force}

# Create function to remove older versions of an installed module
# Example of useage:  Remove-OldModule -ModuleName PSWindowsUpdate
function Remove-OldModule{
    # Setup Parameter for command
    param ([string]$ModuleName)

    # Remove older versions of the module on the host if they exist excluding the latest version
    $CurrentVersion = Find-Module -Name $ModuleName | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    if ((Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\$ModuleName\" -Exclude $CurrentVersion).Exists -ne $null){
        Write-Host -ForegroundColor Red "Removing older versions of $ModuleName"
        Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\$ModuleName\" -Exclude $CurrentVersion | foreach($_){
        Write-Host -ForegroundColor Red "Cleaning:  $_"
        Remove-Item $_.fullname -Recurse -Force
        Write-Host -ForegroundColor Green "Removed:  $_"}}}

# Create function to check if a module is installed then proceeds to install/ update/ remove older versions of the module
# Example of useage:  Check-ModuleInstall -ModuleName PSWindowsUpdate
function Check-ModuleInstall{
    # Setup Parameter for command
    param ([string]$ModuleName)

    if (($Module = Get-Package -Name $ModuleName -ErrorAction SilentlyContinue) -eq $null){
        Write-Host -ForegroundColor Cyan "Installing $ModuleName Module..."
        # Install module
        Install-NewModule -ModuleName $ModuleName}
    else{
        $Module_Installed = Get-Package -Name $ModuleName | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
        $Module_Available = Find-Module -Name $ModuleName | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
        if("$Module_Installed" -eq "$Module_Available"){
            Write-Host -ForegroundColor Green "Latest version of $ModuleName installed ..."
            # Remove older versions of module
            Remove-OldModule -ModuleName $ModuleName}
        else{
            Write-Host -ForegroundColor Cyan "Updating version of $ModuleName"
            # Install latest version of module
            Install-NewModule -ModuleName $ModuleName
            # Remove older versions of module
            Remove-OldModule -ModuleName $ModuleName}}}

function Install-Windows-Update {
    # Get Today's date
    $date = Get-Date -Format M/D/YYYY | Out-String -Stream
    # Begin Windows Update
    Write-Host -ForegroundColor Cyan "Begining Windows Update..."
    Get-WUInstall -IgnoreUserInput -AcceptAll -Install -Download -IgnoreReboot
    # Get the history of windows updates on the host and isolate to the latest update by subtracting the headers and only select the install date portion
    $last_install = Get-WUHistory| Select -Property Date | Out-String -Stream | Select -Skip 3 | Select -First 1
    # Split the string at the '/' into three arrays 
    $last_install_date = $last_install.Split('/',3)
    # Join the month and the day array with a "/"
    $last_install_date = $last_install_date[0..1] -join "/"
    # Check to see if there was any updates installed when script was ran
    if ("$day_month" -match "$last_install_date"){
        # If updates were installed show the installed update titles
        $updates = Get-WUHistory| Select -Property Date,Title | Out-String -Stream | Select-String -Pattern "$date"
        Write-Host -ForegroundColor White "Installed updates:`n$updates"
        Write-Host -ForegroundColor Green "Windows Update Complete!"}
    else{
        Write-Host -ForegroundColor Green "No updates available."}}

######################################################################################################################################
########################################                Begin Script            ######################################################
######################################################################################################################################

# Check for Package Provider Nuget for installation/ update
Install-NewProvider -ProviderName NuGet

# Check for PendingReboot Module for installation/ update/ removal of older versions
Check-ModuleInstall -ModuleName PendingReboot

# Check for PSWindowsUpdate Module for installation/ update/ removal of older versions
Check-ModuleInstall -ModuleName PSWindowsUpdate

# Begin Windows updates
Install-Windows-Update

# Check for reboot requirement
if ((Test-PendingReboot -Detailed -SkipConfigurationManagerClientCheck).WindowsUpdateAutoUpdate -eq $True){
    Write-Host -ForegroundColor Yellow "Computer has installed updates that require a reboot. Have a nice day!"}
else{
    Write-Host -ForegroundColor Green "No reboot required. Your computer is up to date!"}
