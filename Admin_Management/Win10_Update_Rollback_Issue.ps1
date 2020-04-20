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
    Version: 0.0.5
    Authors: Hasselhuff, mclark-titor
    Last Modified: 20 April 2020
.REFERENCES
#>

# Suspend Bitlocker
Suspend-BitLocker -MountPoint "C:" -RebootCount 1

# Pause Windows Update

# Perform Disk Clean Up and clear out windows update cache

# Perform Disk Defragment

# Delete and recreate the SoftwareDistribution folder
Stop-Service -Name BITS -Force
Sleep 1
Stop-Service -Name wuauserv -Force
Sleep 1
Stop-Service -Name CryptSvc -Force
Sleep 1
Stop-Service -Name msiserver -Force
Sleep 1
Remove-Item -Path C:\Windows\SoftwareDistribution -Recurse -Force
Sleep 1
New-Item -Path C:\Windows\ -Name SoftwareDistribution -ItemType Directory -Force
Sleep 1
Start-Service -Name BITS
Sleep 1
Start-Service -Name wuauserv
Sleep 1
Start-Service -Name CryptSvc
Sleep 1
Start-Service -Name msiserver
Sleep 1

# Fix corrupted files
DISM /Online /Cleanup-Image /RestoreHealth
sfc /scannow

# Perform driver updates with Dell Command Update
$dcu_path = (Get-ChildItem -Path C:\ -Filter dcu-cli.exe -ErrorAction SilentlyContinue -Recurse -Force).DirectoryName
cd $dcu_path
.\dcu-cli.exe /scan -report=C:\Users\Edmond.Shore\Desktop\Dell_UpdatesReport.xml                       # Creates xml of available updates from scan
#.\dcu-cli.exe /configure -autoSuspendBitLocker=disable                                                 # Suspend Bitlocker only if an update needs it. Auto enables on reboot
.\dcu-cli.exe /applyUpdates -reboot=enable                                                             # Install all new drivers and updates
#.\dcu-cli.exe /driverInstall                                                                           # Re-install all drivers current drivers

# Disable all non-Microsoft Services except for TeamViewer, Qualys, and CISCO vpn

# Perform restart
Restart-Computer -WhatIf
