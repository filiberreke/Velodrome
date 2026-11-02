@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Initialize-Config.ps1"
if errorlevel 1 (
    echo Configuratie kon niet worden voorbereid. Controleer of deze map schrijfbaar is.
    pause
    exit /b 1
)
start "" /D "%~dp0" "%~dp0Velodrome.exe" %*
