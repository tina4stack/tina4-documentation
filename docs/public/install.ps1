# Tina4 CLI installer for Windows
# Usage: irm https://raw.githubusercontent.com/tina4stack/tina4/main/install.ps1 | iex
$ErrorActionPreference = "Stop"

$repo = "tina4stack/tina4"
$binary = "tina4-windows-amd64.exe"
$installDir = "$env:LOCALAPPDATA\tina4"

Write-Host ""
Write-Host "  Tina4 CLI Installer" -ForegroundColor Cyan
Write-Host "  ===================" -ForegroundColor Cyan

# Get latest release
$release = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest"
$tag = $release.tag_name
$asset = $release.assets | Where-Object { $_.name -eq $binary }

if (-not $asset) {
    Write-Error "Could not find $binary in release $tag"
    exit 1
}

Write-Host "  Version:    $tag"
Write-Host "  Install to: $installDir\tina4.exe"
Write-Host ""

# Create install directory
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# Download
$dest = "$installDir\tina4.exe"
Write-Host "Downloading $binary..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest

# Verify integrity against the release SHA256SUMS before trusting the binary.
# Releases from 3.8.53 publish SHA256SUMS; verify strictly when present, and
# warn + continue for older releases that predate it.
# (Keep all output ASCII-only - see the cp1252 note further down.)
$sumsAsset = $release.assets | Where-Object { $_.name -eq "SHA256SUMS" }
if ($sumsAsset) {
    # GitHub serves release assets as application/octet-stream, so
    # Invoke-WebRequest returns .Content as a byte[] (NOT a string). Splitting a
    # byte[] on "`n" yields per-byte garbage, the regex never matches, and every
    # lookup wrongly reports "is not listed". Decode to UTF-8 text first. (Guard
    # the type so a future string response still works.)
    $sumsRaw = (Invoke-WebRequest -Uri $sumsAsset.browser_download_url -UseBasicParsing).Content
    $sums = if ($sumsRaw -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($sumsRaw) } else { $sumsRaw }
    $line = $sums -split "`n" | Where-Object { $_ -match "\s\*?$([regex]::Escape($binary))\s*$" } | Select-Object -First 1
    if (-not $line) {
        Remove-Item $dest -Force
        Write-Error "$binary is not listed in SHA256SUMS for $tag"
        exit 1
    }
    $expected = (($line -split '\s+')[0]).ToLower()
    $actual = (Get-FileHash $dest -Algorithm SHA256).Hash.ToLower()
    if ($expected -ne $actual) {
        Remove-Item $dest -Force
        Write-Host ""
        Write-Host "  Error: checksum mismatch for $binary - refusing to install" -ForegroundColor Red
        Write-Host "    expected: $expected" -ForegroundColor Red
        Write-Host "    actual:   $actual" -ForegroundColor Red
        exit 1
    }
    Write-Host "Checksum verified (sha256)." -ForegroundColor Green
} else {
    Write-Host "Note: no SHA256SUMS published for $tag - skipping integrity check (older release)." -ForegroundColor Yellow
}

# Put the install dir FIRST on the user PATH so a fresh install always wins
# over a stale tina4.exe sitting earlier on PATH (e.g. an old copy dropped in a
# Ruby / MSYS / Scoop bin dir by a previous install or `tina4 update`). Just
# appending left the old binary shadowing the new one -- `tina4 --version` kept
# reporting the old version and `tina4 setup` ran old code.
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$parts = @()
if ($userPath) { $parts = $userPath -split ';' | Where-Object { $_ -and $_ -ne $installDir } }
$newUserPath = (@($installDir) + $parts) -join ';'
[Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
$env:Path = "$installDir;$env:Path"
Write-Host "Put $installDir first on PATH"

# A tina4.exe in a MACHINE/system PATH dir is searched before any user-PATH dir
# in a new terminal, so a user install can't reorder it. Surface any other copy
# so the user knows why `tina4 --version` might still report an old version.
$others = @(Get-Command tina4 -All -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Source } | Where-Object { $_ -and $_ -ne $dest })
if ($others.Count -gt 0) {
    Write-Host ""
    Write-Host "  Heads up: other tina4 copies are also on PATH:" -ForegroundColor Yellow
    $others | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
    Write-Host "  If 'tina4 --version' doesn't show $tag in a new terminal, remove the" -ForegroundColor Yellow
    Write-Host "  one(s) above (or their folder from PATH)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  tina4 $tag installed successfully" -ForegroundColor Green
Write-Host ""

# Do NOT auto-launch `tina4 setup` here. This script is normally run via
#   irm https://tina4.com/install.ps1 | iex
# which means the PowerShell host's stdin IS the download pipe -- already at EOF.
# `tina4 setup` is an interactive wizard; launched from that dead stdin its menu
# can't be answered and it would silently default, then fail on UAC elevation --
# the "Starting setup -> drops to the prompt" symptom. Instead, point the user at
# the next step. They run it in their own fresh terminal where stdin is a real
# console and the menu works. (`tina4 setup` itself also now refuses a
# non-interactive stdin, as a backstop.)
# NOTE: keep all Write-Host output ASCII-only. Windows PowerShell 5.1 reads this
# UTF-8 script as cp1252, so an em dash / ellipsis renders as mojibake (the
# reported "any time | open a new terminal" garbage). Plain ASCII renders right.
Write-Host "  Next step - run this in your terminal:" -ForegroundColor Cyan
Write-Host ""
Write-Host "    tina4 setup" -ForegroundColor Green -NoNewline
Write-Host "    Guided onboarding: language + AI tool + first project"
Write-Host ""
Write-Host "  Other commands (any time):"
Write-Host "    tina4 doctor   - Check your environment"
Write-Host "    tina4 serve    - Start the dev server"
Write-Host ""
