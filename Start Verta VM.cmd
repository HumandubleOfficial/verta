@echo off
:: Double-click to start the Verta test VM (Hyper-V "Verta-Test") and open its window.
:: Hyper-V needs administrator rights, so Windows asks for permission first.

net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$vm = Get-VM -Name 'Verta-Test' -ErrorAction Stop;" ^
  "if ($vm.State -ne 'Running') { Write-Host 'Starting Verta-Test...'; Start-VM -Name 'Verta-Test' -ErrorAction Stop }" ^
  "else { Write-Host 'Verta-Test is already running.' };" ^
  "Start-Process vmconnect.exe -ArgumentList 'localhost','Verta-Test'"

if errorlevel 1 (
    echo.
    echo Couldn't start the VM. The message above says why.
    pause
)
