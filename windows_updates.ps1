<#
.SYNOPSIS
    Allow Windows Updates to be forced via powershell on hosts that are running PowerShell 5.1 or newer.

.DESCRIPTION
    Downloads the PSWindowsUpdate package from NuGet.
    Does not install Cumulative, "already pending but not downloaded", and windows anti-virus libraries.

.EXAMPLE
    # Run powershell as administrator and type path to this script.

Description
-----------
    Checks to see if host has PSWindowsUpdate module and automatically installs if the repository is not found.

.NOTES
    Name:  win10_updates.ps1
    Version: 1.0
    Author: Hasselhuff
    Last Modified: 01 November 2019

.REFERENCES
    https://www.powershellgallery.com/packages/PSWindowsUpdate/2.1.1.2

#>

if ((Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules" -Filter PSWindowsUpdate -Force).exists){
    Get-WUInstall -IgnoreUserInput -AcceptAll -Install -Download -IgnoreReboot
  }
  else {
    Set-ExecutionPolicy Bypass Process -Force
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name PSWindowsUpdate -Force
    Import-Module PSWindowsUpdate
    Get-WUInstall -IgnoreUserInput -AcceptAll -Install -Download -IgnoreReboot
  }