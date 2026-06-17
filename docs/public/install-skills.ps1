# Tina4 AI skills installer for Windows
# Usage: irm https://raw.githubusercontent.com/tina4stack/tina4/main/install-skills.ps1 | iex
#
# Installs the tina4 AI skills (tina4-developer, tina4-js) into ~/.claude/skills
# so Claude Desktop / Claude Code use Tina4 conventions out of the box.
# Stopgap until `tina4 skills install` ships embedded in the CLI binary.
$ErrorActionPreference = "Stop"

$base = "https://raw.githubusercontent.com/tina4stack/tina4-python/v3/.claude/skills"
$dest = Join-Path $HOME ".claude\skills"

# skill name -> reference files
$skills = [ordered]@{
  "tina4-developer" = @("auth-and-services.md", "data-and-orm.md", "deployment.md", "routes-and-api.md", "templates-and-frontend.md")
  "tina4-js"        = @("html-and-components.md", "signals-and-reactivity.md")
}

Write-Host ""
Write-Host "  Tina4 Skills Installer" -ForegroundColor Cyan
Write-Host "  Installing to: $dest" -ForegroundColor Cyan
Write-Host ""

foreach ($skill in $skills.Keys) {
  $refdir = Join-Path $dest "$skill\references"
  New-Item -ItemType Directory -Path $refdir -Force | Out-Null
  Invoke-WebRequest -Uri "$base/$skill/SKILL.md" -OutFile (Join-Path $dest "$skill\SKILL.md")
  foreach ($ref in $skills[$skill]) {
    Invoke-WebRequest -Uri "$base/$skill/references/$ref" -OutFile (Join-Path $refdir $ref)
  }
  Write-Host "  + $skill" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Done. Restart Claude (Desktop/Code) to pick up the skills." -ForegroundColor Green
Write-Host ""
