# ============================================================
#  ESP32 board package download fix (GitHub mirror for CN users)
#
#  What it does: rewrites every  "url": "https://github.com/..."
#  inside Arduino's esp32 package index so that tool downloads
#  go through a GitHub proxy mirror that is reachable from China.
#
#  Usage:
#    - Double-click run_fix.bat, OR
#    - Right-click this file -> "Run with PowerShell"
#
#  After it finishes:
#    1. Fully close Arduino IDE
#    2. Reopen Arduino IDE
#    3. Boards Manager -> reinstall "esp32 by Espressif Systems"
# ============================================================

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "=========================================="
Write-Host "  ESP32 package download fix"
Write-Host "=========================================="

# ---- 1. locate the esp32 package index ----
$candidates = @(
  (Join-Path $env:LOCALAPPDATA 'Arduino15\package_esp32_index.json'),  # Arduino IDE 2.x
  (Join-Path $env:APPDATA      'Arduino15\package_esp32_index.json')   # Arduino IDE 1.8.x
)
$indexFile = $null
foreach ($c in $candidates) { if (Test-Path $c) { $indexFile = $c; break } }
if (-not $indexFile) {
  Write-Host "[!] package_esp32_index.json not found." -ForegroundColor Red
  Write-Host ""
  Write-Host "    Please first add this URL in Arduino IDE:"
  Write-Host "      File -> Preferences -> Additional boards manager URLs:"
  Write-Host "      https://espressif.github.io/arduino-esp32/package_esp32_index.json"
  Write-Host "    Then open Boards Manager so the esp32 entry appears,"
  Write-Host "    and run this script again."
  Read-Host "Press Enter to exit"
  exit 1
}
Write-Host "[1/4] Index found:" -NoNewline
Write-Host " $indexFile" -ForegroundColor Cyan

# ---- 2. backup ----
$backup = "$indexFile.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
Copy-Item $indexFile $backup -Force
Write-Host "[2/4] Backup saved:" -NoNewline
Write-Host " $backup" -ForegroundColor Cyan

# ---- 3. check if there is still anything to replace ----
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$content = [System.IO.File]::ReadAllText($indexFile)
$pattern = '(?<="url"\s*:\s*")https://github\.com/'
if (-not [regex]::IsMatch($content, $pattern)) {
  Write-Host "[i] No github.com download URLs remain (already fixed?)." -ForegroundColor Yellow
  Write-Host "    Reopen Arduino IDE and install esp32 from Boards Manager."
  Read-Host "Press Enter to exit"
  exit 0
}

# ---- 4. pick a working mirror ----
$mirrors = @(
  'https://ghfast.top/',
  'https://gh-proxy.com/',
  'https://ghproxy.net/',
  'https://ghproxy.homeboyc.cn/'
)
$testUrl = 'https://github.com/espressif/crosstool-NG/releases/download/esp-14.2.0_20260121/riscv32-esp-elf-14.2.0_20260121-x86_64-w64-mingw32.zip'
$chosen = $null
foreach ($m in $mirrors) {
  Write-Host -NoNewline "    testing $m ... "
  try {
    $resp = Invoke-WebRequest -Uri ($m + $testUrl) -Method Head -TimeoutSec 8 -UseBasicParsing
    if ($resp.StatusCode -lt 500) { Write-Host "OK" -ForegroundColor Green; $chosen = $m; break }
  } catch { }
  Write-Host "unreachable"
}
if (-not $chosen) {
  $chosen = $mirrors[0]
  Write-Host "[!] No mirror responded. Will still try $chosen ." -ForegroundColor Yellow
}
Write-Host "[3/4] Using mirror:" -NoNewline
Write-Host " $chosen" -ForegroundColor Green

# ---- 5. rewrite and save ----
$replacement = $chosen + 'https://github.com/'
$newContent = [regex]::Replace($content, $pattern, $replacement)
[System.IO.File]::WriteAllText($indexFile, $newContent, $utf8NoBom)
Write-Host "[4/4] Download URLs now go through the mirror." -ForegroundColor Green

Write-Host ""
Write-Host "=========================================="
Write-Host "  Done! Next steps:"
Write-Host "  1. Fully close Arduino IDE"
Write-Host "  2. Reopen Arduino IDE"
Write-Host "  3. Boards Manager -> reinstall esp32"
Write-Host "     (Tools -> Board -> Boards Manager -> search esp32)"
Write-Host ""
Write-Host "  Still failing?"
Write-Host "  - Network hiccup: just retry the install"
Write-Host "  - Re-run this script to pick another mirror"
Write-Host "  - Restore original: copy the backup file back, e.g."
Write-Host "    Copy-Item '$backup' '$indexFile' -Force"
Write-Host "=========================================="
Read-Host "Press Enter to exit"
