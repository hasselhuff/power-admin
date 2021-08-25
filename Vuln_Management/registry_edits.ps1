Write-Host "####    Performing Security Registry Edits    ####"  

# Null Session Restriction registry edit
Write-Host -ForegroundColor Green "Setting: Null Session Restriction"
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\LSA -Name RestrictAnonymous -Type DWord -Value 1 -ErrorAction SilentlyContinue -Force

# Windows Socket Address Sharing Restriction registry edit
Write-Host -ForegroundColor Green "Setting: Windows Socket Address Sharing Restriction"
Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Services\Afd\Parameters -Name DisableAddressSharing -Type DWord -Value 1 -ErrorAction SilentlyContinue -Force

# Windows Update for Spectre Meltdown
Write-Host -ForegroundColor Green "Setting: Windows Update for Spectre Meltdown"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name FeatureSettingsOverride -Type DWord -Value 8 -ErrorAction SilentlyContinue -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name FeatureSettingsOverrideMask -Type DWord -Value 3 -ErrorAction SilentlyContinue -Force

# Disable Windows PowerShell v2.0
Write-Host -ForegroundColor Green "Setting: Disabling Windows PowerShell v2.0"
Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -norestart

# Windows RDP Weak Encryption Method Allowed
Write-Host -ForegroundColor Green "Setting: Disabling Windows RDP Weak Encryption Method"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name MinEncryptionLevel -Type DWord -Value 3 -ErrorAction SilentlyContinue -Force

# Prevent Autorun so applications from any drive can not be automatically executed
Write-Host -ForegroundColor Green "Setting: Prevent Autorun"
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name NoDriveTypeAutorun -PropertyType DWord -Value "255" -ErrorAction SilentlyContinue -Force

# SMB Signing
Write-Host -ForegroundColor Green "Setting: Require SMB Signing"
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanWorkStation\Parameters" -Name RequireSecuritySignature -Type DWord -Value 1 -ErrorAction SilentlyContinue -Force
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanWorkStation\Parameters" -Name EnableSecuritySignature -Type DWord -Value 1 -ErrorAction SilentlyContinue -Force
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanServer\Parameters" -Name RequireSecuritySignature -Type DWord -Value 1 -ErrorAction SilentlyContinue -Force
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanmanServer\Parameters" -Name EnableSecuritySignature -Type DWord -Value 1 -ErrorAction SilentlyContinue -Force
