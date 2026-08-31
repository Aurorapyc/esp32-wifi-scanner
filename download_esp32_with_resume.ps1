# ============================================================
#  Download all esp32 toolchain files with RESUME + RETRY
#
#  Why: Arduino's own installer gives up on the FIRST network
#  hiccup and throws "unexpected EOF", leaving a broken cache
#  file that makes the next attempt fail too.
#
#  This script downloads every file esp32 needs (platform zip +
#  all toolchains) using curl with:
#     -C -            resume from where it stopped (断点续传)
#     --retry ...     auto-retry on any failure
#     -x proxy        through your local HTTP proxy
#  It saves the files into Arduino's staging/packages folder.
#  Arduino then verifies the checksums and just unpacks them
#  instead of downloading again.
#
#  It auto-locates your Arduino data folder, finds (or, if
#  missing, downloads) the esp32 package index, and downloads
#  only the toolchains your esp32 version actually needs.
#
#  Usage: double-click download_esp32_with_resume.bat
# ============================================================

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$targetVersion = '3.3.11'   # change if your Arduino IDE shows a different version

# ---------- candidate Arduino data dirs ----------
$dirs = @(
  (Join-Path $env:LOCALAPPDATA 'Arduino15'),
  (Join-Path $env:APPDATA      'Arduino15'),
  (Join-Path $env:USERPROFILE  '.arduino15')
)

# ---------- detect the real data dir using markers ----------
$dataDir = $null
foreach ($marker in @('package_index.json', 'packages', 'package_esp32_index.json', 'arduino-cli.yaml')) {
  foreach ($d in $dirs) {
    if (Test-Path (Join-Path $d $marker)) { $dataDir = $d; break }
  }
  if ($dataDir) { break }
}
if (-not $dataDir) {
  foreach ($d in $dirs) { if (Test-Path $d) { $dataDir = $d; break } }
}
if (-not $dataDir) { $dataDir = $dirs[0] }
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null

# ---------- read proxy from arduino-cli.yaml ----------
$fallbackProxy = 'http://127.0.0.1:10808'
$proxy = $fallbackProxy
$cfgFile = Join-Path $dataDir 'arduino-cli.yaml'
if (Test-Path $cfgFile) {
  $yaml = Get-Content $cfgFile -Raw -ErrorAction SilentlyContinue
  $m = [regex]::Match($yaml, '(?m)^[ \t]*proxy:[ \t]*(\S+)')
  if ($m.Success -and $m.Groups[1].Value.Trim()) { $proxy = $m.Groups[1].Value.Trim() }
}

Write-Host ""
Write-Host "=========================================="
Write-Host "  esp32 toolchain download (resume+retry)"
Write-Host "  Arduino data dir : $dataDir"
Write-Host "  proxy            : $proxy"
Write-Host "=========================================="

# ---------- report what exists in each candidate dir ----------
foreach ($d in $dirs) {
  if (Test-Path $d) {
    $hasIdx = Test-Path (Join-Path $d 'package_index.json')
    $hasEsp = Test-Path (Join-Path $d 'package_esp32_index.json')
    $hasPkg = Test-Path (Join-Path $d 'packages')
    Write-Host ("  [present] {0}  (defaultIndex={1}, esp32Index={2}, packages={3})" -f $d, $hasIdx, $hasEsp, $hasPkg)
  } else {
    Write-Host "  [absent ] $d"
  }
}

# ---------- locate the esp32 package index ----------
$indexFile = $null
foreach ($d in $dirs) {
  $c = Join-Path $d 'package_esp32_index.json'
  if (Test-Path $c) { $indexFile = $c; break }
}
if (-not $indexFile) {
  $found = Get-ChildItem $dirs -Filter 'package_*esp32*.json' -Recurse -ErrorAction SilentlyContinue |
           Where-Object { $_.Length -gt 1000 } | Select-Object -First 1
  if ($found) { $indexFile = $found.FullName }
}
if (-not $indexFile) {
  Write-Host "esp32 index not found locally; downloading it via proxy ..." -ForegroundColor Yellow
  $indexFile = Join-Path $dataDir 'package_esp32_index.json'
  & curl.exe -sS -L --connect-timeout 15 --retry 10 --retry-all-errors -x $proxy -o $indexFile `
    'https://espressif.github.io/arduino-esp32/package_esp32_index.json' 2>$null
  if (-not (Test-Path $indexFile) -or (Get-Item $indexFile).Length -lt 1000) {
    Write-Host "[!] Could not locate or download the esp32 index." -ForegroundColor Red
    Write-Host "    Checked:" -ForegroundColor Yellow
    foreach ($d in $dirs) { Write-Host "      $(Join-Path $d 'package_esp32_index.json')" -ForegroundColor Yellow }
    Read-Host "Press Enter to exit"
    exit 1
  }
  Write-Host "  downloaded index -> $indexFile" -ForegroundColor Green
}
Write-Host "  index            : $indexFile"

$stagingPkg = Join-Path $dataDir 'staging\packages'
New-Item -ItemType Directory -Path $stagingPkg -Force | Out-Null

# ---------- parse index (note: structure is packages[].platforms/tools) ----------
$idx = [System.IO.File]::ReadAllText($indexFile) | ConvertFrom-Json

$pkg = $null
if ($idx.packages) { $pkg = $idx.packages | Where-Object { $_.name -eq 'esp32' } | Select-Object -First 1 }
if (-not $pkg) {
  Write-Host "[!] The index does not contain an 'esp32' package." -ForegroundColor Red
  Write-Host "    The downloaded file may be an error page from the proxy." -ForegroundColor Yellow
  Write-Host "    File: $indexFile" -ForegroundColor Yellow
  Read-Host "Press Enter to exit"
  exit 1
}

# pick platform version: requested, else latest
$plat = $null
$esp32Plats = @($pkg.platforms)
$plat = $esp32Plats | Where-Object { $_.version -eq $targetVersion } | Select-Object -First 1
if (-not $plat) {
  $esp32Plats = $esp32Plats | Sort-Object { [version]$_.version } -Descending
  $plat = $esp32Plats | Select-Object -First 1
  if ($plat) {
    Write-Host "  Note: requested $targetVersion not found; using latest esp32 $($plat.version)" -ForegroundColor Yellow
    Write-Host "        -> In Arduino IDE, install esp32 version $($plat.version)" -ForegroundColor Yellow
  }
}
if (-not $plat) {
  Write-Host "[!] No esp32 platform found in the index." -ForegroundColor Red
  Read-Host "Press Enter to exit"
  exit 1
}
$installedVersion = $plat.version
Write-Host "  target esp32    : $installedVersion"

function Get-File([string]$url, [string]$dest, [string]$expectedSha, [string]$label) {
  Write-Host ""
  Write-Host ("[{0}] {1}" -f $label, $url) -ForegroundColor Cyan

  if (Test-Path $dest) {
    $h = (Get-FileHash $dest -Algorithm SHA256).Hash.ToLower()
    if ($expectedSha -ne '' -and $h -eq $expectedSha) {
      Write-Host "  already complete, skipping." -ForegroundColor Green
      return $true
    } else {
      Write-Host "  stale/corrupt cached file, deleting..." -ForegroundColor Yellow
      Remove-Item $dest -Force -ErrorAction SilentlyContinue
    }
  }

  for ($try = 1; $try -le 8; $try++) {
    Write-Host "  try $try ..." -ForegroundColor DarkCyan
    & curl.exe -sS -L --connect-timeout 15 --retry 25 --retry-all-errors --retry-delay 3 -C - -x $proxy -o $dest $url 2>$null
    $code = $LASTEXITCODE
    if ($code -ne 0) { Write-Host "  curl exit=$code (will resume/retry)" -ForegroundColor Yellow; continue }
    if (Test-Path $dest) {
      if ($expectedSha -eq '') { Write-Host "  done (no checksum to verify)." -ForegroundColor Green; return $true }
      $h = (Get-FileHash $dest -Algorithm SHA256).Hash.ToLower()
      if ($h -eq $expectedSha) { Write-Host "  done, checksum OK." -ForegroundColor Green; return $true }
      Write-Host "  checksum MISMATCH, deleting and retrying..." -ForegroundColor Red
      Remove-Item $dest -Force -ErrorAction SilentlyContinue
    }
  }
  Write-Host "  FAILED after many attempts." -ForegroundColor Red
  return $false
}

$allOk = $true

# ---------- 1. platform archive ----------
$dest = Join-Path $stagingPkg $plat.archiveFileName
$sha = ($plat.checksum -replace '^SHA-256:', '').ToLower()
if (-not (Get-File $plat.url $dest $sha 'platform')) { $allOk = $false }

# ---------- 2. only the tools this version depends on ----------
$need = @{}
foreach ($dep in $plat.toolDependencies) { $need["$($dep.name)|$($dep.version)"] = $true }

foreach ($tool in $pkg.tools) {
  $key = "$($tool.name)|$($tool.version)"
  if (-not $need.ContainsKey($key)) { Write-Host "  skip $key (not used by esp32 $installedVersion)" -ForegroundColor DarkGray; continue }

  $sys = $null
  foreach ($s in $tool.systems) {
    $h = $s.host
    if ($h -like '*x86_64*' -and ($h -like '*mingw32*' -or $h -like '*windows*')) { $sys = $s; break }
  }
  if (-not $sys) {
    if ($tool.systems.Count -eq 1) { $sys = $tool.systems[0] }
    else { foreach ($s in $tool.systems) { if ($s.host -eq '*' -or $s.host -eq '') { $sys = $s; break } } }
  }
  if (-not $sys) { Write-Host "  No Windows-x64 build for $key, skipping." -ForegroundColor DarkGray; continue }

  $dest = Join-Path $stagingPkg $sys.archiveFileName
  $sha = ($sys.checksum -replace '^SHA-256:', '').ToLower()
  if (-not (Get-File $sys.url $dest $sha "tool: $($tool.name) v$($tool.version)")) { $allOk = $false }
}

Write-Host ""
Write-Host "=========================================="
if ($allOk) {
  Write-Host "  All files downloaded & verified into:" -ForegroundColor Green
  Write-Host "    $stagingPkg" -ForegroundColor Green
  Write-Host ""
  Write-Host "  Next steps:" -ForegroundColor Green
  Write-Host "  1. Fully close Arduino IDE" -ForegroundColor Green
  Write-Host "  2. Reopen Arduino IDE" -ForegroundColor Green
  Write-Host "  3. Boards Manager -> install esp32 version $installedVersion" -ForegroundColor Green
  Write-Host "     (it will unpack the files, no more downloading)" -ForegroundColor Green
} else {
  Write-Host "  Some files failed. Re-run this script to RESUME them." -ForegroundColor Red
  Write-Host "  If a file keeps failing, your proxy is dropping large transfers -" -ForegroundColor Yellow
  Write-Host "  run 'run_fix.bat' to switch to a GitHub mirror instead." -ForegroundColor Yellow
}
Write-Host "=========================================="
Read-Host "Press Enter to exit"
