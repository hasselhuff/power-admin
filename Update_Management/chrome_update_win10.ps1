<#
.SYNOPSIS
    Script to run in GPO startup to auto search for available Chrome updates and apply them.

.DESCRIPTION
    Create the C:\Temp directory if not already created
    Deletes the chrome-update.log file if its creation time is older than 30 days from the current date
    Will perform the following as well as output to the C:\Temp\chrome-update.log
    Checks if Chrome is installed and if so display the current version of Chrome
    Retrieves the current version of Chrome on the host
    Scrapes the latest version of Chrome on the Google Chrome Blog website for Stable Releases
    Compares the installes version with the latest version on the blog
    Auto downloads the Chrome installer if out of date to the C:\Temp folder
    Installs the new download for all users quietly and supresses any restart
    Sets registry key to allow auto updates through the browser
    Deletes the Chrome installer
    Displays the host's new version of Chrome

.NOTES
    Name:  chrome_update_win10.ps1
    Version: 1.2.1
    Author: Hasselhuff
    Last Modified: 16 April 2020

.REFERENCES
    https://chromereleases.googleblog.com/search/label/Stable%20updates
#>


New-Item -Path C:\ -Name Temp -ItemType Directory -Force -ErrorAction SilentlyContinue
$Path = "C:\temp"
$Daysback = "-30"
$CurrentDate = Get-Date
$DatetoDelete = $CurrentDate.AddDays($Daysback)
Get-ChildItem $Path | Where-Object {$_.Name -match "chrome-update.log" -and $_.CreationTime -lt $DatetoDelete } | Remove-Item

if (($word=Test-Path "c:\program files (x86)\google\chrome\application") -eq "True"){
    $file_version = ((Get-Item (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe').'(Default)').VersionInfo).FileVersion
    Write-host "Chrome version: $file_version installed" -ForegroundColor Green
    Write-Output "########################################" >> C:\Temp\chrome-update.log
    Write-Output "Updater launched on $CurrentDate" >> C:\Temp\chrome-update.log
    Write-Output "Chrome version: $file_version installed" >> C:\Temp\chrome-update.log
    # Check if version is latest Chrome release
    $WebResponse = Invoke-WebRequest "https://chromereleases.googleblog.com/search/label/Stable%20updates"
    $latest_version = $WebResponse.Links.Href | Select-String "/stable-channel-update-for-desktop" -Context 1 | Out-String -Stream
    $latest_version = $latest_version | Where {$_ -match "log/"} | Select -First 1
    $latest_version = $latest_version.Replace("https://chromium.googlesource.com/chromium/src/+log/","")
    $latest_version = $latest_version.Replace("?pretty=fuller&amp;n=10000","")
    $latest_version = $latest_version -split "\.\."
    $latest_version = $latest_version[1]
    Write-Host "Latest stable version of chrome is: $latest_version" -ForegroundColor DarkYellow
    Write-Output "Latest stable version of chrome is: $latest_version" >> C:\Temp\chrome-update.log
    $compare_versions = $latest_version.Contains($file_version)
    if($compare_versions -eq $true){
        Write-Host "Host has latest version" -ForegroundColor Green
        Write-Output "Host has latest version" >> C:\Temp\chrome-update.log}
    else{
        $theurl = "http://dl.google.com/edgedl/chrome/install/GoogleChromeStandaloneEnterprise64.msi"
        $output = "c:\Temp\chrome.msi"
        # Get download
        Write-Host "Downloading update" -ForegroundColor Cyan
        Write-Output "Downloading update" >> C:\Temp\chrome-update.log
        Invoke-WebRequest -Uri $theurl -OutFile $output -ErrorAction SilentlyContinue
        #Begin install
        Write-Host "Installing update" -ForegroundColor Cyan
        Write-Output "Installing update" >> C:\Temp\chrome-update.log
        msiexec.exe /i "c:\Temp\chrome.msi" ALLUSERS=1 /qn /norestart /log output.log
        start-sleep -Seconds 300
        # Set Chrome to auto update
        Write-Host "Set Chrome to Auto Update" -ForegroundColor Cyan
        Write-Output "Installing update" >> C:\Temp\chrome-update.log
 #       Reg.exe ADD "HKLM\SOFTWARE\Policies\Google\Update" /v "Update{8A69D345-D564-463C-AFF1-A69D9E530F96}" /d 1 /t REG_DWORD /f
        Write-host "Update complete" -ForegroundColor Green
        $date = Get-Date
        Write-Output "Update complete at $date" >> C:\Temp\chrome-update.log
        $new_file_version = ((Get-Item (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe').'(Default)').VersionInfo).FileVersion
        Write-host "Chrome version: $new_file_version" -ForegroundColor Green
        Write-Output "Chrome version: $new_file_version" >> C:\Temp\chrome-update.log
        Remove-Item -Path c:\Temp\chrome.msi -Force}}
else{
    # Chrome path did not exist
    Write-host "Chrome not installed" -ForegroundColor Red
    Write-Output "Chrome not installed" >> C:\Temp\chrome-update.log}
