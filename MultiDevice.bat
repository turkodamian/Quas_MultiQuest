@echo off
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0Quas-MultiDevice.ps1"
pause
