@echo off
chcp 65001 >nul
echo.
echo Configuring Arduino to use your local proxy ...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0set_arduino_proxy.ps1"
