@echo off
cd /d "%~dp0"
where py >nul 2>&1
if errorlevel 1 (
    python tools\virtual_bridge_ui.py
) else (
    py -3 tools\virtual_bridge_ui.py
)
if errorlevel 1 pause
