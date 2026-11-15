#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Create (or recreate) a Hyper-V test VM that boots the newest Verta ISO.

.EXAMPLE
  # From an administrator PowerShell in the Verta folder:
  powershell -ExecutionPolicy Bypass -File .\scripts\new-test-vm.ps1
  powershell -ExecutionPolicy Bypass -File .\scripts\new-test-vm.ps1 -Replace   # delete and recreate
#>
param(
    [string]$Flavor   = 'verta',
    [string]$Name     = 'Verta-Test',
    [int]   $MemoryGB = 8,
    [int]   $DiskGB   = 64,
    [int]   $CPUs     = 4,
    [switch]$Replace
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

# Newest ISO for this flavor ("verta-YYYYMMDD[-HHMM].iso", not "verta-nvidia-...").
$iso = Get-ChildItem (Join-Path $root 'output') -Filter '*.iso' |
    Where-Object { $_.Name -match "^$([regex]::Escape($Flavor))-\d{8}(-\d{4})?\.iso$" } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $iso) { throw "No $Flavor-YYYYMMDD.iso in $root\output. Run scripts/build-iso.sh $Flavor first." }
Write-Host "ISO: $($iso.FullName)"

$host_ = Get-VMHost
$vhd   = Join-Path $host_.VirtualHardDiskPath "$Name.vhdx"

$existing = Get-VM -Name $Name -ErrorAction SilentlyContinue
if ($existing) {
    if (-not $Replace) { throw "VM '$Name' already exists. Re-run with -Replace to delete and recreate it." }
    Write-Host "Removing existing VM '$Name'"
    if ($existing.State -ne 'Off') { Stop-VM -Name $Name -TurnOff -Force }
    Remove-VM -Name $Name -Force
}
if (Test-Path $vhd) { Remove-Item $vhd -Force }

$switch = Get-VMSwitch -Name 'Default Switch' -ErrorAction SilentlyContinue
if (-not $switch) { $switch = Get-VMSwitch | Select-Object -First 1 }
if (-not $switch) { throw "No Hyper-V virtual switch found (the 'Default Switch' normally appears after a reboot once Hyper-V is enabled)." }

New-VM -Name $Name -Generation 2 `
    -MemoryStartupBytes ([int64]$MemoryGB * 1GB) `
    -NewVHDPath $vhd -NewVHDSizeBytes ([int64]$DiskGB * 1GB) `
    -SwitchName $switch.Name | Out-Null

Set-VMMemory    -VMName $Name -DynamicMemoryEnabled $false
Set-VMProcessor -VMName $Name -Count $CPUs
Set-VM          -Name   $Name -AutomaticCheckpointsEnabled $false
# Fedora's bootloader is signed by Microsoft's third-party UEFI CA.
Set-VMFirmware  -VMName $Name -EnableSecureBoot On -SecureBootTemplate MicrosoftUEFICertificateAuthority

$dvd = Add-VMDvdDrive -VMName $Name -Path $iso.FullName -Passthru
Set-VMFirmware -VMName $Name -FirstBootDevice $dvd

Start-VM -Name $Name
Write-Host "VM '$Name' started ($CPUs CPUs, $MemoryGB GB RAM, $DiskGB GB disk, switch '$($switch.Name)')."
Start-Process vmconnect.exe -ArgumentList 'localhost', $Name
