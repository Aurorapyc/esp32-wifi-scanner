@echo off
chcp 65001 >nul
echo.
echo Downloading esp32 toolchain with resume support (may take a while) ...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0download_esp32_with_resume.ps1"
