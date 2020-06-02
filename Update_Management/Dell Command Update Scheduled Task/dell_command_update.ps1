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
    Version: 0.0.0.3
    Author: Hasselhuff
    Last Modified: 02 June 2020
.REFERENCES
    https://www.dell.com/support/manuals/us/en/04/command-update/dellcommandupdate_3.1.1_ug/command-line-interface-reference?guid=guid-92619086-5f7c-4a05-bce2-0d560c15e8ed&lang=en-us
    https://gallery.technet.microsoft.com/scriptcenter/Windows-Unquoted-Service-190f0341
    https://www.tenable.com/sc-report-templates/microsoft-windows-unquoted-service-path-enumeration
    http://www.commonexploits.com/unquoted-service-paths/
#>

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

if(-not(Test-Path C:\Temp\Dell_UpdatesReport.log)){
    New-Item -Path C:\Temp -Name Dell_UpdatesReport.log -ItemType File -Force -ErrorAction SilentlyContinue}

$Path = "C:\Temp"
$Daysback = "-10"
$CurrentDate = Get-Date
$DatetoDelete = $CurrentDate.AddDays($Daysback)
Get-ChildItem $Path | Where-Object {$_.Name -match "Dell_UpdatesReport.log" -and $_.CreationTime -lt $DatetoDelete } | Remove-Item

$Path = "C:\Temp"
$Daysback = "-10"
$CurrentDate = Get-Date
$DatetoDelete = $CurrentDate.AddDays($Daysback)
Get-ChildItem $Path | Where-Object {$_.Name -match "ServicesFix-3.3.1.log" -and $_.CreationTime -lt $DatetoDelete } | Remove-Item

Write-Host "Begining Driver Updates" -ForegroundColor Cyan
$dcu_path = (Get-ChildItem -Path C:\ -Filter dcu-cli.exe -ErrorAction SilentlyContinue -Recurse -Force).FullName
Try{
    Test-Path $dcu_path
    Write-Host "Searching for Available Driver Updates" -ForegroundColor Cyan >> C:\Temp\Dell_UpdatesReport.log
    & "$dcu_path" /scan -silent
    & "$dcu_path" /applyUpdates -reboot=disable -outputLog=C:\Temp\Dell_UpdatesReport.log
    Sleep 5}                                                
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
    Write-Host "Searching for Available Driver Updates" -ForegroundColor Cyan >> C:\Temp\Dell_UpdatesReport.log
    & "$dcu_path" /scan -silent
    & "$dcu_path" /applyUpdates -reboot=disable -outputLog=C:\Temp\Dell_UpdatesReport.log
    #.\dcu-cli.exe /driverInstall                                                                     # Re-install all currently available drivers
    Sleep 5} 

##################################################################################################
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
