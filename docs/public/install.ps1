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

# Add to PATH if not already there
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$installDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$installDir", "User")
    $env:Path = "$env:Path;$installDir"
    Write-Host "Added $installDir to PATH"
}

Write-Host ""
Write-Host "  tina4 $tag installed successfully" -ForegroundColor Green
Write-Host ""

# Do NOT auto-launch `tina4 setup` here. This script is normally run via
#   irm https://tina4.com/install.ps1 | iex
# which means the PowerShell host's stdin IS the download pipe — already at EOF.
# `tina4 setup` is an interactive wizard; launched from that dead stdin its menu
# can't be answered and it would silently default, then fail on UAC elevation —
# the "Starting setup… → drops to the prompt" symptom. Instead, point the user at
# the next step. They run it in their own fresh terminal where stdin is a real
# console and the menu works. (`tina4 setup` itself also now refuses a
# non-interactive stdin, as a backstop.)
Write-Host "  Next step — run this in your terminal:" -ForegroundColor Cyan
Write-Host ""
Write-Host "    tina4 setup" -ForegroundColor Green -NoNewline
Write-Host "    Guided onboarding: language + AI tool + first project"
Write-Host ""
Write-Host "  Other commands (any time):"
Write-Host "    tina4 doctor   - Check your environment"
Write-Host "    tina4 serve    - Start the dev server"
Write-Host ""
