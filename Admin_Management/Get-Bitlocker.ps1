  <#
.SYNOPSIS
    Checks for Bitlocker entires in all OU's in Active Directory on the domain that the host the script is running off of.
.DESCRIPTION
    Create the C:\Temp directory if not already created
    Restricts access to C:\Temp to only administrators
    Define's function to retrieve a list of all the stored Bitlocker codes in active directory and exports csv to C:\Temp
    Revises the data in the csv to an array in memory then exports new array to new csv in C:\Temp and deletes originial csv
    Outgrids the data in the new csv for user to view data
.REQUIRMENTS

.NOTES
    Name:  Get-ADBitlocker
    Version: 1.0.0
    Author: Hasselhuff
    Last Modified: 14 July 2020
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

# Test C:\Temp direcotry
try{
    Test-Path -Path C:\Temp 
    Write-Host -ForegroundColor Green "C:\Temp directory exists"
    }
catch{
    Write-Host -ForegroundColor Red "C:\Temp directory does not exist, creating directory"
    New-Item -Path C:\ -Name Temp -ItemType Directory -Force
    }

#Set C:\Temp to only allow Admin access
Write-Host -ForegroundColor Gray "Restricting C:\Temp to administrators only."
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
Get-ADBitlocker | Export-Csv -Path C:\Temp\bitlocker_codes.csv -NoTypeInformation

$import = get-content C:\Temp\bitlocker_codes.csv
$Table = ConvertFrom-Csv -InputObject $import -Delimiter ','
$count = $table.Count 
Write-Host -ForegroundColor Yellow "Before sanitization: $count bitlocker codes"
sleep 5

$Host_Names = $Table.Name | Select -Unique
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
        $duplicates_array = $duplicates_array | Sort-Object -Property "Bitlocker When"
        1..$duplicates_to_remove | % {$Duplicates_Removed += $duplicates_array[$_]; Write-Host -ForegroundColor Red "Removing Duplicate # $_"}
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
sleep 5

$New_Table | Sort -Property Name | Out-GridView
$New_Table | Sort -Property Name |Export-Csv -Path C:\Temp\bitlocker_backup.csv -NoTypeInformation

Remove-Item -Path "C:\Temp\bitlocker_codes.csv"