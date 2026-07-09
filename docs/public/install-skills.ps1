# Tina4 AI skills installer for Windows
# Usage: irm https://raw.githubusercontent.com/tina4stack/tina4/main/install-skills.ps1 | iex
#
# Installs the tina4 AI skills into ~/.claude/skills so Claude Desktop / Claude Code
# use Tina4 conventions out of the box. As of 3.13.59 the developer skill is split
# per language (each owned by its framework repo); tina4-js + tina4-maintainer are shared.
# Stopgap until `tina4 skills install` ships embedded in the CLI binary.
$ErrorActionPreference = "Stop"

# Pin skills to a released tag, not a moving branch, so an install is reproducible.
# Bump this when the skills change in a new release. Override with TINA4_SKILLS_REF.
$ref  = if ($env:TINA4_SKILLS_REF) { $env:TINA4_SKILLS_REF } else { "3.13.59" }
$dest = Join-Path $HOME ".claude\skills"

$devRefs = @("auth-and-services.md", "data-and-orm.md", "deployment.md", "routes-and-api.md", "templates-and-frontend.md", "realtime.md")

# repo, skill, reference files. Per-language developer skills come from their own
# framework repo; tina4-js + tina4-maintainer are shared (served from tina4-python).
$installs = @(
  @{ repo = "tina4-python"; skill = "tina4-developer-python"; refs = $devRefs }
  @{ repo = "tina4-php";    skill = "tina4-developer-php";    refs = $devRefs }
  @{ repo = "tina4-ruby";   skill = "tina4-developer-ruby";   refs = $devRefs }
  @{ repo = "tina4-nodejs"; skill = "tina4-developer-nodejs"; refs = $devRefs }
  @{ repo = "tina4-python"; skill = "tina4-js";               refs = @("html-and-components.md", "signals-and-reactivity.md", "persistence.md", "rtc.md") }
  @{ repo = "tina4-python"; skill = "tina4-maintainer";       refs = @("cli-and-deployment.md", "frond-and-frontend.md", "routing-and-orm.md", "subsystems.md") }
)

Write-Host ""
Write-Host "  Tina4 Skills Installer" -ForegroundColor Cyan
Write-Host "  Installing to: $dest  (ref: $ref)" -ForegroundColor Cyan
Write-Host ""

foreach ($i in $installs) {
  $base   = "https://raw.githubusercontent.com/tina4stack/$($i.repo)/$ref/.claude/skills"
  $refdir = Join-Path $dest "$($i.skill)\references"
  New-Item -ItemType Directory -Path $refdir -Force | Out-Null
  Invoke-WebRequest -Uri "$base/$($i.skill)/SKILL.md" -OutFile (Join-Path $dest "$($i.skill)\SKILL.md")
  foreach ($r in $i.refs) {
    Invoke-WebRequest -Uri "$base/$($i.skill)/references/$r" -OutFile (Join-Path $refdir $r)
  }
  Write-Host "  + $($i.skill)  ($($i.repo))" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Done - six skills installed. Restart Claude (Desktop/Code) to pick them up." -ForegroundColor Green
Write-Host ""
