# Tina4 documentation installer entry point.
# The installer implementation lives in tina4stack/tina4 so the published
# documentation and the Tina4 client always use the same target selection.
#
# Examples:
#   $env:TINA4_SKILLS_TARGET = "claude"; irm https://tina4.com/install-skills.ps1 | iex
#   $env:TINA4_SKILLS_TARGET = "codex"; irm https://tina4.com/install-skills.ps1 | iex
#   $env:TINA4_SKILLS_TARGET = "cursor"; irm https://tina4.com/install-skills.ps1 | iex
$ErrorActionPreference = "Stop"
$urls = @(
  "https://raw.githubusercontent.com/tina4stack/tina4/3.13.123/install-skills.ps1",
  "https://cdn.jsdelivr.net/gh/tina4stack/tina4@3.13.123/install-skills.ps1"
)
$installer = $null

foreach ($url in $urls) {
  for ($attempt = 0; $attempt -le 3; $attempt++) {
    try {
      $installer = (Invoke-WebRequest -UseBasicParsing -Uri $url).Content
      break
    } catch {
      if ($attempt -lt 3) { Start-Sleep -Seconds 2 }
    }
  }
  if ($installer) { break }
}

if (-not $installer) {
  throw "Could not download the Tina4 skills installer from either source."
}

Invoke-Expression $installer
