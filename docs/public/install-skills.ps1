# Tina4 documentation installer entry point.
# The installer implementation lives in tina4stack/tina4 so the published
# documentation and the Tina4 client always use the same target selection.
#
# Examples:
#   $env:TINA4_SKILLS_TARGET = "claude"; irm https://tina4.com/install-skills.ps1 | iex
#   $env:TINA4_SKILLS_TARGET = "codex"; irm https://tina4.com/install-skills.ps1 | iex
#   $env:TINA4_SKILLS_TARGET = "cursor"; irm https://tina4.com/install-skills.ps1 | iex
$ErrorActionPreference = "Stop"
# The skills release this bootstrap installs. One pin, honoured as an override,
# used to build all three source URLs. scripts/bump-skills-ref.sh bumps it.
$ref = if ($env:TINA4_SKILLS_REF) { $env:TINA4_SKILLS_REF } else { "3.13.136" }
# Fetch the inner installer from tina4.com FIRST (Tina4's own infra, Jenkins-
# deployed), then jsDelivr, then raw.githubusercontent as fallbacks. GitHub raw
# 503s during incidents, so leading with tina4.com keeps the common path off
# GitHub; the fallbacks keep the install working if tina4.com is ever down.
$urls = @(
  "https://tina4.com/skills/$ref/install-skills.ps1",
  "https://cdn.jsdelivr.net/gh/tina4stack/tina4@$ref/install-skills.ps1",
  "https://raw.githubusercontent.com/tina4stack/tina4/$ref/install-skills.ps1"
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
