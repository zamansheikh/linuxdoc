@echo off

:: Developer credits
echo =============================================
echo       Dev: Md Shamsuzzaman (Zaman Sheikh)
echo       Git: github.com/zamansheikh
echo =============================================

echo Checking PowerShell Execution Policy...
:: Check the current execution policy
powershell -Command "& {if ((Get-ExecutionPolicy) -eq 'Restricted') {Set-ExecutionPolicy Bypass -Scope Process -Force}}"

echo Ensuring Execution Policy is set to Bypass...
powershell -Command "& {if ((Get-ExecutionPolicy) -eq 'Restricted') {Write-Host 'Failed to set Execution Policy. Please run this script as Administrator.'; exit /b 1}}"

:: Install Chocolatey
echo Installing Chocolatey...
powershell -Command "& {Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))}"

:: Verify Chocolatey installation
choco --version >nul 2>&1
if %errorlevel% equ 0 (
    echo Chocolatey installed successfully.
) else (
    echo Chocolatey installation failed. Please check your system and try again.
)

echo Script execution completed.
pause
