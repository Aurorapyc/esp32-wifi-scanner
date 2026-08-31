@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
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
  echo.
  pause
  exit /b 1
)

if not exist ".git" (
  echo [1/6] Initializing git repository ^(branch: main^)...
  git init -b main >nul
) else (
  echo [1/6] Git repository already exists.
)

echo [2/6] Setting author...
git config user.name "Eiralan"
git config user.email "2954564954@qq.com"

echo [3/6] Staging all files...
git add . >nul

echo [4/6] Creating initial commit...
git commit -m "feat: add ESP32 WiFi scanner 0.1.0" >nul 2>&1

echo [5/6] Setting remote origin...
git remote remove origin 2>nul
set "REPO_URL="
set /p REPO_URL=  Enter repo URL (git@github.com:... or https://...):
if "!REPO_URL!"=="" (
  echo [ERROR] No URL entered.
  echo.
  pause
  exit /b 1
)
git remote add origin "!REPO_URL!"

echo [6/6] Pushing to origin main...
git branch -M main
git push -u origin main
if not errorlevel 1 goto success

echo.
echo ==========================================
echo   Push FAILED.
echo ==========================================

echo "!REPO_URL!" | findstr /i "git@" >nul
if errorlevel 1 goto notssh

echo.
echo   You are using an SSH URL. If push failed, check:
echo.
echo   1. Verify the SSH key is registered on GitHub:
echo        ssh -T git@github.com
echo      The first time it asks about a host key, type "yes".
echo      You should see a welcome message with your GitHub name.
echo.
echo   2. If it times out, port 22 may be blocked by the network.
echo      Switch to SSH over port 443. Create the file
echo      %USERPROFILE%\.ssh\config with:
echo        Host github.com
echo          HostName ssh.github.com
echo          Port 443
echo          User git
echo.
echo   3. Make sure the repo exists on GitHub:
echo      !REPO_URL!
echo.
goto endfail

:notssh
echo.
echo   Push over HTTPS also failed. Possible causes:
echo   - The repo does not exist on GitHub yet, or the URL is wrong.
echo   - If you were asked for a password, use a Personal Access
echo     Token, NOT your GitHub password. Create one at:
echo     GitHub - Settings - Developer settings
echo     - Personal access tokens - Tokens ^(classic^) - Generate
echo     ^(scope: repo^)
echo   - If the remote repo already has files, create an EMPTY repo,
echo     or run:  git pull --rebase origin main

:endfail
echo.
pause
exit /b 1

:success
echo.
echo ==========================================
echo   Push succeeded.
echo   Refresh your GitHub repository page to see the files.
echo ==========================================
echo.
pause
