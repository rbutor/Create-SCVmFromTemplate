$vmHost = "HostName.with.domain" 
$VmName = "VirtualMachineName"
$VMNetwork = "LogicalNetworlName"
$Template = "TemplateName"
$OperatingSystem = "Ubuntu Linux 20.04 (64 bit)"
$CPUCount = 4
$MemSize = 8192
$HA = $true
$staticIPv4Pool = "IPPull"
$VMPath = "C:\VMPath\"
$CompName = $VmName
$VMMServer = "VMMServer.with.domain"

$HWPJobGuid = [System.Guid]::NewGuid().ToString()
$CreVMJobGuid = [System.Guid]::NewGuid().ToString()

New-SCVirtualScsiAdapter -VMMServer $VMMServer -JobGroup $HWPJobGuid -AdapterID 7 -ShareVirtualScsiAdapter $false -ScsiControllerType DefaultTypeNoType 


New-SCVirtualDVDDrive -VMMServer $VMMServer -JobGroup $HWPJobGuid -Bus 0 -LUN 1 

$VMNetwork = Get-SCVMNetwork -VMMServer $VMMServer -Name $VMNetwork

New-SCVirtualNetworkAdapter -VMMServer $VMMServer -JobGroup $HWPJobGuid -MACAddress "00:00:00:00:00:00" -MACAddressType Static -VLanEnabled $false -Synthetic -EnableVMNetworkOptimization $false -EnableMACAddressSpoofing $false -EnableGuestIPNetworkVirtualizationUpdates $false -IPv4AddressType Static -IPv6AddressType Dynamic -VMNetwork $VMNetwork -DevicePropertiesAdapterNameMode Disabled 

#$CPUType = Get-SCCPUType -VMMServer $VMMServer | where {$_.Name -eq "3.60 GHz Xeon (2 MB L2 cache)"}   #-CPUType $CPUType

New-SCHardwareProfile -VMMServer $VMMServer -Name "Profile$HWPJobGuid" -Description "Profile used to create a VM/Template" -CPUCount $CPUCount -MemoryMB $MemSize -DynamicMemoryEnabled $false -MemoryWeight 5000 -CPUExpectedUtilizationPercent 20 -DiskIops 0 -CPUMaximumPercent 100 -CPUReserve 0 -NumaIsolationRequired $false -NetworkUtilizationMbps 0 -CPURelativeWeight 100 -HighlyAvailable $HA -HAVMPriority 2000 -DRProtectionRequired $false -SecureBootEnabled $false -CPULimitFunctionality $false -CPULimitForMigration $false -CheckpointType Production -Generation 2 -JobGroup $HWPJobGuid 



$Template = Get-SCVMTemplate -VMMServer $VMMServer | where {$_.Name -eq $Template}
$HardwareProfile = Get-SCHardwareProfile -VMMServer $VMMServer | where {$_.Name -eq "Profile$HWPJobGuid"}

$OperatingSystem = Get-SCOperatingSystem -VMMServer $VMMServer  | where {$_.Name -eq $OperatingSystem}

New-SCVMTemplate -Name "Temporary$CreVMJobGuid" -EnableNestedVirtualization $false -Template $Template -HardwareProfile $HardwareProfile -JobGroup $CreVMJobGuid -ComputerName $CompName -TimeZone 145  -LinuxDomainName "" -OperatingSystem $OperatingSystem -UpdateManagementProfile $null 



$template = Get-SCVMTemplate -All | where { $_.Name -eq "Temporary$CreVMJobGuid" }
$virtualMachineConfiguration = New-SCVMConfiguration -VMTemplate $template -Name $VmName
Write-Output $virtualMachineConfiguration
$vmHost = Get-SCVMHost -ComputerName $vmHost
Set-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration -VMHost $vmHost
Update-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration
Set-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration -VMLocation $VMPath -PinVMLocation $true

$AllNICConfigurations = Get-SCVirtualNetworkAdapterConfiguration -VMConfiguration $virtualMachineConfiguration

$NICConfiguration = Get-SCVirtualNetworkAdapterConfiguration -VMConfiguration $virtualMachineConfiguration #| where { $_.ID -eq "dd452978-00a0-4114-a0ef-559ef2cb1c97" }
if($NICConfiguration -eq $null) { $NICConfiguration = $AllNICConfigurations[0]
 }
$staticIPv4Pool = Get-SCStaticIPAddressPool -Name $staticIPv4Pool
Set-SCVirtualNetworkAdapterConfiguration -VirtualNetworkAdapterConfiguration $NICConfiguration -IPv4AddressPool $staticIPv4Pool -PinIPv4AddressPool $true -PinIPv6AddressPool $false -PinMACAddressPool $false
$VHDConfiguration = Get-SCVirtualHardDiskConfiguration -VMConfiguration $virtualMachineConfiguration
Set-SCVirtualHardDiskConfiguration -VHDConfiguration $VHDConfiguration -PinSourceLocation $false -PinDestinationLocation $false -PinFileName $false -StorageQoSPolicy $null -DeploymentOption "UseNetwork"



Update-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration
New-SCVirtualMachine -Name $VmName -VMConfiguration $virtualMachineConfiguration -Description "" -BlockDynamicOptimization $false -JobGroup "$CreVMJobGuid" -ReturnImmediately -StartAction "NeverAutoTurnOnVM" -StopAction "SaveVM"
#TestPush