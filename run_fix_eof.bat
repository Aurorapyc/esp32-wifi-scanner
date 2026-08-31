@echo off
chcp 65001 >nul
echo.
echo Cleaning download cache and checking your network path ...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix_eof_download.ps1"
