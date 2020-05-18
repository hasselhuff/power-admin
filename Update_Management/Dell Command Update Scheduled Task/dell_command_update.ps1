  <#
.SYNOPSIS
    Script to register a weekly Dell Command Update scan
.DESCRIPTION
    Change file permissions on C:\Temp so that only SYSTEM and administrators can modify the contents
    Register the scheduled task and execute the Dell Command Update to update drivers and clean up files.
.REQUIRMENTS
    Needs the Register_ScheduledTask.psm1 and the Dell_Command_Update.xml files in the Temp folder on the host machine
    in order to be activated into the scheduled task. Once all three files are in the Temp folder just run the 
    Register_ScheduledTask.psm1. It will register the scheduled task and then delete the Register_ScheduledTask.psm1
    and the Dell_Command_Update.xml files. You must keep this script in the Temp folder.
.NOTES
    Name:  dell_command_update.ps1
    Version: 0.0.0.2
    Author: Hasselhuff
    Last Modified: 18 May 2020
.REFERENCES
#>


if(-not(Test-Path C:\Temp\Dell_UpdatesReport.xml)){
    New-Item -Path C:\Temp -Name Dell_UpdatesReport.xml -ItemType File -Force -ErrorAction SilentlyContinue}

$Path = "C:\Temp"
$Daysback = "-10"
$CurrentDate = Get-Date
$DatetoDelete = $CurrentDate.AddDays($Daysback)
Get-ChildItem $Path | Where-Object {$_.Name -match "Dell_UpdatesReport.xml" -and $_.CreationTime -lt $DatetoDelete } | Remove-Item

$dcu_path = (Get-ChildItem -Path C:\ -Filter dcu-cli.exe -ErrorAction SilentlyContinue -Recurse -Force).DirectoryName
Try{
    Test-Path $dcu_path
    Write-Output "######################################################################################################################" >> C:\Temp\Dell_UpdatesReport.xml
    Write-Output "DCU scan begining: $CurrentDate" >> C:\Temp\Dell_UpdatesReport.xml
    & "$dcu_path\dcu-cli.exe" /scan -report=C:\Temp\Dell_UpdatesReport.xml                      # Creates xml of available updates from scan
    & "$dcu_path\dcu-cli.exe" /configure -autoSuspendBitLocker=disable                                                 # Suspend Bitlocker only if an update needs it. Auto enables on reboot
    & "$dcu_path\dcu-cli.exe" /applyUpdates -reboot=enable
    Write-Output "DCU scan complete: $CurrentDate" >> C:\Temp\Dell_UpdatesReport.xml}                                                             # Install all new drivers and updates
Catch{Write-Output "Dell Command Update is not installed on this device" -ForegroundColor Red 
      Write-Output "Dell Command Update is not installed on this device" -ForegroundColor >> C:\Temp\Dell_UpdatesReport.xml}