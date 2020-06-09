  <#
.SYNOPSIS
    Script to register the scheduled task
.DESCRIPTION
    Change file permissions on C:\Temp so that only SYSTEM and administrators can modify the contents
    Register the scheduled task and execute the chrome update script to update Chrome and clean up files.
.REQUIRMENTS
    Create the C:\Temp directory if not already created
    Needs the chrome_update_win10.psm1 and the Chrome_Update.xml files in the Temp folder on the host machine
    in order to be activated into the scheduled task. Once all three files are in the Temp folder just run the 
    Register_ScheduledTask.psm1.
.NOTES
    Name:  Register_ScheduledTask.ps1
    Version: 0.0.2
    Author: Hasselhuff
    Last Modified: 09 June 2020
.REFERENCES
    http://www.vsysad.com/2015/04/powershell-script-to-remove-permissions-inheritance-from-a-folder-then-remove-users-group-access-to-it/
    https://stackoverflow.com/questions/31721221/disable-inheritance-and-manually-apply-permissions-when-creating-a-folder-in-pow
#>

$folder = 'C:\Temp'
$acl = Get-ACL -Path $folder
$acl.SetAccessRuleProtection($True, $True)
Set-Acl -Path $folder -AclObject $acl

$acl = Get-Acl "C:\Temp"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\Authenticated Users", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.RemoveAccessRuleAll($accessRule)
$acl | Set-Acl "C:\Temp"

$acl = Get-Acl "C:\Temp"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\Authenticated Users", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($accessRule)
$acl | Set-Acl "C:\Temp"

try{
    Unregister-ScheduledTask -TaskName ChromeUpdate -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path C:\Temp\chrome-update.log -Force -ErrorAction SilentlyContinue
    }
catch{}

Register-ScheduledTask -TaskName "Chrome Update" -Xml (Get-Content "C:\Temp\ChromeUpdate.xml" | Out-String)
Remove-Item -Path C:\Temp\ChromeUpdate.xml -Force -ErrorAction SilentlyContinue
Remove-Item -Path C:\Temp\Register_ScheduledTask.ps1 -Force -ErrorAction SilentlyContinue
