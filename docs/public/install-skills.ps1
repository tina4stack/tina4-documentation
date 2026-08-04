# Tina4 documentation installer entry point.
# The installer implementation lives in tina4stack/tina4 so the published
# documentation and the Tina4 client always use the same target selection.
#
# Examples:
#   $env:TINA4_SKILLS_TARGET = "claude"; irm https://tina4.com/install-skills.ps1 | iex
#   $env:TINA4_SKILLS_TARGET = "codex"; irm https://tina4.com/install-skills.ps1 | iex
$ErrorActionPreference = "Stop"
Invoke-RestMethod https://raw.githubusercontent.com/tina4stack/tina4/main/install-skills.ps1 | Invoke-Expression
