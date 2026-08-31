@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo.
echo ==========================================
echo   ESP32 WiFi Scanner - Git push helper
echo ==========================================
echo.

where git >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Git is not installed.
  echo   Install it from https://git-scm.com/download/win
  echo   then run this script again.
  echo.
  pause
  exit /b 1
)

if not exist ".git" (
  echo [1/6] Initializing git repository ^(branch: main^)...
  git init -b main
) else (
  echo [1/6] Git repository already exists.
)

echo [2/6] Setting author...
git config user.name "Eiralan"
git config user.email "2954564954@qq.com"

echo [3/6] Staging all files...
git add .

echo [4/6] Creating initial commit...
git commit -m "feat: add ESP32 WiFi scanner 0.1.0"

echo [5/6] Setting remote origin...
git remote remove origin 2>nul
set "REPO_URL="
set /p REPO_URL=  Enter GitHub repository URL (e.g. https://github.com/Eiralan/esp32-wifi-scanner.git):
if "%REPO_URL%"=="" (
  echo [ERROR] No URL entered.
  echo.
  pause
  exit /b 1
)
git remote add origin "%REPO_URL%"

echo [6/6] Pushing to origin main...
git branch -M main
git push -u origin main

echo.
echo ==========================================
if errorlevel 1 (
  echo   Push FAILED. Check the error above.
  echo   Tips:
  echo   - The GitHub repo must be created and EMPTY first.
  echo   - If asked for a password, use a Personal Access Token,
  echo     NOT your GitHub password.
) else (
  echo   Push succeeded.
  echo   Refresh your GitHub repository page to see the files.
)
echo ==========================================
echo.
pause
