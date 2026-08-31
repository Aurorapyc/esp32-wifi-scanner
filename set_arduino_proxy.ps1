# ============================================================
#  Configure Arduino IDE to download through your local proxy
#
#  What it does:
#   1. Tests 127.0.0.1:10808 and auto-detects whether it is
#      an HTTP or a SOCKS5 proxy (uses curl, built into Windows)
#   2. Checks that GitHub is reachable through the proxy
#   3. Writes network.proxy into Arduino's arduino-cli.yaml
#
#  Usage:
#    - Double-click set_proxy.bat, OR
#    - Right-click this file -> "Run with PowerShell"
#
#  After it finishes:
#    1. Fully close Arduino IDE
#    2. Reopen Arduino IDE
#    3. Boards Manager -> install "esp32 by Espressif Systems"
#
#  Tip: if your proxy uses a different port, change $port below.
# ============================================================

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$hostAddr = '127.0.0.1'
$port     = 10808

$githubProbe = 'https://github.com/'
$failUrl     = 'https://github.com/espressif/crosstool-NG/releases/download/esp-14.2.0_20260121/riscv32-esp-elf-14.2.0_20260121-x86_64-w64-mingw32.zip'

function Get-Code([string]$px, [string]$url) {
  try {
    $code = & curl.exe -s -o NUL -w "%{http_code}" --connect-timeout 8 --max-time 20 -x $px -I $url 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    return $code
  } catch { return '' }
}

Write-Host ""
Write-Host "=========================================="
Write-Host "  Arduino proxy setup (127.0.0.1:$port)"
Write-Host "=========================================="

# ---- 1. detect proxy type ----
$cHttp  = Get-Code "http://${hostAddr}:${port}"   $githubProbe
$cSocks = Get-Code "socks5://${hostAddr}:${port}" $githubProbe

$scheme = $null
if ($cHttp  -match '^\d{3}$') { $scheme = 'http' }
elseif ($cSocks -match '^\d{3}$') { $scheme = 'socks5' }

if (-not $scheme) {
  Write-Host "[!] Could not reach $hostAddr`:$port with http or socks5." -ForegroundColor Red
  Write-Host "    Possible reasons:" -ForegroundColor Yellow
  Write-Host "    - The proxy is not actually running" -ForegroundColor Yellow
  Write-Host "    - It is on a different port (edit `$port at the top of this script)" -ForegroundColor Yellow
  Write-Host "    - Windows built-in curl is unavailable" -ForegroundColor Yellow
  Read-Host "Press Enter to exit"
  exit 1
}
Write-Host "[1/3] Proxy detected: $scheme   (http test=$cHttp, socks5 test=$cSocks)" -ForegroundColor Green
$proxyUrl = "${scheme}://${hostAddr}:${port}"

# ---- 2. confirm the actual failing file is reachable ----
$c = Get-Code $proxyUrl $failUrl
if ($c -match '^\d{3}$') {
  Write-Host "[2/3] GitHub reachable through proxy (HTTP $c)." -ForegroundColor Green
} else {
  Write-Host "[2/3] Warning: GitHub not confirmed through proxy (got '$c')." -ForegroundColor Yellow
  Write-Host "      Will still write the config; you can retry inside Arduino." -ForegroundColor Yellow
}

# ---- 3. write network.proxy into arduino-cli.yaml ----
$dataDir = Join-Path $env:LOCALAPPDATA 'Arduino15'
if (-not (Test-Path $dataDir)) { $dataDir = Join-Path $env:APPDATA 'Arduino15' }
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
$cfgFile = Join-Path $dataDir 'arduino-cli.yaml'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$yaml = ''
if (Test-Path $cfgFile) { $yaml = [System.IO.File]::ReadAllText($cfgFile) }

# remove any existing proxy lines, then (re)insert under network:
$yaml = [regex]::Replace($yaml, '(?m)^[ \t]*proxy:[^\r\n]*(?:\r?\n)?', '')
$m = [regex]::Match($yaml, '(?m)^[ \t]*network:[^\r\n]*(?:\r?\n)?')
if ($m.Success) {
  $at = $m.Index + $m.Length
  $yaml = $yaml.Substring(0, $at) + "  proxy: $proxyUrl`r`n" + $yaml.Substring($at)
} else {
  $yaml = $yaml.TrimEnd() + "`r`nnetwork:`r`n  proxy: $proxyUrl`r`n"
}
[System.IO.File]::WriteAllText($cfgFile, $yaml, $utf8NoBom)
Write-Host "[3/3] Wrote proxy config:" -ForegroundColor Green
Write-Host "       file  : $cfgFile"
Write-Host "       proxy : $proxyUrl"

Write-Host ""
Write-Host "=========================================="
Write-Host "  Done! Next steps:"
Write-Host "  1. Fully close Arduino IDE"
Write-Host "  2. Reopen Arduino IDE"
Write-Host "  3. Boards Manager -> install esp32"
Write-Host "     (Tools -> Board -> Boards Manager -> search esp32)"
Write-Host ""
Write-Host "  If it still fails:"
Write-Host "  - Preferences -> Network -> Manual proxy -> $hostAddr`:$port"
Write-Host "  - Or re-run this script and watch the test output"
Write-Host "=========================================="
Read-Host "Press Enter to exit"
