# Null Session Restriction registry edit
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\LSA -Name RestrictAnonymous -Type DWord -Value 1 -Force

# Windows Socket Address Sharing Restriction registry edit
Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Services\Afd\Parameters -Name DisableAddressSharing -Type DWord -Value 1 -Force

# Windows Update for Spectr Meltdown
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name FeatureSettingsOverride -Type DWord -Value 8 -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name FeatureSettingsOverrideMask -Type DWord -Value 3 -Force

# Disable Windows PowerShell v2.0
Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -norestart
