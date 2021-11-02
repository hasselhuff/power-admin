# Windows Update Rollback

Steps:
1. Run 1.Win10_Update_Rollback_TroubleShoot.ps1 to remediate multiple possible issues
2. Restart the computer
3. Attempt windows update, or run 2.Win10_Update_Rollback_Install_Updates.ps1 to install via commandline
> Note:
> 2.Win10_Update_Rollback_Install_Updates.ps1 involves downloading and installing multiple PowerShell modules.
4. Restart the computer
5. Run 3.Win10_Update_Rollback_Enable_Services.ps1 to re-enable services that were disabled during 1.Win10_Update_Rollback_TroubleShoot.ps1
