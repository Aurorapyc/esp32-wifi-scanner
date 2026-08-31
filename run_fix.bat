@echo off
chcp 65001 >nul
echo.
echo Running ESP32 download fix ...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix_esp32_download.ps1"
