# ============================================================
#  Fix "Download failed: unexpected EOF" when installing esp32
#
#  "unexpected EOF" = a download got cut off halfway, leaving a
#  broken partial file in the cache. Arduino then keeps reusing
#  that broken file, so it fails again and again.
#
#  What this script does:
#   1. Clears Arduino's download cache (staging folder)
#   2. Checks free disk space
#   3. Detects which download path you are currently using
#      (your local proxy  vs  GitHub mirror) and whether the
#      package index still points at github.com
#   4. Quick-tests connectivity and prints the recommended path
#
#  Usage:
#    - Double-click run_fix_eof.bat, OR
#    - Right-click this file -> "Run with PowerShell"
#
#  After it finishes: reopen Arduino IDE and retry the install.
# ============================================================

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Test-Code([string]$proxyArg, [string]$url) {
  try {
    if ($proxyArg) {
      $c = & curl.exe -s -o NUL -w "%{http_code}" --connect-timeout 8 --max-time 20 -x $proxyArg -I $url 2>$null
    } else {
      $c = & curl.exe -s -o NUL -w "%{http_code}" --connect-timeout 8 --max-time 20 -I $url 2>$null
    }
    if ($LASTEXITCODE -ne 0) { return '' }
    return $c
  } catch { return '' }
}

Write-Host ""
Write-Host "=========================================="
Write-Host "  Fix 'unexpected EOF' download error"
Write-Host "=========================================="

# ---- 1. locate Arduino data dir (check both possible locations) ----
$localDir   = Join-Path $env:LOCALAPPDATA 'Arduino15'
$roamingDir = Join-Path $env:APPDATA      'Arduino15'
$dataDir = $null
foreach ($d in @($localDir, $roamingDir)) {
  if (Test-Path (Join-Path $d 'packages')) { $dataDir = $d; break }
}
if (-not $dataDir) {
  foreach ($d in @($localDir, $roamingDir)) { if (Test-Path $d) { $dataDir = $d; break } }
}
if (-not $dataDir) { $dataDir = $localDir }
Write-Host "[1/5] Arduino data dir: $dataDir"

# ---- 2. clear staging (broken partial downloads) ----
$staging = Join-Path $dataDir 'staging'
$before = 0
if (Test-Path $staging) {
  $before = (Get-ChildItem $staging -Recurse -Force -ErrorAction SilentlyContinue |
             Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
  Get-ChildItem $staging -Recurse -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
$mb = [math]::Round($before / 1MB, 1)
Write-Host "[2/5] Cleared download cache in staging ($mb MB removed)." -ForegroundColor Green

# ---- 3. check disk space ----
$drive = [System.IO.Path]::GetPathRoot($dataDir)
$free = (Get-PSDrive -Name ($drive.TrimEnd('\')) -ErrorAction SilentlyContinue).Free
if ($null -eq $free) {
  $free = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive'" -ErrorAction SilentlyContinue).FreeSpace
}
if ($null -ne $free) {
  $freeGb = [math]::Round($free / 1GB, 1)
  if ($freeGb -lt 5) {
    Write-Host "[3/5] WARNING: only ${freeGb} GB free on $drive . esp32 toolchain needs ~2-4 GB." -ForegroundColor Red
  } else {
    Write-Host "[3/5] Free space on $drive : ${freeGb} GB (OK)." -ForegroundColor Green
  }
} else {
  Write-Host "[3/5] Could not read free disk space." -ForegroundColor Yellow
}

# ---- 4. diagnose current path (proxy vs mirror) ----
$cfgFile  = Join-Path $dataDir 'arduino-cli.yaml'
$idxFile  = Join-Path $dataDir 'package_esp32_index.json'

$proxy = ''
if (Test-Path $cfgFile) {
  $yaml = Get-Content $cfgFile -Raw -ErrorAction SilentlyContinue
  $m = [regex]::Match($yaml, '(?m)^[ \t]*proxy:[ \t]*(\S+)')
  if ($m.Success) { $proxy = $m.Groups[1].Value.Trim() }
}

$mirrorPrefixes = @('gh-proxy.com','ghfast.top','ghproxy.net','ghproxy.homeboyc.cn','github.akams.cn','ghproxy')
$indexHasMirror = $false
if (Test-Path $idxFile) {
  $idx = Get-Content $idxFile -Raw -ErrorAction SilentlyContinue
  foreach ($p in $mirrorPrefixes) {
    if ($idx -match [regex]::Escape($p)) { $indexHasMirror = $true; break }
  }
}

Write-Host "[4/5] Current setup:"
Write-Host "       proxy  in arduino-cli.yaml : $(if ($proxy) { $proxy } else { '(none)' })"
Write-Host "       mirror in package index     : $(if ($indexHasMirror) { 'YES (github.com URLs were rewritten)' } else { 'no (URLs point at github.com)' })"

# ---- 5. connectivity quick tests ----
Write-Host "[5/5] Connectivity quick test..."
$ghProbe = 'https://github.com/'
$testUrl = 'https://github.com/espressif/crosstool-NG/releases/download/esp-14.2.0_20260121/riscv32-esp-elf-14.2.0_20260121-x86_64-w64-mingw32.zip'

$proxyOk = $false
if ($proxy) {
  $c = Test-Code $proxy $ghProbe
  $proxyOk = ($c -match '^\d{3}$')
  Write-Host "       github.com via proxy $proxy : $(if ($proxyOk) { "HTTP $c OK" } else { 'unreachable' })"
}
$mirrorOk = $false
foreach ($m in @('https://ghfast.top/','https://gh-proxy.com/')) {
  $c = Test-Code "" ($m + $testUrl)
  if ($c -match '^\d{3}$') { $mirrorOk = $true; Write-Host "       mirror $m : HTTP $c OK"; break }
  else { Write-Host "       mirror $m : unreachable" }
}

Write-Host ""
Write-Host "=========================================="
Write-Host "  Recommendation"
Write-Host "=========================================="
if ($proxyOk) {
  if ($indexHasMirror) {
    Write-Host "  You have a working proxy AND mirror-rewritten URLs."
    Write-Host "  -> Prefer the proxy: restore the original index first."
    Write-Host "     Restore file:"
    Write-Host "       Copy-Item (Get-ChildItem '$dataDir\package_esp32_index.json.bak_*' | Select-Object -Last 1).FullName '$idxFile' -Force"
    Write-Host "  Then retry install in Arduino IDE (with proxy on)."
  } else {
    Write-Host "  Proxy works and URLs point at github.com. "
    Write-Host "  -> Just retry the install in Arduino IDE now."
  }
} elseif ($mirrorOk) {
  Write-Host "  Proxy is down but a GitHub mirror works."
  Write-Host "  -> Use the mirror path: run 'run_fix.bat' (rewrites URLs to mirror),"
  Write-Host "     or open Preferences->Network and disable the proxy."
} else {
  Write-Host "  Neither the proxy nor mirrors are reachable right now."
  Write-Host "  -> Check the proxy is running, then re-run this script."
}
Write-Host ""
Write-Host "  Tips:"
Write-Host "  - 'unexpected EOF' usually clears after the cache wipe above + a retry."
Write-Host "  - If the SAME file keeps EOF-ing every time, the proxy is dropping"
Write-Host "    large downloads -> switch to a mirror (run_fix.bat), or vice versa."
Write-Host "  - Keep proxy ON for the whole install; it downloads several GB."
Write-Host "=========================================="
Read-Host "Press Enter to exit"
