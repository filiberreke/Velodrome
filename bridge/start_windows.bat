@echo off
setlocal
cd /d "%~dp0"
py -3.12 --version >nul 2>nul
if errorlevel 1 (
    echo Python 3.12 niet gevonden. Installeer Python 3.12 en probeer opnieuw.
    pause
    exit /b 1
)
if not exist ".venv\Scripts\python.exe" (
    py -3.12 -m venv ".venv"
    if errorlevel 1 goto failed
)
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check --only-binary=:all: -r requirements.txt
if errorlevel 1 goto failed

echo.
echo VELODROME 250 BRIDGE v0.15 - KICKR + Zwift Ride + Garmin ANT+ hartslag
echo Zet eerst de LINKER Zwift Ride aan, pas daarna de rechter.
echo Garmin vivoactive 5: Broadcast Heart Rate aanzetten.
echo Sluit oude bridges, ANT+ tests, Garmin Express en andere trainerapps.
echo De oorspronkelijke Dynastream USB-driver blijft ongewijzigd.
echo Start Godot apart. Deze bridge biedt SIM, ERG en HR in EEN venster.
echo.
".venv\Scripts\python.exe" -u bridge.py %*

:failed
echo.
echo Bridge afgesloten. Controleer eventuele foutmeldingen hierboven.
pause
endlocal
