# Null Session Restriction registry edit
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\LSA" /v RestrictAnonymous /t REG_DWORD /d 1 /f
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\LSA -Name RestrictAnonymous -Type DWord -Value 1 -Force

# Windows Socket Address Sharing Restriction registry edit
reg add "HKLM\System\CurrentControlSet\Services\Afd\Parameters" /v DisableAddressSharing /t REG_DWORD /d 1 /f
Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Services\Afd\Parameters -Name DisableAddressSharing -Type DWord -Value 1 -Force

# Windows Update for Spectr Meltdown
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /t REG_DWORD /d 8 /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /t REG_DWORD /d 3 /f

# Disable Windows PowerShell v2.0
Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -norestart