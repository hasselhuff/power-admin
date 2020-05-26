<#
.SYNOPSIS
   Script to help remediate the rollback ("Undoing Changes" reboot loop due to windows updates.
.REQUIREMENTS
   Affected host needs Dell Command Update installed for driver updates
.DESCRIPTION
    Disables Bitlocker for possible BIOS updates
    Performs Disk Cleanup to clear update cache and clear disk space
    Performs Disk Defragment
    Deletes SoftwareDistribution folder and then recreates it as an empty directory
    Performs DISM and sfc scans to repair corrupted files
    Performs driver update with the Dell Command Update command line utility
    Disables non-Microsoft services with exceptions.
    Performs restart on host
.USAGE
    Run powershell as administrator and type path to this script.
.NOTES
    Name:  Win10_Update_Rollback_Issue.ps1
    Version: 0.1.2
    Authors: Hasselhuff, mclark-titor
    Last Modified: 22 May 2020
.REFERENCES
#>

# Suspend Bitlocker
Write-Host "Suspending Bitlocker" -ForegroundColor Yellow
Suspend-BitLocker -MountPoint "C:" -RebootCount 1
Sleep 1
###################################################################################################################################
# Stop Symantec Agent
Write-Host "Stopping Symantec Agent" -ForegroundColor Yellow
& "C:\Program Files (x86)\Symantec\Symantec Endpoint Protection\smc.exe" -stop
Sleep 3
###################################################################################################################################
# Delete and recreate the SoftwareDistribution and catroot2 folder
Write-Host "Cleaning SoftwareDistribution and Catroot2 Folders" -ForegroundColor Cyan
Stop-Service -Name BITS -Force
Sleep 1
Stop-Service -Name wuauserv -Force
Sleep 1
Stop-Service -Name CryptSvc -Force
Sleep 1
Stop-Service -Name msiserver -Force
Sleep 1
Stop-Service trustedinstaller
Sleep 1
Stop-Service UsoSvc
Sleep 1
Remove-Item -Path C:\Windows\SoftwareDistribution -Recurse -Force
Sleep 1
Remove-Item -Path C:\Windows\System32\catroot2 -Recurse -Force
Start-Service -Name BITS
Sleep 1
Start-Service -Name wuauserv
Sleep 1
Start-Service -Name CryptSvc
Sleep 1
Start-Service -Name msiserver
Sleep 1
Start-Service trustedinstaller
Sleep 1
Start-Service UsoSvc
###################################################################################################################################
# Perform Disk Clean Up and clear out windows update cache
Write-Host "Performing Disk Cleanup" -ForegroundColor Cyan
Sleep 1
$HKLM = [UInt32] “0x80000002”
$strKeyPath = “SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches”
$strValueName = “StateFlags0065”
$subkeys = gci -Path HKLM:\$strKeyPath -Name
ForEach ($subkey in $subkeys) {
Try {
New-ItemProperty -Path HKLM:\$strKeyPath\$subkey -Name $strValueName -PropertyType DWord -Value 2 -ErrorAction SilentlyContinue| Out-Null}
Catch {}}

Sleep 5
Start-Process cleanmgr -ArgumentList “/sagerun:65” -Wait -NoNewWindow -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Sleep 5

ForEach ($subkey in $subkeys) {
Try {
Remove-ItemProperty -Path HKLM:\$strKeyPath\$subkey -Name $strValueName | Out-Null}
Catch {}}
Sleep 5
###################################################################################################################################
# Perform Disk Defragment
Write-Host "Performing Disk Defragment" -ForegroundColor Cyan
Sleep 1
Optimize-Volume -DriveLetter C -Defrag
Sleep 5
###################################################################################################################################
# Fix corrupted files
Write-Host "Restoring Windows Image" -ForegroundColor Cyan
DISM /online /Cleanup-image /startcomponentcleanup
Write-Host "Start Components Cleaned" -ForegroundColor Green
DISM /Online /Cleanup-Image /ScanHealth
Write-Host "Health Scan Completed" -ForegroundColor Green
DISM /Online /Cleanup-Image /CheckHealth
Write-Host "Checked Image Health" -ForegroundColor Green
Sleep 5
DISM /Online /Cleanup-Image /RestoreHealth
Write-Host "Restored Image Health" -ForegroundColor Green
Sleep 5
Write-Host "Performing System File Checks" -ForegroundColor Cyan
cmd /C sfc /scannow
Sleep 3
###################################################################################################################################
# Perform driver updates with Dell Command Update
Write-Host "Begining Driver Updates" -ForegroundColor Cyan
$dcu_path = (Get-ChildItem -Path C:\ -Filter dcu-cli.exe -ErrorAction SilentlyContinue -Recurse -Force).FullName
Try{
    Test-Path $dcu_path
    Write-Host "Searching for Available Driver Updates" -ForegroundColor Cyan
    & "$dcu_path" /applyUpdates -reboot=disable
    Sleep 5}                                      # Install all new drivers and updates and disables auto reboot             
Catch{
    Write-Host "Dell Command Update is not installed on this device" -ForegroundColor Yellow
    Write-Host "Fetching Latest Version of Dell Command | Update" -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $WebResponse = Invoke-WebRequest -Uri "https://www.dell.com/support/article/en-us/sln311129/dell-command-update?lang=en" -UseBasicParsing
    $latest_version_url = $WebResponse.Links.Href | Select-String "DriversDetails" | Out-String -Stream
    $latest_version_url = $latest_version_url[3]
    [System.Uri]$latest_version_url
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $WebResponse2 = Invoke-WebRequest -Uri $latest_version_url -UseBasicParsing
    $latest_version_download = $WebResponse2.Links.Href | Select-String ".exe" | Out-String -Stream
    $latest_version_download = $latest_version_download[1]
    [System.Uri]$latest_version_download
    ##################################################################################################
    $output = "C:\Temp\dcu-setup.exe"
    # Get download
    Write-Host "Downloading Dell Command | Update" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $latest_version_download -OutFile $output -ErrorAction SilentlyContinue
    #Begin install
    Write-Host "Installing Dell Command | Update" -ForegroundColor Cyan
    Start-Process -Wait "C:\Temp\dcu-setup.exe"
    Remove-Item -Path "C:\Temp\dcu-setup.exe" -Force
    Sleep 5
    Write-Host "Searching for Available Driver Updates" -ForegroundColor Cyan
    & "$dcu_path" /applyUpdates -reboot=disable
    #.\dcu-cli.exe /driverInstall                                                                     # Re-install all currently available drivers
    Sleep 5}  
###################################################################################################################################
# Disable all non-Microsoft Services except for TeamViewer, Qualys, CloudBerry, and CISCO vpn
Write-Host "Disabling Non-Microsoft and Buisness Critical Services at Boot Up" -ForegroundColor Yellow
$Required_Services =@(
"AdobeARMservice", "Appinfo", "AudioEndpointBuilder", "Audiosrv", "BDESVC", "BFE", "BITS", "BrokerInfrastructure", "BTAGService", "camsvc", "CbDefense", `
"cbdhsvc_132fce", "CDPSvc", "CDPUserSvc_132fce", "CertPropSvc", "ClickToRunSvc", "CoreMessagingRegistrar", "CryptSvc", "DcomLaunch", "DeviceAssociationService", `
"Dhcp", "DiagTrack", "DispBrokerDesktopSvc", "Dnscache", "DoSvc", "DPS", "DusmSvc", "EventLog", "EventSystem", "FileSyncHelper", "FontCache", "FontCache3.0.0.0", `
"gpsvc", "hidserv", "IKEEXT", "InstallService", "iphlpsvc", "KeyIso", "LanmanServer", "LanmanWorkstation", "LicenseManager", "lmhosts", "LSM", "mpssvc", "NcbService", `
"Netlogon", "netprofm", "NlaSvc", "nsi", "OneDrive Updater Service", "OneSyncSvc_132fce", "online backup Service", "online backup Service Remote Management", "OSE.EXE", `
"OSPPSVC.EXE", "PcaSvc", "perceptionsimulation", "PlugPlay", "PolicyAgent", "policyhost.exe", "Power", "ProfSvc", "QualysAgent", "QWAVE", "RasMan", "RpcEptMapper", "RpcSs", `
"SamSs", "SCardSvr", "Schedule", "SDRSVC", "seclogon", "SecurityHealthService", "SENS", "sepWscSvc", "SgrmBroker", "SharedRealitySvc", `
"ShellHWDetection", "SmsRouter", "spectrum", "Spooler", "SSDPSRV", "SstpSvc", "StateRepository", "StorSvc", "SysMain", "SystemEventsBroker", "TabletInputService", "TapiSrv", `
"TeamViewer", "Themes", "TimeBrokerSvc", "TokenBroker", "TrkWks", "upnphost", "UserManager", "UsoSvc", "VaultSvc", "vpnagent", "W32Time", "WbioSrvc", "Wcmsvc", `
"wcncsvc", "WdiServiceHost", "WdiSystemHost", "Wecsvc", "WerSvc", "WinHttpAutoProxySvc", "Winmgmt", "WinRM", "WlanSvc", "WManSvc", "WpnService", "WpnUserService_132fce", `
"wscsvc", "WSearch", "msiserver", "TrustedInstaller", "IAStorDataMgrSvc")

$All_Services = (Get-Service).Name
$Disabled_Services = @()
$Disabled_Services = New-Object System.Collections.Generic.List[System.Object]
Foreach ($service in $All_Services){
    $Service_Status = (Get-Service -Name $service).Status
    if ($service -notin $Required_Services -and $Service_Status -match "Running"){
        Write-Host "Disabling: $service" -ForegroundColor Yellow
        #Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
        $Disabled_Services.Add("$service")}}

try{
    Add-Content -Value $Disabled_Services -Path C:\Temp\Disabled_Services.txt}
catch{
    New-Item -Path C:\ -Name Temp -ItemType Directory -Force
    Add-Content -Value $Disabled_Services -Path C:\Temp\Disabled_Services.txt}

#Set TeamViewer to Auto Start
Write-Host "Set TeamViewer Service to Start on Boot" -ForegroundColor Cyan
Set-Service -Name TeamViewer -StartupType Automatic
Sleep 1

# Perform restart
Write-Host "Restarting Computer in 5 seconds" -ForegroundColor Yellow
Sleep 5
Restart-Computer

# Links to May 2020 Windows Update downloads:
# https://www.catalog.update.microsoft.com/Search.aspx?q=4552931
# https://www.catalog.update.microsoft.com/Search.aspx?q=4556799