<#
.SYNOPSIS
   Script to help remediate the rollback ("Undoing Changes" reboot loop due to windows updates.
.REQUIREMENTS
   Affected host needs Dell Command Update installed for driver updates
.DESCRIPTION
    Disables Bitlocker for possible BIOS updates
    Deletes SoftwareDistribution and Catroot2 folders
    Performs Disk Cleanup to clear update cache and clear disk space
    Performs Disk Defragment
    Performs DISM and sfc scans to repair corrupted files
    Enables .NET Frameworks
    Performs driver update with the Dell Command Update command line utility
    Runs quoted service check and auto corrects
    Disables non-Microsoft services with exceptions
    Set TemaViewer service to auto start
    Performs restart on host
.USAGE
    Run powershell as administrator and type path to this script.
.NOTES
    Name:  Win10_Update_Rollback_Issue.ps1
    Version: 0.1.2
    Authors: Hasselhuff, mclark-titor
    Last Modified: 21 October 2021
.REFERENCES
    http://www.theservergeeks.com/how-todisk-cleanup-using-powershell/
    https://www.dell.com/support/manuals/us/en/04/command-update/dellcommandupdate_3.1.1_ug/command-line-interface-reference?guid=guid-92619086-5f7c-4a05-bce2-0d560c15e8ed&lang=en-us
    https://gallery.technet.microsoft.com/scriptcenter/Windows-Unquoted-Service-190f0341
    https://www.tenable.com/sc-report-templates/microsoft-windows-unquoted-service-path-enumeration
    http://www.commonexploits.com/unquoted-service-paths/
#>
# This is for quoted service fix later on in the script (must be ran)
    Param (
    [parameter(Mandatory=$false)]
    [Alias("s")]
        [Bool]$FixServices=$true,
    [parameter(Mandatory=$false)]
    [Alias("u")]
        [Switch]$FixUninstall,
    [parameter(Mandatory=$false)]
    [Alias("e")]
        [Switch]$FixEnv,
    [parameter(Mandatory=$false)]
    [Alias("ShowOnly")]
        [Switch]$WhatIf,
    [parameter(Mandatory=$false)]
    [Alias("h")]
        [switch]$Help,
    [System.IO.FileInfo]$Logname = "C:\Temp\ServicesFix-3.3.1.Log"
)

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
# Delete and recreate the SoftwareDistribution and catroot2 folder
Write-Host "Cleaning SoftwareDistribution and Catroot2 Folders" -ForegroundColor Cyan
Stop-Service -Name BITS -Force
Stop-Service -Name wuauserv -Force
Stop-Service -Name CryptSvc -Force
Stop-Service -Name msiserver -Force
Stop-Service trustedinstaller -Force
Stop-Service UsoSvc -Force
Rename-Item -Path C:\Windows\SoftwareDistribution -NewName SD.old -Force
Remove-Item -Path C:\Windows\SD.old -Recurse -Force
Remove-Item -Path C:\Windows\System32\catroot2 -Recurse -Force
Start-Service -Name BITS
Start-Service -Name wuauserv
Start-Service -Name CryptSvc
Start-Service -Name msiserver
Start-Service trustedinstaller
Start-Service UsoSvc
###################################################################################################################################
# Perform Disk Clean Up and clear out windows update cache
Write-Host "Performing Disk Cleanup" -ForegroundColor Cyan
$strKeyPath = “SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches”
$strValueName = “StateFlags0065”
$subkeys = Get-ChildItem -Path HKLM:\$strKeyPath -Name
ForEach ($subkey in $subkeys) {
    Try {
        New-ItemProperty -Path HKLM:\$strKeyPath\$subkey -Name $strValueName -PropertyType DWord -Value 2 -ErrorAction SilentlyContinue| Out-Null}
    Catch {}
}
Start-Sleep 5
Start-Process cleanmgr -ArgumentList “/sagerun:65” -Wait -NoNewWindow -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Start-Sleep 5
ForEach ($subkey in $subkeys) {
    Try {
        Remove-ItemProperty -Path HKLM:\$strKeyPath\$subkey -Name $strValueName | Out-Null}
    Catch {}
}
###################################################################################################################################
# Perform Disk Defragment
Write-Host "Performing Disk Defragment" -ForegroundColor Cyan
Start-Sleep 1
Optimize-Volume -DriveLetter C -Defrag
###################################################################################################################################
# Fix corrupted files
DISM /Online /Cleanup-Image /CheckHealth
Write-Host "Checked Image Health" -ForegroundColor Green
DISM /Online /Cleanup-Image /ScanHealth
Write-Host "Health Scan Completed" -ForegroundColor Green
DISM /online /Cleanup-image /startcomponentcleanup
Write-Host "Start Components Cleaned" -ForegroundColor Green
DISM /Online /Cleanup-Image /RestoreHealth
Write-Host "Restored Image Health" -ForegroundColor Green
Write-Host "Performing System File Checks" -ForegroundColor Cyan
cmd /C sfc /scannow
###################################################################################################################################
# Enabling .NET Frameworks
Write-Host -ForegroundColor Cyan "Checking for Available .NET Frameworks"
$ASPNET = (Get-WindowsOptionalFeature -Online | Where-Object {$_.State -match "Disabled" -and $_.FeatureName -match '\w*-ASPNET\d\d' -and $_.FeatureName -match '^Net'}).FeatureName

if ( $null -ne $ASPNET){
    foreach ($a in $ASPNET){
        Write-Host -ForegroundColor Green "$a is available!"
        Enable-WindowsOptionalFeature -Online -FeatureName $a -NoRestart -ErrorAction SilentlyContinue }}
else{
    Write-Host -ForegroundColor Red "There is no ASP .NET Framework available for install"}
###################################################################################################################################
# Fix any services that got updated that need to be quoted
Write-Host "Searching for unquoted services" -ForegroundColor Cyan
Function Write-FileLog {
    Param (
        [parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        [AllowEmptyString()]
        [AllowNull()]
            [String[]]$Value,
        [parameter(Mandatory=$true,
            Position=1)]
        [alias("File","Filename","FullName")]
        [ValidateScript({
            If (Test-Path $_){
                -NOT ((Get-Item $_).Attributes -like "*Directory*")
            }
            ElseIf (-NOT (Test-Path $_)){
                $Tmp = $_
                $Tmp -match '(?''path''^\w\:\\([^\\]+\\)+)(?''filename''[^\\]+)' | Out-Null
                $TmpPath = $Matches['path']
                $Tmpfilename = $Matches['filename']
                New-Item -ItemType Directory $TmpPath -Force -ErrorAction Stop
                New-Item -ItemType File $TmpPath$Tmpfilename -ErrorAction Stop
            } # End ElseIf blockk
        })] # End validate script
            [String]$Logname,
        [String]$AddAtBegin,
        [String]$AddToEnd,
        [String]$AddAtBeginRegOut,
        [String]$AddToEndRegOut,
        [switch]$SkipNullString,
        [switch]$OutOnScreen,
        [String]$OutRegexpMask
    ) # End Param block
    Begin {}
    Process {
        $Value -split '\n' | ForEach-Object {

            If ($SkipNullString -and (-not (([string]::IsNullOrEmpty($($_))) -or ([string]::IsNullOrWhiteSpace($($_)))))){
                If ([String]::IsNullOrEmpty($OutRegexpMask)){
                    If ($OutOnScreen){"$AddAtBegin$($_ -replace '\r')$AddToEnd"}
                    "$AddAtBegin$($_ -replace '\r')$AddToEnd" | out-file $Logname -Append
                } # End If
                ElseIf (![String]::IsNullOrEmpty($OutRegexpMask)){
                    If ($($_ -replace '\r') -match $OutRegexpMask){
                        Write-Output "$AddAtBeginRegOut$($_ -replace '\r')$AddToEndRegOut"
                        "$AddAtBeginRegOut$($_ -replace '\r')$AddToEndRegOut" | out-file $Logname -Append
                    } # End If
                    Else {
                        "$AddAtBegin$($_ -replace '\r')$AddToEnd" | out-file $Logname -Append
                    } # End Else
                } # End elseif
            } # End If
            ElseIF (-not ($SkipNullString)){
                If ([String]::IsNullOrEmpty($OutRegexpMask)){
                    If ($OutOnScreen){"$AddAtBegin$($_ -replace '\r')$AddToEnd"}
                    "$AddAtBegin$($_ -replace '\r')$AddToEnd" | out-file $Logname -Append
                } # End If
                ElseIf (![String]::IsNullOrEmpty($OutRegexpMask)){
                    If (($($_ -replace '\r') -match $OutRegexpMask) -or ([string]::IsNullOrEmpty($($_))) -or ([string]::IsNullOrWhiteSpace($($_)))){
                        Write-Output  "$AddAtBeginRegOut$($_ -replace '\r')$AddToEndRegOut"
                        "$AddAtBeginRegOut$($_ -replace '\r')$AddToEndRegOut" | out-file $Logname -Append
                    } # End If
                    Else {
                        "$AddAtBegin$($_ -replace '\r')$AddToEnd" | out-file $Logname -Append
                    } # End Else
                } # End elseif
            } # End elseif
        } # End Foreach
    } # End process
    End {}
} # End Function


Function Fix-ServicePath
{
    Param (
        [bool]$FixServices=$true,
        [Switch]$FixUninstall,
        [Switch]$FixEnv,
        [Switch]$WhatIf
    )

    Write-Output "$(get-date -format u)  :  INFO  : Computername: $($Env:COMPUTERNAME)"

    # Get all services
    $FixParameters = @()
    If ($FixServices){
        $FixParameters += @{"Path" = "HKLM:\SYSTEM\CurrentControlSet\Services\" ; "ParamName" = "ImagePath"}
    }
    If ($FixUninstall){
        $FixParameters += @{"Path" = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" ; "ParamName" = "UninstallString"}
        # If OS x64 - adding pathes for x86 programs
        If (Test-Path "$($env:SystemDrive)\Program Files (x86)\"){
            $FixParameters += @{"Path" = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\" ; "ParamName" = "UninstallString"}
        }
    }
    ForEach ($FixParameter in $FixParameters){
        Get-ChildItem $FixParameter.path -ErrorAction SilentlyContinue | ForEach-Object {
            $SpCharREGEX = '([\[\]])'
            $RegistryPath =$_.name -Replace 'HKEY_LOCAL_MACHINE', 'HKLM:' -replace $SpCharREGEX,'`$1'
            $OriginalPath = (Get-ItemProperty "$RegistryPath")
            $ImagePath = $OriginalPath.$($FixParameter.ParamName)
            If ($FixEnv){
                If ($($OriginalPath.$($FixParameter.ParamName)) -match '%(?''envVar''[^%]+)%'){
                    $EnvVar = $Matches['envVar']
                    $FullVar = (Get-Childitem env: | Where-Object {$_.Name -eq $EnvVar}).value
                    $ImagePath = $OriginalPath.$($FixParameter.ParamName) -replace "%$EnvVar%",$FullVar
                    Clear-Variable Matches
                } # End If
            } # End If $fixEnv
            # Get all services with vulnerability
            If (($ImagePath -like "* *") -and ($ImagePath -notlike '"*"*') -and ($ImagePath -like '*.exe*')){
                # Skip MsiExec.exe in uninstall strings
                If ((($FixParameter.ParamName -eq 'UninstallString') -and ($ImagePath -NotMatch 'MsiExec(\.exe)?')) -or ($FixParameter.ParamName -eq 'ImagePath')){
                    $NewPath = ($ImagePath -split ".exe ")[0]
                    $key = ($ImagePath -split ".exe ")[1]
                    $triger = ($ImagePath -split ".exe ")[2]
                    $NewValue = ''
                    # Get service with vulnerability with key in ImagePath
                    If (-not ($triger | Measure-Object).count -ge 1){
                        If (($NewPath -like "* *") -and ($NewPath -notlike "*.exe")){
                            $NewValue = "`"$NewPath.exe`" $key"
                        } # End If
                        # Get service with vulnerability with out key in ImagePath
                        ElseIf (($NewPath -like "* *") -and ($NewPath -like "*.exe")){
                            $NewValue = "`"$NewPath`""
                        } # End ElseIf
                        If ((-not ([string]::IsNullOrEmpty($NewValue))) -and ($NewPath -like "* *")) {
                            try {
                                $soft_service = $(if($FixParameter.ParamName -Eq 'ImagePath'){'Service'}Else{'Software'})
                                Write-Output "$(get-date -format u)  :  Old Value : $soft_service : '$($OriginalPath.PSChildName)' - $($OriginalPath.$($FixParameter.ParamName))"
                                Write-Output "$(get-date -format u)  :  Expected  : $soft_service : '$($OriginalPath.PSChildName)' - $NewValue"
                                If (! $WhatIf){
                                    $OriginalPSPathOptimized = $OriginalPath.PSPath -replace $SpCharREGEX, '`$1'
                                    Set-ItemProperty -Path $OriginalPSPathOptimized -Name $($FixParameter.ParamName) -Value $NewValue -ErrorAction Stop
                                    $DisplayName = ''
                                    $keyTmp = (Get-ItemProperty -Path $OriginalPSPathOptimized)
                                    If ($soft_service -match 'Software'){
                                        $DisplayName =  $keyTmp.DisplayName
                                    }
                                    If ($keyTmp.$($FixParameter.ParamName) -eq $NewValue){
                                        Write-Output "$(get-date -format u)  :  SUCCESS  : Path value was changed for $soft_service '$(if($DisplayName){$DisplayName}else{$OriginalPath.PSChildName})'"
                                    } # End If
                                    Else {
                                        Write-Output "$(get-date -format u)  :  ERROR  : Something is going wrong. Path was not changed for $soft_service '$(if($DisplayName){$DisplayName}else{$OriginalPath.PSChildName})'."
                                    } # End Else
                                } # End If
                            } # End try
                            Catch {
                                Write-Output "$(get-date -format u)  :  ERROR  : Something is going wrong. Value changing failed in service '$($OriginalPath.PSChildName)'."
                                Write-Output "$(get-date -format u)  :  ERROR  : $_"
                            } # End Catch
                            Clear-Variable NewValue
                        } # End If
                    } # End Main If
                } # End if (Skip not needed strings)
            } # End If

            If (($triger | Measure-Object).count -ge 1) {
                Write-Output "$(get-date -format u)  :  ERROR  : Can't parse  $($OriginalPath.$($FixParameter.ParamName)) in registry  $($OriginalPath.PSPath -replace 'Microsoft\.PowerShell\.Core\\Registry\:\:') "
            } # End If
        } # End Foreach
    } # End Foreach
}

Function Get-OSandPoShArchitecture {
    # Check OS architecture
    if ((Get-WmiObject win32_operatingsystem | Select-Object osarchitecture).osarchitecture -eq "64-bit"){
        if ([intptr]::Size -eq 8){
            Return $true, $true
        } 
        Else {
            Return $true, $false
        }
    }
    else { Return $false, $false }
}

if ((! $FixServices) -and (! $FixUninstall)){
    Throw "Should be selected at least one of two parameters: FixServices or FixUninstall. `r`n For more details use 'get-help Windows_Path_Enumerate.ps1 -full'"
}
if ($Help){
    Write-Output "For help use this command in powershell: Get-Help $($MyInvocation.MyCommand.Path) -full"
    powershell -command "& Get-Help $($MyInvocation.MyCommand.Path) -full"
    exit
}

$OS, $PoSh = Get-OSandPoShArchitecture
If (($OS -eq $true) -and ($PoSh -eq $true)){
    $validation = "$(get-date -format u)  :  INFO  : Executed x64 Powershell on x64 OS"
} elseIf (($OS -eq $true) -and ($PoSh -eq $false)) {
    $validation =  "$(get-date -format u)  :  WARNING  : !ATTENTION! : Executed x32 Powershell on x64 OS. Not all vulnerabilities could be fixed.`r`n"
    $validation += "$(get-date -format u)  :  WARNING  : For fixing all vulnerabilities should be used x64 Powershell."
} else {
    $validation = "$(get-date -format u)  :  INFO  : Executed x32 Powershell on x32 OS"
}

if (! [string]::IsNullOrEmpty($Logname)){
    '*********************************************************************' | Write-FileLog -Logname $Logname
    $validation | Write-FileLog -Logname $Logname -OutOnScreen
    Fix-ServicePath `
        -FixUninstall:$FixUninstall `
        -FixServices:$FixServices `
        -WhatIf:$WhatIf `
        -FixEnv:$FixEnv | Write-FileLog -Logname $Logname -OutOnScreen
} else {
    Write-Output $validation
    Fix-ServicePath `
        -FixUninstall:$FixUninstall `
        -FixServices:$FixServices `
        -WhatIf:$WhatIf `
        -FixEnv:$FixEnv
}
###################################################################################################################################
# Disable all non-Microsoft Services except for TeamViewer
Write-Host "Disabling Non-Microsoft and Buisness Critical Services at Boot Up" -ForegroundColor Yellow
$Required_Services =@(
"AdobeARMservice", "Appinfo", "AudioEndpointBuilder", "Audiosrv", "BDESVC", "BFE", "BITS", "BrokerInfrastructure", "BTAGService", "camsvc", "CbDefense", `
"cbdhsvc_132fce", "CDPSvc", "CDPUserSvc_132fce", "CertPropSvc", "ClickToRunSvc", "CoreMessagingRegistrar", "CryptSvc", "DcomLaunch", "DeviceAssociationService", `
"Dhcp", "DiagTrack", "DispBrokerDesktopSvc", "Dnscache", "DoSvc", "DPS", "DusmSvc", "EventLog", "EventSystem", "FileSyncHelper", "FontCache", "FontCache3.0.0.0", `
"gpsvc", "hidserv", "IKEEXT", "InstallService", "iphlpsvc", "KeyIso", "LanmanServer", "LanmanWorkstation", "LicenseManager", "lmhosts", "LSM", "mpssvc", "NcbService", `
"Netlogon", "netprofm", "NlaSvc", "nsi", "OneDrive Updater Service", "OneSyncSvc_132fce", "online backup Service", "OSE.EXE", `
"OSPPSVC.EXE", "PcaSvc", "perceptionsimulation", "PlugPlay", "PolicyAgent", "policyhost.exe", "Power", "ProfSvc", "QWAVE", "RasMan", "RpcEptMapper", "RpcSs", `
"SamSs", "SCardSvr", "Schedule", "SDRSVC", "seclogon", "SecurityHealthService", "SENS", "sepWscSvc", "SgrmBroker", "SharedRealitySvc", `
"ShellHWDetection", "SmsRouter", "spectrum", "Spooler", "SSDPSRV", "SstpSvc", "StateRepository", "StorSvc", "SysMain", "SystemEventsBroker", "TabletInputService", "TapiSrv", `
"TeamViewer", "Themes", "TimeBrokerSvc", "TokenBroker", "TrkWks", "upnphost", "UserManager", "UsoSvc", "VaultSvc", "W32Time", "WbioSrvc", "Wcmsvc", `
"wcncsvc", "WdiServiceHost", "WdiSystemHost", "Wecsvc", "WerSvc", "WinHttpAutoProxySvc", "Winmgmt", "WinRM", "WlanSvc", "WManSvc", "WpnService", "WpnUserService_132fce", `
"wscsvc", "WSearch", "msiserver", "TrustedInstaller", "IAStorDataMgrSvc")

$All_Services = (Get-Service).Name
$Disabled_Services = @()
$Disabled_Services = New-Object System.Collections.Generic.List[System.Object]
Foreach ($service in $All_Services){
    if ($service -notin $Required_Services){
        Write-Host "Disabling: $service" -ForegroundColor Yellow
        Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
        $Disabled_Services.Add("$service")
    }
}
New-Item -Path C:\ -Name Temp -ItemType Directory -Force
Add-Content -Value $Disabled_Services -Path C:\Temp\Disabled_Services.txt

#Set TeamViewer or AnyDesk to Auto Start
if( $null -notmatch (Get-Service TeamViewer -ErrorAction SilentlyContinue)){
    Write-Host "Set TeamViewer Service to Start on Boot" -ForegroundColor Cyan
    Set-Service -Name TeamViewer -StartupType Automatic
}

if( $null -notmatch (Get-Service AnyDesk -ErrorAction SilentlyContinue)){
    Write-Host "Set AnyDesk Service to Start on Boot" -ForegroundColor Cyan
    Set-Service -Name TeamViewer -StartupType Automatic
}

# Perform restart
Write-Host "Restarting Computer in 5 seconds" -ForegroundColor Yellow
Start-Sleep 5
Restart-Computer
