#Check admin priviliges
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator") )  {
    Write-Warning "Please enter your domain administrative credentials."
    Start-Process -Verb "Runas" -File PowerShell.exe -Argument "-STA -noprofile -file $($myinvocation.mycommand.definition)"
    Break
}

# Suspend Bitlocker
$BLvols = Get-BitLockerVolume | Select-Object -Property MountPoint,ProtectionStatus 
foreach($vol in $BLvols){
    $mountpoint = $vol.MountPoint
    $status = $vol.ProtectionStatus
    if($status -match "On"){
        Write-Host "Suspending Bitlocker for volume $mountpoint" -ForegroundColor Yellow
        Suspend-BitLocker -MountPoint $mountpoint -RebootCount 1
    }
}
###################################################################################################################################
# Create function to check/ install/ update a Package Provider
# Example of useage:  Install-NewProvider -ProviderName NuGet
function Install-NewProvider{
    # Setup Parameter for command
    param ([string]$ProviderName)

if ( $null -eq ($Installed_Provider = Get-PackageProvider -Name $ProviderName )){
    Write-Host -ForegroundColor Cyan "Installing $ProviderName Package Provider..."
    Set-ExecutionPolicy Bypass Process -Force
    Install-PackageProvider -Name $ProviderName -Force}
    # If Provider is installed check to see if it requires an update
else{
    $Installed_Provider = Get-PackageProvider -Name $ProviderName | Select-Object -Property Version | Out-String -Stream | Select-Object-Object -Skip 3 | Select-Object -First 1
    $Available_Provider = Find-PackageProvider -Name $ProviderName | Select-Object -Property Version | Out-String -Stream | Select-Object-Object -Skip 3 | Select-Object -First 1
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
    $CurrentVersion = Find-Module -Name $ModuleName | Select-Object -Property Version | Out-String -Stream | Select-Object-Object -Skip 3 | Select-Object -First 1
    if ( $null -ne (Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\$ModuleName\" -Exclude $CurrentVersion).Exists){
        Write-Host -ForegroundColor Red "Removing older versions of $ModuleName"
        Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\$ModuleName\" -Exclude $CurrentVersion | ForEach-Object ($_){
        Write-Host -ForegroundColor Red "Cleaning:  $_"
        Remove-Item $_.fullname -Recurse -Force
        Write-Host -ForegroundColor Green "Removed:  $_"}}}

# Create function to check if a module is installed then proceeds to install/ update/ remove older versions of the module
# Example of useage:  Check-ModuleInstall -ModuleName PSWindowsUpdate
function Check-ModuleInstall{
    # Setup Parameter for command
    param ([string]$ModuleName)

    if ( $null -eq ($Module = Get-Package -Name $ModuleName -ErrorAction SilentlyContinue)){
        Write-Host -ForegroundColor Cyan "Installing $ModuleName Module..."
        # Install module
        Install-NewModule -ModuleName $ModuleName}
    else{
        $Module_Installed = Get-Package -Name $ModuleName | Select-Object -Property Version | Out-String -Stream | Select-Object-Object -Skip 3 | Select-Object -First 1
        $Module_Available = Find-Module -Name $ModuleName | Select-Object -Property Version | Out-String -Stream | Select-Object-Object -Skip 3 | Select-Object -First 1
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
    $date = Get-Date -Format g | Out-String -Stream
    $date = $date.Split(' ',2)
    $date = $date[0]
    # Begin Windows Update
    Write-Host -ForegroundColor Cyan "Begining Windows Update..."
    Get-WUInstall -IgnoreUserInput -AcceptAll -Install -Download -IgnoreReboot
    # Get the history of windows updates on the host and isolate to the latest update by subtracting the headers and only select the install date portion
    $last_install = Get-WUHistory| Select-Object -Property Date | Out-String -Stream | Select-Object -Skip 3 | Select-Object -First 1
    # Split the string at the space to separate the date and the time in an array
    $last_install_date = $last_install.Split(' ',2)
    # Select-Object the first value of the array which is the date portion
    $last_install_date = $last_install_date[0]
    # Check to see if there was any updates installed when script was ran
if ("$date" -match "$last_install_date"){
    # If updates were installed show the installed update titles
    $updates = Get-WUHistory| Select-Object -Property Date,Title | Out-String -Stream | Select-Object-String -Pattern "$date"
    Write-Host -ForegroundColor Green "Windows Update Complete!"
    Write-Host -ForegroundColor White "Installed updates: "
    # Break down the $updates variable into individual lines if there was more than one update installed
    foreach($u in $updates){
        # Converting the new variable for the inidividual line into a string
        $u = $u.ToString()
        # Separating at each space between the date, time, AM/PM, and the update name
        $u = $u.Split(' ', 4)
        # Selecting only the update name
        $u = $u[3]
        Write-Host -ForegroundColor Green "$u"}}
else{
    Write-Host "No updates available."}}

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
    Write-Host -ForegroundColor Yellow "Computer has installed updates that require a reboot. Restarting in 5 seconds"
    Start-Sleep 5
    Restart-Computer}
else{
    $Disabled_Services = Get-Content -Path C:\Temp\Disabled_Services.txt
    Write-Host -ForegroundColor Green "No reboot required. Your computer is up to date!"
    Write-Host -ForegroundColor Cyan "Re-enabling Disabled Services"
    Foreach ($d_service in $Disabled_Services){
    Write-Host "Starting Service: $d_service" -ForegroundColor Green
    Set-Service -Name $d_service -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name $service -ErrorAction SilentlyContinue}}
