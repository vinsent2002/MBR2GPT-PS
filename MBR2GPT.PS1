$ScriptBody = @'
#Disable Windows Recovery Environment
reagentc.exe /enable

#Delete Drive Latter from System Reserved partition
$SysReservedPart = Get-Volume -FileSystemLabel "System Reserved" | Get-Partition
Remove-PartitionAccessPath -DiskNumber $SysReservedPart.DiskNumber -PartitionNumber $SysReservedPart.PartitionNumber -Accesspath "$($SysReservedPart.DriveLetter):\"

Remove-Item $PSCommandPath -Force
'@

$ScriptPath = "C:\MBR2GPT.PS1"
$BootDisk = (Get-Disk | Where { $_.IsBoot -eq $TRUE } ).Number

if ((Get-Bitlockervolume -MountPoint "C:").ProtectionStatus) {
Write-Warning "BitLocker is enabled!"
[Environment]::Exit(1)
}

mbr2gpt /validate /disk:$BootDisk /allowFullOS | Out-Null

if (!$LASTEXITCODE) {
    #Disable Windows Recovery Environment
    reagentc /disable

    mbr2gpt /convert /disk:$BootDisk /allowFullOS
    #Debug
    Write-Host "MBR2GPT Return Code:" $LASTEXITCODE

}

#Enable Windows Recovery Environment if conversion failed
If ($LASTEXITCODE) {
    reagentc /enable
}

#Swith to UEFI Boot Mode if MBR2GPT conversion completed successfully
if (!$LASTEXITCODE) {

    Add-Content -Path $ScriptPath -Value $ScriptBody

    #Adds hidden and system attribute for PowerShell script
    $script = Get-Item $ScriptPath
    $script.Attributes += 'System, Hidden'

    REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v MBR2GPT /t REG_SZ /d "powershell.exe -exec bypass -w hidden -file $ScriptPath" /f

    $Interface = Get-WmiObject -Namespace root\wmi -Class Lenovo_SetBiosSetting
    $SaveSettings = Get-WmiObject -Namespace root\wmi -Class Lenovo_SaveBiosSettings

    $Interface.SetBiosSetting("Secure Boot,Enabled")
    $Interface.SetBiosSetting("CSM,Disabled")
    $Interface.SetBiosSetting("Intel(R) Virtualization Technology,Enabled")
    $Interface.SetBiosSetting("VirtualizationTechnology,Enabled")
    $Interface.SetBiosSetting("VT-d,Enabled")
    $Interface.SetBiosSetting("VTdFeature,Enabled")
    $Interface.SetBiosSetting("Security Chip 2.0,Enabled")

    $SaveSettings.SaveBiosSettings()
}
