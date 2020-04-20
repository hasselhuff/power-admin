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