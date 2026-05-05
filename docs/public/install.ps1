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
Write-Host "Get started (open a new terminal):"
Write-Host "  tina4 doctor   - Check your environment"
Write-Host "  tina4 init     - Create a new project"
Write-Host "  tina4 serve    - Start development server"
Write-Host ""
