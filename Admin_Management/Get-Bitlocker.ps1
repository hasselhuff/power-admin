  <#
.SYNOPSIS
    Checks for Bitlocker entires in all OU's in Active Directory on the domain that the host the script is running off of.
.DESCRIPTION
    Create the "C:\Users\$user\Desktop\Bitlocker\" directory if not already created
    Restricts access to "C:\Users\$user\Desktop\Bitlocker\" to only administrators
    Define's function to retrieve a list of all the stored Bitlocker codes in active directory and exports csv to "C:\Users\$user\Desktop\Bitlocker\"
    Revises the data in the csv to an array in memory then exports new array to new csv in "C:\Users\$user\Desktop\Bitlocker\" and deletes originial csv
    Outgrids the data in the new csv for user to view data
.REQUIRMENTS

.NOTES
    Name:  Get-ADBitlocker
    Version: 1.0.1
    Author: Hasselhuff
    Last Modified: 21 October 2021
.REFERENCES
    https://stackoverflow.com/questions/50411539/retrieving-bitlocker-recovery-keys-from-ad
#>


#Check admin priviliges
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please enter your domain administrative credentials."
    Start-Process -Verb "Runas" -File PowerShell.exe -Argument "-STA -noprofile -file $($myinvocation.mycommand.definition)"
    Break
}

# Setup Desktop location
$user = (Get-CimInstance -ClassName Win32_ComputerSystem).Username
$user = ($user).Split("\")[1]

$filepath = "C:\Users\$user\Desktop\Bitlocker\recovery_keys.csv"

New-Item -Path C:\Users\$user\Desktop\ -Name Bitlocker -ItemType Directory -Force


#SetC:\Users\$user\Desktop\Bitlocker\ to only allow Admin access
Write-Host -ForegroundColor Gray "Restricting C:\Users\$user\Desktop\Bitlocker\ to administrators only."
$folder = "C:\Users\$user\Desktop\Bitlocker"
$acl = Get-Acl $folder 
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Authenticated Users", "ReadAndExecute", "ContainerInherit,ObjectInherit","None", "Allow")
$acl.RemoveAccessRuleAll($accessRule)
$acl | Set-Acl $folder 
$acl = Get-Acl $folder 
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Users", "ReadAndExecute", "ContainerInherit,ObjectInherit","None", "Allow")
$acl.RemoveAccessRuleAll($accessRule)
$acl | Set-Acl $folder 
$acl = Get-Acl $folder 
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "Allow")
$acl.SetAccessRule($accessRule)
$acl | Set-Acl $folder 
$acl = Get-Acl $folder 
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "Allow")
$acl.SetAccessRule($accessRule)
$acl | Set-Acl $folder 

# Define Function
function Get-ADBitlocker {
    param(
        [string] $Domain = $Env:USERDNSDOMAIN,
        [Array] $Computers
    )
    $Properties = @(
        'Name',
        'OperatingSystem'
    )
    #[DateTime] $CurrentDate = Get-Date
    if ($null -eq $Computers) {
        $Computers = Get-ADComputer -Filter * -Properties $Properties -Server $Domain
    }
    foreach ($Computer in $Computers) {
        $Bitlockers = Get-ADObject -Filter 'objectClass -eq "msFVE-RecoveryInformation"' -SearchBase $Computer.DistinguishedName -Properties 'WhenCreated', 'msFVE-RecoveryPassword'
        foreach ($Bitlocker in $Bitlockers) {
            [PSCustomObject] @{
                'Name'                        = $Computer.Name
                'Bitlocker Recovery Password' = $Bitlocker.'msFVE-RecoveryPassword'
                'Bitlocker When'              = $Bitlocker.WhenCreated
                'Operating System'            = $Computer.'OperatingSystem'
            }
        }
    }
}

##################################### Begin Script ###################################
Get-ADBitlocker | Export-Csv -Path $filepath -NoTypeInformation

$import = get-content $filepath
$Table = ConvertFrom-Csv -InputObject $import -Delimiter ','
$count = $table.Count 
Write-Host -ForegroundColor Yellow "Before sanitization: $count bitlocker codes"
Start-Sleep 5

$Host_Names = $Table.Name | Select-Object -Unique
$duplicates_array = @()
[System.Collections.ArrayList]$ArrayList = $Duplicates_Removed
$Duplicates_Removed = @()
Foreach ($H in $Host_Names){
    $duplicates = $Table | Where-Object {$_ -match $H}
    $duplicates_array += $duplicates
    if ($duplicates_array.Count -gt 1){ 
        $duplicates_count = $duplicates_array.Count
        $duplicates_to_remove = $duplicates_count - 1
        Write-Host -ForegroundColor Yellow "Found $duplicates_count duplicates for $H"
        $duplicates_array = $duplicates_array | Sort-Object-Object -Property "Bitlocker When"
        1..$duplicates_to_remove |ForEach-Object {$Duplicates_Removed += $duplicates_array[$_]; Write-Host -ForegroundColor Red "Removing Duplicate # $_"}
        $duplicates_array = @()
        }
    else{
        $duplicates_array = @()
        }
}

[System.Collections.ArrayList]$ArrayList= $New_Table
$New_Table = @()
foreach ($line in $Table){
    if ($line -notin $Duplicates_Removed){
        $New_Table += $line
    }
}
$new_count = $New_Table.Count
Write-Host -ForegroundColor Green "After sanitization: $new_count bitlocker codes"
Remove-Item -Path $filepath

$New_Table | Sort-Object -Property Name | Out-GridView
$New_Table | Sort-Object -Property Name | Export-Csv -Path $filepath -NoTypeInformation
