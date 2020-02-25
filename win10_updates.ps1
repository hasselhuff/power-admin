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
    Version: 2.3.2
    Author: Hasselhuff
    Last Modified: 25 February 2020

.REFERENCES
    https://www.powershellgallery.com/packages/PSWindowsUpdate/2.1.1.2

#>

# Defining function to install NuGet Package Provider
## If NuGet is not installed procedd to install
function Install-NuGet{
if (($NuGet = Get-PackageProvider -Name NuGet ) -eq $null){
    Write-Host -ForegroundColor Cyan "Installing NuGet Package Provider..."
    Set-ExecutionPolicy RemoteSigned CurrentUser -Force
    Install-PackageProvider -Name NuGet -Force}
## If NuGet is installed check to see if it requires an update
else{
    $NuGetinstalled = Get-PackageProvider -Name NuGet | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    $NuGetcurrentversion = Find-PackageProvider -Name NuGet | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    if("$NuGetinstalled" -eq "$NuGetcurrentversion"){
        Write-Host -ForegroundColor Green "Latest version of NuGet installed ..."}
    else{
        Write-Host -ForegroundColor Cyan "Updating version of NuGet"
        Set-ExecutionPolicy RemoteSigned CurrentUser -Force
        Install-PackageProvider -Name NuGet -Force}}}

# Defining function to install the PendingReboot module
function Install-PendingReboot{
if (($PR = Get-Package -Name PendingReboot -ErrorAction SilentlyContinue) -eq $null){
    Write-Host -ForegroundColor Cyan "Installing PendingReboot Module..."
    # Set execution policy to allow installing of module
    Set-ExecutionPolicy RemoteSigned CurrentUser -Force
    Install-Module -Name PendingReboot -Force
    Import-Module PendingReboot -Force}
else{
    $PRinstalled = Get-Module -Name PendingReboot | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    $PRcurrentversion = Find-Module -Name PendingReboot | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    if("$PRinstalled" -eq "$PRcurrentversion"){
        Write-Host -ForegroundColor Green "Latest version of PendingReboot installed ..."
        Remove-Old-PendingReboot}
    else{
        Write-Host -ForegroundColor Cyan "Updating version of PendingReboot"
        Set-ExecutionPolicy RemoteSigned CurrentUser -Force
        Install-Module -Name PendingReboot -Force
        Import-Module PendingReboot -Force
        Remove-Old-PendingReboot}}}


#Defining function to remove older version of PendingReboot
function Remove-Old-PendingReboot{
    # Remove older versions of the module on the host if they exist excluding the latest version
    $PRcurrentversion = Find-Module -Name PendingReboot | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    if ((Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\PendingReboot\" -Exclude "$PRcurrentversion").Exists -ne $null){
        Write-Host -ForegroundColor Cyan "Removing older versions of PendingReboot..."
        Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\PendingReboot\" -Exclude "$PRcurrentversion" | foreach($_){
        Write-Host -ForegroundColor Red "Cleaning: $_"
        Remove-Item $_.Fullname -Recurse -Force
        Write-Host -ForegroundColor Green "Removed:  $_"}}}

# Defining function to install the PSWindowsUpdate module
function Install-PSWindowsUpdate{
    Write-Host -ForegroundColor Cyan "Installing latest version of PSWindowsUpdate Module..."
    # Set execution policy to allow installing of module
    Set-ExecutionPolicy RemoteSigned CurrentUser -Force
    Install-Module -Name PSWindowsUpdate -Force
    Import-Module PSWindowsUpdate -Force}

# Defining Windows Update function "install-windows-update"
function Install-Windows-Update ($date) {
    Write-Host -ForegroundColor Cyan "Begining Windows Update..."
    Get-WUInstall -IgnoreUserInput -AcceptAll -Install -Download -IgnoreReboot
    # Get the history of windows updates on the host and subtract the headers and only select the install date portion
    $last_install = Get-WUHistory| Select -Property Date | Out-String -Stream | Select -Skip 3 | Select -First 1
    # Select the latest update
    # Edit the string to only display mm/dd/yyyy
    $last_install_date = $last_install.Substring(0,10)
    # Eliminate white space in case the date only was like the following: m/dd/yyyy or mm/d/yyyy or m/d/yyyy
    $last_install_date = $last_install_date.trim()
    # Check to see if there was any updates installed when script was ran
    if ("$date" -match "$last_install_date"){
        # If updates were installed show the installed update titles
        $updates = Get-WUHistory| Select -Property Date,Title | Out-String -Stream | Select-String -Pattern "$date"
        Write-Host -ForegroundColor White "Installed updates:`n$updates"
        Write-Host -ForegroundColor Green "Windows Update Complete!"}
    else{
        Write-Host -ForegroundColor Green "No updates available."}}

# Defining function for removing older versions of PSWindowsUpdate
function Remove-Old-PSWindowsUpdate ($PSWUcurrentversion){
    # Remove older versions of the module on the host if they exist excluding the latest version
    if ((Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate\" -Exclude $PSWUcurrentversion).Exists -ne $null){
        Write-Host -ForegroundColor Red "Removing older versions of PSWindowsUpdate"
        Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate\" -Exclude $PSWUcurrentversion | foreach($_){
        Write-Host -ForegroundColor Red "Cleaning:  $_"
        Remove-Item $_.fullname -Recurse -Force
        Write-Host -ForegroundColor Green "Removed:  $_"}}}

######################################################################################################################################
########################################                Begin Script            ######################################################
######################################################################################################################################

# Check for installation of NuGet Package Provider and if there is an update available
Install-NuGet
# Install PendingReboot Module
Install-PendingReboot
# Check to see if the host already has the PSWindowsUpdate Module installed
if (($PSWU = Get-Package -Name PSWindowsUpdate -ErrorAction SilentlyContinue) -ne $null){
    # Check the latest version of the module
    ## Outputing the property, converting to a string, and then removing the headers to isolate the value
    $PSWUinstalled = Get-Module -Name PSWindowsUpdate | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    # Check the version available to download, converting to a string, and then removing the headers to isolate the value
    $PSWUcurrentversion = Find-Module -Name PSWindowsUpdate | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    # Get today's date
    $date = Get-Date -Format MM/dd/yyyy
### If the host has the module installed verify it is the latest released version of the module
    if ("$PSWUinstalled" -match "$PSWUcurrentversion" ){
        #Statement if host has the most up to date module
        Write-Host -ForegroundColor Green "Latest PSWindowsUpdate Module installed"
        Sleep 5
        # Begin windows update
        Install-Windows-Update}

 ## Path if the host has an outdated PSWindowsUpdate Module
    else{ 
        Write-Host -ForegroundColor Red "PSWindowsUpdate Module out of date"
        Install-PSWindowsUpdate
        Remove-Old-PSWindowsUpdate
        Sleep 5
        Install-Windows-Update}}
# Path if host did not have PSWindowsUpdate Module installed
else{
    Write-Host -ForegroundColor Red "PSWindowsUpdate Module not installed"
    Install-PSWindowsUpdate
    Install-Windows-Update}
# Check for reboot requirement
if ((Test-PendingReboot -Detailed -SkipConfigurationManagerClientCheck).WindowsUpdateAutoUpdate -eq $True){
    Write-Host -ForegroundColor Yellow "Computer has installed updates that require a reboot. Have a nice day!"}
else{
    Write-Host -ForegroundColor Green "No reboot required. Your computer is up to date!"}


################################################################################################################################
# Deployment Software Edition:
<#
# Defining function to install NuGet Package Provider
## If NuGet is not installed procedd to install
function Install-NuGet{
if (($NuGet = Get-PackageProvider -Name NuGet ) -eq $null){
    Write-Output "Installing NuGet Package Provider..."
    Set-ExecutionPolicy Bypass Process -Force
    Install-PackageProvider -Name NuGet -Force}
## If NuGet is installed check to see if it requires an update
else{
    $NuGetinstalled = Get-PackageProvider -Name NuGet | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    $NuGetcurrentversion = Find-PackageProvider -Name NuGet | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    if("$NuGetinstalled" -eq "$NuGetcurrentversion"){
        Write-Output "Latest version of NuGet installed ..."}
    else{
        Write-Output "Updating version of NuGet"
        Set-ExecutionPolicy Bypass Process -Force
        Install-PackageProvider -Name NuGet -Force}}}

# Defining function to install the PendingReboot module
function Install-PendingReboot{
if (($PR = Get-Module -Name PendingReboot -ErrorAction SilentlyContinue) -eq $null){
    Write-Output "Installing PendingReboot Module..."
    # Set execution policy to allow installing of module
    Set-ExecutionPolicy Bypass Process -Force
    Install-Module -Name PendingReboot -Force
    Import-Module PendingReboot -Force}
else{
    $PRinstalled = Get-Module -Name PendingReboot | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    $PRcurrentversion = Find-Module -Name PendingReboot | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    if("$PRinstalled" -eq "$PRcurrentversion"){
        Write-Output "Latest version of PendingReboot installed ..."
        Remove-Old-PendingReboot}
    else{
        Write-Output "Updating version of PendingReboot"
        Set-ExecutionPolicy Bypass Process -Force
        Install-Module -Name PendingReboot -Force
        Import-Module PendingReboot -Force
        Remove-Old-PendingReboot}}}


#Defining function to remove older version of PendingReboot
function Remove-Old-PendingReboot{
    # Remove older versions of the module on the host if they exist excluding the latest version
    $PRcurrentversion = Find-Module -Name PendingReboot | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    if ((Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\PendingReboot\" -Exclude "$PRcurrentversion").Exists -ne $null){
        Write-Output "Removing older versions of PendingReboot..."
        Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\PendingReboot\" -Exclude "$PRcurrentversion" | foreach($_){
        Write-Output "Cleaning: $_"
        Remove-Item $_.Fullname -Recurse -Force
        Write-Output "Removed:  $_"}}}

# Defining function to install the PSWindowsUpdate module
function Install-PSWindowsUpdate{
    Write-Output "Installing latest version of PSWindowsUpdate Module..."
    # Set execution policy to allow installing of module
    Set-ExecutionPolicy Bypass Process -Force
    Install-Module -Name PSWindowsUpdate -Force
    Import-Module PSWindowsUpdate -Force}

# Defining Windows Update function "install-windows-update"
function Install-Windows-Update ($date) {
    Write-Output "Begining Windows Update..."
    Get-WUInstall -IgnoreUserInput -AcceptAll -Install -Download -IgnoreReboot
    # Get the history of windows updates on the host and subtract the headers and only select the install date portion
    $last_install = Get-WUHistory| Select -Property Date | Out-String -Stream | Select -Skip 3 | Select -First 1
    # Select the latest update
    # Edit the string to only display mm/dd/yyyy
    $last_install_date = $last_install.Substring(0,10)
    # Eliminate white space in case the date only was like the following: m/dd/yyyy or mm/d/yyyy or m/d/yyyy
    $last_install_date = $last_install_date.trim()
    # Check to see if there was any updates installed when script was ran
    if ("$date" -match "$last_install_date"){
        # If updates were installed show the installed update titles
        $updates = Get-WUHistory| Select -Property Date,Title | Out-String -Stream | Select-String -Pattern "$date"
        Write-Output "Installed updates:`n$updates"
        Write-Output "Windows Update Complete!"}
    else{
        Write-Output "No updates available."}}

# Defining function for removing older versions of PSWindowsUpdate
function Remove-Old-PSWindowsUpdate ($PSWUcurrentversion){
    # Remove older versions of the module on the host if they exist excluding the latest version
    if ((Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate\" -Exclude $PSWUcurrentversion).Exists -ne $null){
        Write-Output "Removing older versions of PSWindowsUpdate"
        Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\PSWindowsUpdate\" -Exclude $PSWUcurrentversion | foreach($_){
        Write-Output "Cleaning:  $_"
        Remove-Item $_.fullname -Recurse -Force
        Write-Output "Removed:  $_"}}}

######################################################################################################################################
########################################                Begin Script            ######################################################
######################################################################################################################################

# Check for installation of NuGet Package Provider and if there is an update available
Install-NuGet
# Install PendingReboot Module
Install-PendingReboot
# Check to see if the host already has the PSWindowsUpdate Module installed
if (($PSWU = Get-Module -Name PSWindowsUpdate -ErrorAction SilentlyContinue) -ne $null){
    # Check the latest version of the module
    ## Outputing the property, converting to a string, and then removing the headers to isolate the value
    $PSWUinstalled = Get-Module -Name PSWindowsUpdate | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    # Check the version available to download, converting to a string, and then removing the headers to isolate the value
    $PSWUcurrentversion = Find-Module -Name PSWindowsUpdate | Select -Property Version | Out-String -Stream | Select-Object -Skip 3 | Select -First 1
    # Get today's date
    $date = Get-Date -Format MM/dd/yyyy
### If the host has the module installed verify it is the latest released version of the module
    if ("$PSWUinstalled" -match "$PSWUcurrentversion" ){
        #Statement if host has the most up to date module
        Write-Output "Latest PSWindowsUpdate Module installed"
        Sleep 5
        # Begin windows update
        Install-Windows-Update}

 ## Path if the host has an outdated PSWindowsUpdate Module
    else{ 
        Write-Output "PSWindowsUpdate Module out of date"
        Install-PSWindowsUpdate
        Remove-Old-PSWindowsUpdate
        Sleep 5
        Install-Windows-Update}}
# Path if host did not have PSWindowsUpdate Module installed
else{
    Write-Output "PSWindowsUpdate Module not installed"
    Install-PSWindowsUpdate
    Install-Windows-Update}
# Check for reboot requirement
if ((Test-PendingReboot -Detailed -SkipConfigurationManagerClientCheck).WindowsUpdateAutoUpdate -eq $True){
    Write-Output "Computer has installed updates that require a reboot. Have a nice day!"}
else{
    Write-Output "No reboot required. Your computer is up to date!"}
#>
