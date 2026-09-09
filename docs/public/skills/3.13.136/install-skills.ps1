# Tina4 AI skills installer for Windows.
#
# Choose a target explicitly:
#   $env:TINA4_SKILLS_TARGET = "claude"; irm https://raw.githubusercontent.com/tina4stack/tina4/main/install-skills.ps1 | iex
#   $env:TINA4_SKILLS_TARGET = "codex"; irm https://raw.githubusercontent.com/tina4stack/tina4/main/install-skills.ps1 | iex
#   $env:TINA4_SKILLS_TARGET = "cursor"; irm https://raw.githubusercontent.com/tina4stack/tina4/main/install-skills.ps1 | iex
# Use TINA4_SKILLS_TARGET=all only when every supported tool should receive the skills.
$ErrorActionPreference = "Stop"

# Pin skills to a released tag, not a moving branch, so an install is reproducible.
# Bump this when the skills change in a new release. Override with TINA4_SKILLS_REF.
$ref = if ($env:TINA4_SKILLS_REF) { $env:TINA4_SKILLS_REF } else { "3.13.136" }
$target = $env:TINA4_SKILLS_TARGET
$skillHome = if ($env:TINA4_SKILLS_HOME) { $env:TINA4_SKILLS_HOME } else { $HOME }
# Three sources, tried in this order per file: tina4.com (Tina4's own infra),
# jsDelivr (a cached CDN mirror), then raw.githubusercontent (the GitHub origin).
# tina4.com is FIRST so the common path never depends on GitHub raw, which 503s
# during GitHub incidents; jsDelivr and raw remain automatic fallbacks and the
# sha256 manifest still gates every downloaded file. Each source has its OWN path
# shape (tina4.com is flat; jsDelivr uses repo@ref; raw uses repo/ref), composed
# per-tier in Get-Tina4SkillUrls. Override any tier for a mirror or an air-gap.
$tina4Root = if ($env:TINA4_SKILLS_TINA4_ROOT) { $env:TINA4_SKILLS_TINA4_ROOT } else { "https://tina4.com/skills" }
$jsdelivrRoot = if ($env:TINA4_SKILLS_JSDELIVR_ROOT) { $env:TINA4_SKILLS_JSDELIVR_ROOT } else { "https://cdn.jsdelivr.net/gh/tina4stack" }
$rawRoot = if ($env:TINA4_SKILLS_RAW_ROOT) { $env:TINA4_SKILLS_RAW_ROOT } else { "https://raw.githubusercontent.com/tina4stack" }
$retryCount = if ($env:TINA4_SKILLS_RETRY_COUNT) { [int]$env:TINA4_SKILLS_RETRY_COUNT } else { 3 }
$retryDelay = if ($env:TINA4_SKILLS_RETRY_DELAY) { [int]$env:TINA4_SKILLS_RETRY_DELAY } else { 2 }
$destinations = switch ($target) {
  "claude" { @(Join-Path $skillHome ".claude\skills") }
  "codex"  { @(Join-Path $skillHome ".agents\skills") }
  "cursor" { @(Join-Path $skillHome ".cursor\skills") }
  "all"    { @(Join-Path $skillHome ".claude\skills"; Join-Path $skillHome ".agents\skills"; Join-Path $skillHome ".cursor\skills") }
  default { throw "Set TINA4_SKILLS_TARGET to claude, codex, cursor, or all." }
}
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("tina4-skills-" + [guid]::NewGuid())

# Every file under references/, not most of them. ai-coder-rule-path.svg was
# missing here and in the sh installer, so a SUCCESSFUL install still produced
# an incomplete skill -- no error, nothing to notice.
$devRefs = @("auth-and-services.md", "data-and-orm.md", "deployment.md", "routes-and-api.md", "templates-and-frontend.md", "realtime.md", "web-push.md", "ai-coder-rule-path.svg")

# Per-language developer skills come from their own framework repo; tina4-js and
# tina4-maintainer are shared and served from tina4-python.
$installs = @(
  @{ repo = "tina4-python"; skill = "tina4-developer-python"; refs = $devRefs }
  @{ repo = "tina4-php";    skill = "tina4-developer-php";    refs = $devRefs }
  @{ repo = "tina4-ruby";   skill = "tina4-developer-ruby";   refs = $devRefs }
  @{ repo = "tina4-nodejs"; skill = "tina4-developer-nodejs"; refs = $devRefs }
  @{ repo = "tina4-python"; skill = "tina4-js";               refs = @("html-and-components.md", "signals-and-reactivity.md", "persistence.md", "rtc.md") }
  @{ repo = "tina4-python"; skill = "tina4-maintainer";       refs = @("cli-and-deployment.md", "frond-and-frontend.md", "routing-and-orm.md", "subsystems.md") }
  @{ repo = "tina4-python"; skill = "tina4-architect";        refs = @() }
  @{ repo = "tina4-python"; skill = "tina4-design";           refs = @() }
)
$legacySkills = @("tina4-developer")

function Invoke-Tina4Download {
  param(
    [Parameter(Mandatory = $true)][string[]]$Urls,
    [Parameter(Mandatory = $true)][string]$Destination
  )

  foreach ($url in $Urls) {
    for ($attempt = 0; $attempt -le $retryCount; $attempt++) {
      try {
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $Destination
        return
      } catch {
        Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        if ($attempt -lt $retryCount) {
          Start-Sleep -Seconds $retryDelay
        }
      }
    }
    Write-Warning "Download failed, trying next source: $url"
  }

  throw "Every download source failed for $Destination"
}

function Get-Tina4SkillUrls {
  # Candidate URLs for one skill file, in priority order: tina4.com (flat,
  # stage-relative), jsDelivr, raw.
  param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [Parameter(Mandatory = $true)][string]$Skill,
    [Parameter(Mandatory = $true)][string]$Relative
  )
  @(
    "$tina4Root/$ref/$Skill/$Relative",
    "$jsdelivrRoot/${Repo}@$ref/.claude/skills/$Skill/$Relative",
    "$rawRoot/$Repo/$ref/.claude/skills/$Skill/$Relative"
  )
}

function Test-Tina4Checksums {
  # Verify every staged file against skills.sha256 (published in tina4 at $ref by
  # scripts/gen-skills-sha256.sh) BEFORE anything is installed, so a tampered or
  # truncated download can never reach a skills directory. Mirrors the same step in
  # install-skills.sh. install-skills.ps1 is itself EV-signed; this checks the payload.
  $manifest = Join-Path ([System.IO.Path]::GetTempPath()) ("tina4-skills-" + [guid]::NewGuid() + ".sha256")
  # SHA256 via .NET, not Get-FileHash: that cmdlet is absent on some Windows
  # PowerShell hosts (CommandNotFoundException), while .NET is always present.
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    Invoke-Tina4Download -Urls @(
      "$tina4Root/$ref/skills.sha256",
      "$jsdelivrRoot/tina4@$ref/skills.sha256",
      "$rawRoot/tina4/$ref/skills.sha256"
    ) -Destination $manifest
    $lines = @(Get-Content -LiteralPath $manifest | Where-Object { $_ -match '\S' })
    if ($lines.Count -eq 0) {
      throw "Skills checksum manifest is empty -- refusing to install."
    }
    foreach ($line in $lines) {
      if ($line -notmatch '^([0-9a-fA-F]{64})\s+(.+?)\s*$') {
        throw "Malformed line in skills checksum manifest: $line"
      }
      $expected = $matches[1]
      $relative = $matches[2] -replace '/', '\'
      $path = Join-Path $stage $relative
      if (-not (Test-Path -LiteralPath $path)) {
        throw "A skill file named in the manifest was not downloaded: $($matches[2])"
      }
      $actual = [System.BitConverter]::ToString($sha256.ComputeHash([System.IO.File]::ReadAllBytes($path))).Replace('-', '')
      if ($actual -ine $expected) {
        throw "A skill file failed checksum verification (tampering or a stale manifest) -- nothing installed: $($matches[2])"
      }
    }
    Write-Host "  verified $($lines.Count) skill files against skills.sha256 (ref $ref)" -ForegroundColor Green
  } finally {
    $sha256.Dispose()
    Remove-Item -LiteralPath $manifest -Force -ErrorAction SilentlyContinue
  }
}

Write-Host ""
Write-Host "  Tina4 Skills Installer" -ForegroundColor Cyan
Write-Host "  Target: $target  (ref: $ref)" -ForegroundColor Cyan
Write-Host ""

try {
  foreach ($i in $installs) {
    $refdir = Join-Path $stage "$($i.skill)\references"
    New-Item -ItemType Directory -Path $refdir -Force | Out-Null
    Invoke-Tina4Download -Urls (Get-Tina4SkillUrls $i.repo $i.skill "SKILL.md") `
      -Destination (Join-Path $stage "$($i.skill)\SKILL.md")
    foreach ($reference in $i.refs) {
      Invoke-Tina4Download -Urls (Get-Tina4SkillUrls $i.repo $i.skill "references/$reference") `
        -Destination (Join-Path $refdir $reference)
    }
    Write-Host "  + $($i.skill)  ($($i.repo))" -ForegroundColor Green
  }

  Test-Tina4Checksums

  foreach ($destination in $destinations) {
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($legacySkill in $legacySkills) {
      $legacyPath = Join-Path $destination $legacySkill
      if (Test-Path -LiteralPath $legacyPath) {
        Remove-Item -LiteralPath $legacyPath -Recurse -Force
        Write-Host "  - removed legacy $legacySkill" -ForegroundColor DarkYellow
      }
    }
    foreach ($skill in Get-ChildItem -Path $stage -Directory) {
      $replacement = Join-Path $destination ("." + $skill.Name + ".tina4-new")
      $installed = Join-Path $destination $skill.Name
      Remove-Item -Path $replacement -Recurse -Force -ErrorAction SilentlyContinue
      Copy-Item -Path $skill.FullName -Destination $replacement -Recurse -Force
      Remove-Item -Path $installed -Recurse -Force -ErrorAction SilentlyContinue
      Move-Item -Path $replacement -Destination $installed -Force
    }
    Set-Content -Path (Join-Path $destination ".tina4-skills-ref") -Value $ref -NoNewline
    Write-Host "  installed for $destination" -ForegroundColor Green
  }
} finally {
  Remove-Item -Path $stage -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "  Done - eight skills installed for $target (ref $ref). Restart your coding tool to pick them up." -ForegroundColor Green

# SIG # Begin signature block
# MIIoPAYJKoZIhvcNAQcCoIIoLTCCKCkCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBYfGP0YsM4f2KN
# XyKZEp1+MhhubWl8IyAOa5mM663VXKCCINgwggbNMIIEtaADAgECAhEAu/DMtbe4
# Mf0hrjJ3iuQMiTANBgkqhkiG9w0BAQwFADCBgDELMAkGA1UEBhMCUEwxIjAgBgNV
# BAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAlBgNVBAsTHkNlcnR1bSBD
# ZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMbQ2VydHVtIFRydXN0ZWQg
# TmV0d29yayBDQSAyMB4XDTIxMDUxOTA1MzIxM1oXDTM2MDUxODA1MzIxM1owajEL
# MAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjE4
# MDYGA1UEAxMvQ2VydHVtIEV4dGVuZGVkIFZhbGlkYXRpb24gQ29kZSBTaWduaW5n
# IDIwMjEgQ0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCUvvjwlqjf
# 9eedRTK+NoavZlVxmQTPIN1nK5XQRUQWyPWwHD54wa2aD2kRDrAjBf71/T0XN9Oq
# ms5ML/Jolgryv3JW7/yahp7lg/wn3PDnNwzC1BlFMyCdEktQmUXMmE4mmxSutRY1
# OGGagENWPjbQ1R/x4HuTByWbG+TUV7dIPxE7TMy9Npco4f09DN6QFRXdk7bZTu58
# kxu6MFH6mzQkC3IXvExfo0c/CT4/hTZD2XknHjXLzi9jzInSHS9GQqeXd6nWbkwE
# u7znKpNEcSElorDSEcRhc1OSOLjUK0x0cOw8whzQ0fWGkPoqgCslbjZoko7U7kj/
# Fn4TWQ8s75LHjhVao+w2SWMP0ELWYIkq1ComGq3wqBD7VU6rtCDoUf237HkgRBxL
# XFjwp444oKWnchYMZ7epWX8jqntSr4QHeidL72c6XswQIIZsFglV4BO28jO02yS7
# w4iyY0c6PQs34GZ7SWphsN1DaiX9ysc6hovVYoVA94t+3p4TI1RtK9Ayh0atmfYP
# JqtBfk5kJ1h4nNax0lZmJL9chJjZQb+7XW8MQgstiQdsegaz2QL6Edm+94N8IW6T
# YaalyO9LeR35A9MoTLo79rdB04naTqWdPTBKh7DpS53ZAQn5dYs2per+m7ZeIxnE
# WaNcG+PbRh+ZslFb6M75JgN43szB+/VYVQIDAQABo4IBVTCCAVEwDwYDVR0TAQH/
# BAUwAwEB/zAdBgNVHQ4EFgQUrFfKCBbcP8UxHApN2/vx3pknLTQwHwYDVR0jBBgw
# FoAUtqFUOQLDoD+Oirz61PgcptE6Dv0wDgYDVR0PAQH/BAQDAgEGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMDMDAGA1UdHwQpMCcwJaAjoCGGH2h0dHA6Ly9jcmwuY2VydHVt
# LnBsL2N0bmNhMi5jcmwwbAYIKwYBBQUHAQEEYDBeMCgGCCsGAQUFBzABhhxodHRw
# Oi8vc3ViY2Eub2NzcC1jZXJ0dW0uY29tMDIGCCsGAQUFBzAChiZodHRwOi8vcmVw
# b3NpdG9yeS5jZXJ0dW0ucGwvY3RuY2EyLmNlcjA5BgNVHSAEMjAwMC4GBFUdIAAw
# JjAkBggrBgEFBQcCARYYaHR0cDovL3d3dy5jZXJ0dW0ucGwvQ1BTMA0GCSqGSIb3
# DQEBDAUAA4ICAQC7khlZjFbU+gsRdcraFFJKj1PL63MVudnm/AILuNaxm7LIZOYt
# rZaRWEpR0qd3uhSpUEI29fMBZvuu3CHXJsM58hbJFo4YoHnyDJgTkeVmc10fd1NI
# //cI3nRD1/Alx09yWhPZlze0A/Bvwc3LcZtTywfsL5tD3QAL8ZqelrHt1Eb8AnDE
# nAzKNbm1mwYmD/5dy1XkIKfsM1pmRM2ZDcJ4qpwVewE7g+4e+Y+iq42LuaHPvNAk
# wq0daA9Hp3qemk0cRFfM5257MvEsu+6w8+44mpQUOgpASVIjY3l2vdf6BUfBJfsd
# 3pcp/2hfDnXaql9AoB7ps7eCZb9VXKm/u2lTRMf5esOcZFy4udsnGBaOwSSUe0ch
# YusfJ9IjsmpoMl4CW5E0R/U55Bz6TpDo+gaXQJL4i/zv0UR5papGsDguBASp9g/O
# fnvGTeWrS9l5orEktu9ExrFfPvAKxZK+4AO9bapPhMATraKo6kx6K51pS1ZO2pf1
# r3B+lXN5bTLgp8g/dygUZm2cmauBAzJA5v/iHOb0b4b4Muqc8dxgcX1jZRLtLvxn
# AWxkKIMfj7A4M0JrN4rLBUpPFM0+Bp2sR7rtFqNZW56huaDkxO75eNRN2z4A959R
# 5GBRnFWtgE65+B1RHAQQ/TOF4mU0Y3oIhVQr3rUh4tdSvIxr8QpsDKIvsDCCBvMw
# ggTboAMCAQICEFIdiL99yRWe40RYYdsSYcYwDQYJKoZIhvcNAQELBQAwajELMAkG
# A1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjE4MDYG
# A1UEAxMvQ2VydHVtIEV4dGVuZGVkIFZhbGlkYXRpb24gQ29kZSBTaWduaW5nIDIw
# MjEgQ0EwHhcNMjUwNzA4MTAzMzIzWhcNMjcwNzA4MTAzMzIyWjCB/TEdMBsGA1UE
# DxMUUHJpdmF0ZSBPcmdhbml6YXRpb24xEzARBgsrBgEEAYI3PAIBAxMCWkExFzAV
# BgNVBAUTDjIwMTQvMDAzODY2LzA3MQswCQYDVQQGEwJaQTEVMBMGA1UECAwMV2Vz
# dGVybiBDYXBlMRIwEAYDVQQHDAlDYXBlIFRvd24xDTALBgNVBBETBDc1NzAxIzAh
# BgNVBAkMGjFCIE1hZHJpZCBTdHJlZXQsIFVpdHppY2h0MSAwHgYDVQQKDBdDb2Rl
# IEluZmluaXR5IChQdHkpIEx0ZDEgMB4GA1UEAwwXQ29kZSBJbmZpbml0eSAoUHR5
# KSBMdGQwggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQDW71KREbtjcKHZ
# xhsWa/228w9DGKNzqEhqajzQTjuQFqS+havJfj6ADAWdmxLwJP0zAzUMqxWe865k
# GUSYcX1i5BCLqzxaOIRX6d4qu9IrsMADGCCYnSiSiXxZvGs52NkE04fEhP04RIM7
# quRBm0+H24TyHXve1OCqApzltRDIeQa1wP6q1Q9uPtQOIUOe9OPsSMy0Ghrj6TKP
# V5e/+JLJYbk1Q4UINq+Gsvn3iuO4Qdw/BFwXwDc2gn0ZNo+V3dZubDIG53+rbKZI
# sm7QP/2wB4sD9OWt7J0Ga9uuBmhnCxPBMFoCWMQw4SKlNMjmbmJ0fZk9mAsLjAyz
# S3hPgA830bow2YZjxuUHot4Aafatq4iIHBiy2W0AjmOxgJO3/VqfdT/GIg1mXNP2
# D4ocmHMgqG4Yc+IiiOtghnFZUAgDoT8Pm6gh3JK0/RoADAWfeDa1RcP1tZ/l0ab3
# uNAY0hMgz7G40A0JPCTBoeaxdQCCH5lngi6qTW/wyhJtjSxkAdsCAwEAAaOCAX8w
# ggF7MAwGA1UdEwEB/wQCMAAwQQYDVR0fBDowODA2oDSgMoYwaHR0cDovL2NldmNz
# Y2EyMDIxLmNybC5jZXJ0dW0ucGwvY2V2Y3NjYTIwMjEuY3JsMHcGCCsGAQUFBwEB
# BGswaTAuBggrBgEFBQcwAYYiaHR0cDovL2NldmNzY2EyMDIxLm9jc3AtY2VydHVt
# LmNvbTA3BggrBgEFBQcwAoYraHR0cDovL3JlcG9zaXRvcnkuY2VydHVtLnBsL2Nl
# dmNzY2EyMDIxLmNlcjAfBgNVHSMEGDAWgBSsV8oIFtw/xTEcCk3b+/HemSctNDAd
# BgNVHQ4EFgQUYsBjN845GrU9vcDNsAUBmlh+MGowSgYDVR0gBEMwQTAHBgVngQwB
# AzA2BgsqhGgBhvZ3AgUBBzAnMCUGCCsGAQUFBwIBFhlodHRwczovL3d3dy5jZXJ0
# dW0ucGwvQ1BTMBMGA1UdJQQMMAoGCCsGAQUFBwMDMA4GA1UdDwEB/wQEAwIHgDAN
# BgkqhkiG9w0BAQsFAAOCAgEAEc4osdwuJURLPKERbtqGk6gD0zSjV4QP5AOyj49h
# 5i5a6Yj5Mf1gd8FebstHGjYGv3sbZ74Y5LJnxi1tzGBPk4VBeYd0NFPKVw/aWVCp
# Vii3prG4ILeHCt2ljV+XSZei2NXTcDJrj+BuuEyT7IsJeE6aE7i/qyEYz0ri9+Jl
# Ef/O1XNXhHI4SmMkM5OT6NOEQD1Gv/YZDc+W73zUCn9N++GY8EN+CdxSkP4SbxFP
# on4qLHJV1cCcuePdcv6QPwpywS164sh52r7At7901pHnEqE0zkXdU3xL5k03fs25
# DyYrjeNzoziXbe7a5tF9Zos/5PJN6rI6wSYPFRLyodrlYNweCJvVONMVxhj3CAGr
# zoMCpLfQQDaAIKGOduhz4fE9Hpnd7w6JpCze4eW+UBAGGZ82715ylJyCjB3J5iBB
# rfSMwhM5h6Bwboi0CoJ8heYMxfhfhXpebpaJw8IIxm+G0irShakWmypUG++dJDbc
# /7N0OP2+6P4h5xWUCpbqlgKmQzP6En17SFbCEMzJrwlP5/YfNs2WIIBGTf+U3kQH
# vys+70arT6YbBTtSqN6pLzpbrvCVeoFUkubtF+PJ2EZohOBRvLZW4nFIzOLWevV/
# UQjgtp7JgA7tEm63FxfmQWVmtKdM9svDJzWd8GvsYar3mQxqlkvyMomVh9ih/Uk7
# C6swggXJMIIEsaADAgECAhAbtY8lKt8jAEkoya49fu0nMA0GCSqGSIb3DQEBDAUA
# MH4xCzAJBgNVBAYTAlBMMSIwIAYDVQQKExlVbml6ZXRvIFRlY2hub2xvZ2llcyBT
# LkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxIjAg
# BgNVBAMTGUNlcnR1bSBUcnVzdGVkIE5ldHdvcmsgQ0EwHhcNMjEwNTMxMDY0MzA2
# WhcNMjkwOTE3MDY0MzA2WjCBgDELMAkGA1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpl
# dG8gVGVjaG5vbG9naWVzIFMuQS4xJzAlBgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMbQ2VydHVtIFRydXN0ZWQgTmV0d29yayBD
# QSAyMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAvfl4+ObVgAxknYYb
# lmRnPyI6HnUBfe/7XGeMycxca6mR5rlC5SBLm9qbe7mZXdmbgEvXhEArJ9PoujC7
# Pgkap0mV7ytAJMKXx6fumyXvqAoAl4Vaqp3cKcniNQfrcE1K1sGzVrihQTib0fsx
# f4/gX+GxPw+OFklg1waNGPmqJhCrKtPQ0WeNG0a+RzDVLnLRxWPa52N5RH5LYySJ
# hi40PylMUosqp8DikSiJucBb+R3Z5yet/5oCl8HGUJKbAiy9qbk0WQq/hEr/3/6z
# n+vZnuCYI+yma3cWKtvMrTscpIfcRnNeGWJoRVfkkIJCu0LW8GHgwaM9ZqNd9Bju
# iMmNF0UpmTJ1AjHuKSbIawLmtWJFfzcVWiNoidQ+3k4nsPBADLxNF8tNorMe0AZa
# 3faTz1d1mfX6hhpneLO/lv403L3nUlbls+V1e9dBkQXcXWnjlQ1DufyDljmVe2yA
# Wk8TcsbXfSl6RLpSpCrVQUYJIP4ioLZbMI28iQzV13D4h1L92u+sUS4Hs07+0Ana
# cO+Y+lbmbdu1V0vc5SwlFcieLnhO+NqcnoYsylfzGuXIkosagpZ6w7xQEmnYDlpG
# izrrJvojybawgb5CAKT41v4wLsfSRvbljnX98sy50IdbzAYQYLuDNbdeZ95H7JlI
# 8aShFf6tjGKOOVVPORa5sWOd/7cCAwEAAaOCAT4wggE6MA8GA1UdEwEB/wQFMAMB
# Af8wHQYDVR0OBBYEFLahVDkCw6A/joq8+tT4HKbROg79MB8GA1UdIwQYMBaAFAh2
# zcsH/yT2xc3tu5C84oQ3RnX3MA4GA1UdDwEB/wQEAwIBBjAvBgNVHR8EKDAmMCSg
# IqAghh5odHRwOi8vY3JsLmNlcnR1bS5wbC9jdG5jYS5jcmwwawYIKwYBBQUHAQEE
# XzBdMCgGCCsGAQUFBzABhhxodHRwOi8vc3ViY2Eub2NzcC1jZXJ0dW0uY29tMDEG
# CCsGAQUFBzAChiVodHRwOi8vcmVwb3NpdG9yeS5jZXJ0dW0ucGwvY3RuY2EuY2Vy
# MDkGA1UdIAQyMDAwLgYEVR0gADAmMCQGCCsGAQUFBwIBFhhodHRwOi8vd3d3LmNl
# cnR1bS5wbC9DUFMwDQYJKoZIhvcNAQEMBQADggEBAFHCoVgWIhCL/IYx1MIy01z4
# S6Ivaj5N+KsIHu3V6PrnCA3st8YeDrJ1BXqxC/rXdGoABh+kzqrya33YEcARCNQO
# TWHFOqj6seHjmOriY/1B9ZN9DbxdkjuRmmW60F9MvkyNaAMQFtXx0ASKhTP5N+db
# LiZpQjy6zbzUeulNndrnQ/tjUoCFBMQllVXwfqefAcVbKPjgzoZwpic7Ofs4LphT
# ZSJ1Ldf23SIikZbr3WjtP6MZl9M7JYjsNhI9qX7OAo0FmpKnJ25FspxihjcNpDOO
# 16hO0EoXQ0zF8ads0h5YbBRRfopUofbvn3l6XYGaFpAP4bvxSgD5+d2+7arszgow
# gga5MIIEoaADAgECAhEA5/9pxzs1zkuRJth0fGilhzANBgkqhkiG9w0BAQwFADCB
# gDELMAkGA1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMu
# QS4xJzAlBgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIG
# A1UEAxMbQ2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMB4XDTIxMDUxOTA1MzIw
# N1oXDTM2MDUxODA1MzIwN1owVjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2Vj
# byBEYXRhIFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGlu
# ZyAyMDIxIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA6RIfBDXt
# uV16xaaVQb6KZX9Od9FtJXXTZo7b+GEof3+3g0ChWiKnO7R4+6MfrvLyLCWZa6Gp
# FHjEt4t0/GiUQvnkLOBRdBqr5DOvlmTvJJs2X8ZmWgWJjC7PBZLYBWAs8sJl3kNX
# xBMX5XntjqWx1ZOuuXl0R4x+zGGSMzZ45dpvB8vLpQfZkfMC/1tL9KYyjU+htLH6
# 8dZJPtzhqLBVG+8ljZ1ZFilOKksS79epCeqFSeAUm2eMTGpOiS3gfLM6yvb8Bg6b
# xg5yglDGC9zbr4sB9ceIGRtCQF1N8dqTgM/dSViiUgJkcv5dLNJeWxGCqJYPgzKl
# YZTgDXfGIeZpEFmjBLwURP5ABsyKoFocMzdjrCiFbTvJn+bD1kq78qZUgAQGGtd6
# zGJ88H4NPJ5Y2R4IargiWAmv8RyvWnHr/VA+2PrrK9eXe5q7M88YRdSTq9TKbqdn
# ITUgZcjjm4ZUjteq8K331a4P0s2in0p3UubMEYa/G5w6jSWPUzchGLwWKYBfeSu6
# dIOC4LkeAPvmdZxSB1lWOb9HzVWZoM8Q/blaP4LWt6JxjkI9yQsYGMdCqwl7uMnP
# UIlcExS1mzXRxUowQref/EPaS7kYVaHHQrp4XB7nTEtQhkP0Z9Puz/n8zIFnUSnx
# Dof4Yy650PAXSYmK2TcbyDoTNmmt8xAxzcMCAwEAAaOCAVUwggFRMA8GA1UdEwEB
# /wQFMAMBAf8wHQYDVR0OBBYEFL5UAi+/QGxzQ86sCSVOnkNEGu7gMB8GA1UdIwQY
# MBaAFLahVDkCw6A/joq8+tT4HKbROg79MA4GA1UdDwEB/wQEAwIBBjATBgNVHSUE
# DDAKBggrBgEFBQcDCDAwBgNVHR8EKTAnMCWgI6Ahhh9odHRwOi8vY3JsLmNlcnR1
# bS5wbC9jdG5jYTIuY3JsMGwGCCsGAQUFBwEBBGAwXjAoBggrBgEFBQcwAYYcaHR0
# cDovL3N1YmNhLm9jc3AtY2VydHVtLmNvbTAyBggrBgEFBQcwAoYmaHR0cDovL3Jl
# cG9zaXRvcnkuY2VydHVtLnBsL2N0bmNhMi5jZXIwOQYDVR0gBDIwMDAuBgRVHSAA
# MCYwJAYIKwYBBQUHAgEWGGh0dHA6Ly93d3cuY2VydHVtLnBsL0NQUzANBgkqhkiG
# 9w0BAQwFAAOCAgEAuJNZd8lMFf2UBwigp3qgLPBBk58BFCS3Q6aJDf3TISoytK0e
# al/JyCB88aUEd0wMNiEcNVMbK9j5Yht2whaknUE1G32k6uld7wcxHmw67vUBY6pS
# p8QhdodY4SzRRaZWzyYlviUpyU4dXyhKhHSncYJfa1U75cXxCe3sTp9uTBm3f8Bj
# 8LkpjMUSVTtMJ6oEu5JqCYzRfc6nnoRUgwz/GVZFoOBGdrSEtDN7mZgcka/tS5MI
# 47fALVvN5lZ2U8k7Dm/hTX8CWOw0uBZloZEW4HB0Xra3qE4qzzq/6M8gyoU/DE0k
# 3+i7bYOrOk/7tPJg1sOhytOGUQ30PbG++0FfJioDuOFhj99b151SqFlSaRQYz74y
# /P2XJP+cF19oqozmi0rRTkfyEJIvhIZ+M5XIFZttmVQgTxfpfJwMFFEoQrSrklOx
# pmSygppsUDJEoliC05vBLVQ+gMZyYaKvBJ4YxBMlKH5ZHkRdloRYlUDplk8GUa+O
# CMVhpDSQurU6K1ua5dmZftnvSSz2H96UrQDzA6DyiI1V3ejVtvn2azVAXg6Nnjmu
# RZ+wa7Pxy0H3+V4K4rOTHlG3VYA6xfLsTunCz72T6Ot4+tkrDYOeaU1pPX1CBfYj
# 6EW2+ELq46GP8KCNUQDirWLU4nOmgCat7vN0SD6RlwUiSsMeCiQDmZwgwrUwggaC
# MIIEaqADAgECAhAo8HfBHDa9/l90MkdwJy4DMA0GCSqGSIb3DQEBDAUAMFYxCzAJ
# BgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAi
# BgNVBAMTG0NlcnR1bSBUaW1lc3RhbXBpbmcgMjAyMSBDQTAeFw0yNjAzMTEwNzM0
# NTRaFw0zNjAyMjcwNzM0NTRaMFAxCzAJBgNVBAYTAlBMMSEwHwYDVQQKDBhBc3Nl
# Y28gRGF0YSBTeXN0ZW1zIFMuQS4xHjAcBgNVBAMMFUNlcnR1bSBUaW1lc3RhbXAg
# MjAyNjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALi9zfBw+xI12hi2
# F9uNQBNOSTkTIi13fuh3DiWybI5392bBfJw6tO7zDs7UqP/rejVf4xFTU3XNOPsu
# OFkP5SPFsnWwn3VJL+NhNhsuujvYsQtaQnvNo1wk46reTgws1L8OFEdKaxgyqT4z
# OQx81mLwNZSqXNU9Rrb9oAJWJF4Mydz+C1ebu0D0+vgM3tqAQ8TU203fqgKCPqId
# HloaFqH9eyR+8tnpmy2hnnN59ZOtmsuHeRwf5iTOhlhf0d/qqquLOSIGPgGVL1Hj
# 5XBUox2OE7tQRr+l/xxNbL6OuwBO4Aa2EbuxYg37cpXv5i2/lTL4NASB/duf9W4f
# jA3Ro+GP+bC54n2OYiM3Cq8z92ejx8F5HWO2e4/75eC95B9tMw/eq7109GDyW2+2
# ut5Bn0o8MXJTERkyystWbqcnUkomA97qfiDCwvpWuOMdfTOksXe9S+xDxOJaCbiy
# TivgPulxcT+tfQTRXBr5UwtPvc+INnafOEilzVHA11tv+pHcylryxBc08cUihf/t
# tqkZS0bmx3VxQay8uohaTp0//ECA9vYGW51SKdJMJhXvKyIdBLy8WYNchTt8yRIT
# v9Adxg9JqGujh+TnP1bW3aQjFtlEl7SzgNeI8OVA/CJAWWUuRT3Au9ToOpHy/flr
# rknhN4heEw7/6ILMv4HSsj0YZ4otAgMBAAGjggFQMIIBTDB1BggrBgEFBQcBAQRp
# MGcwOwYIKwYBBQUHMAKGL2h0dHA6Ly9zdWJjYS5yZXBvc2l0b3J5LmNlcnR1bS5w
# bC9jdHNjYTIwMjEuY2VyMCgGCCsGAQUFBzABhhxodHRwOi8vc3ViY2Eub2NzcC1j
# ZXJ0dW0uY29tMB8GA1UdIwQYMBaAFL5UAi+/QGxzQ86sCSVOnkNEGu7gMAwGA1Ud
# EwEB/wQCMAAwOQYDVR0fBDIwMDAuoCygKoYoaHR0cDovL3N1YmNhLmNybC5jZXJ0
# dW0ucGwvY3RzY2EyMDIxLmNybDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCB4AwIgYDVR0gBBswGTAIBgZngQwBBAIwDQYLKoRoAYb2dwIFAQsw
# HQYDVR0OBBYEFCM5aiirmhKnpKfyH/lFmr+N/oIDMA0GCSqGSIb3DQEBDAUAA4IC
# AQBm/pObrAveTqYFPCSthxNVwBHTW4TfuBQY2KGCdMlH6ALjVPYf2XARNGMTXScR
# 0JQ2/c2LxLpoHHhRwxFf3d933DhFS165rYj6iPSQKm41rc9AMpTCjMdmai1aK9o8
# 70pOzTzLRhWFVIxm+5Qf+t4V5z14tPoUsAWdfRKD1Zzvzfe5AHlE9rxOZcGROiUL
# xs3Edf7ZJ8RZI0jzD9juj2oEX2XS7BVKuNCK1W0h1mjapv028yqo8UtZh5/1Ib48
# Yyp88BDYShh5PSGUUuS5tYXVfcduIPBe3PdNTYRYdT5VNxkwLgjMzIcr/6SH2fej
# FJDjnCxjvXLuarErJg/IdI+hXdGIBDVOGv1zrkF4ktoQvFZIp5DIAYh0GwyUhc87
# qqn5UaYTj2+iyiBDSNh7aGCrkuAnqg7Qh7frhX+QhMGeJ9SpLpnG76qN85hLyjvY
# R6gRYiLTj8G4fxjqV400/buPw0rBo9yJZyq/8cGdCOLPOYf9qpefTcrZKeO9pg+U
# JHx8UABbaTqizRxm8sUSEycccCCFhIit3AI/3wGuSOADeiA676NcQ7+dsP04Yvzv
# dN7pTZNyg672WpBDJdg0eItHl4yomvNeIOWh1qs4QqOW6TI8Ocsi4uSDTLorxLUD
# nBTwKQzzpxd1YUctEgRh32R0J9FkFkeEruJU94RljFr1uDGCBrowgga2AgEBMH4w
# ajELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5B
# LjE4MDYGA1UEAxMvQ2VydHVtIEV4dGVuZGVkIFZhbGlkYXRpb24gQ29kZSBTaWdu
# aW5nIDIwMjEgQ0ECEFIdiL99yRWe40RYYdsSYcYwDQYJYIZIAWUDBAIBBQCggYgw
# GQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDkw
# OTE2NTgyN1owHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcN
# AQkEMSIEIJ5cRea5/g/zo8gw4bmSQlNJk4LQH8Ng/QQ6jLXVmVoEMA0GCSqGSIb3
# DQEBAQUABIIBgAvqjMbVnF87fpr2BqZsC+wC13G1G1BOy4HgqUJz+0MPRGs8sHS6
# N9uLS/GDk1erd8xMNtnc8e3fxL+Eiaqt4C2CAdAm+AKb2QHKLHDTk1dVbZlOJMcG
# ZvRUYAoW/B7nVTpMhU0frqOBfHnkrBpSNsq8ASfDBnO0Vad5lzcH6mzAft/GQP+x
# C0YjoycCALeKXsg4e8PqJSo9fu/J23JT3BtWGYSk6ukpqU7/nxmc911L2rhtj2ci
# 1GSyHEgSiYCyBJmAD90alRz8IYtbduKSYRRE2J2FL73APu7HhEv0scfGTyh2IJFE
# 3INOZfvu1SYouRI3SBTTg7k/oR9H02mp7CdqBAMcEMIn4ciZbJ/GOvIoktPpf3Et
# OT0fe6iPMBORx2Vq4H/kbJoacG2HNjnIjD5BuIwy+2kGgG9h1X4LCaWOdfFqLs2o
# DMqsn6Vpz7hPCthBaHBGq25so79C6YrRo/T526WNH1FMvTx9yHnt9BJv+7QZdl+P
# 0erQlIPm0p8UUKGCBAIwggP+BgkqhkiG9w0BCQYxggPvMIID6wIBATBqMFYxCzAJ
# BgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAi
# BgNVBAMTG0NlcnR1bSBUaW1lc3RhbXBpbmcgMjAyMSBDQQIQKPB3wRw2vf5fdDJH
# cCcuAzANBglghkgBZQMEAgIFAKCCAVYwGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJ
# EAEEMBwGCSqGSIb3DQEJBTEPFw0yNjA5MDkxNjU4MzFaMDcGCyqGSIb3DQEJEAIv
# MSgwJjAkMCIEIIW+kOEK0kONfMkotq9IsJqyCBd87PiwEmxY05EFJcQ8MD8GCSqG
# SIb3DQEJBDEyBDCk4pc8k4uWDuJbPRd8AHKRboDwq+kEQ4SYLZzwpTgUyNiYZ/qI
# IapJDKveWE8ZLDswgZ8GCyqGSIb3DQEJEAIMMYGPMIGMMIGJMIGGBBRXFGhBDKha
# 80JO+RZKUTYQ9NONmDBuMFqkWDBWMQswCQYDVQQGEwJQTDEhMB8GA1UEChMYQXNz
# ZWNvIERhdGEgU3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0dW0gVGltZXN0YW1w
# aW5nIDIwMjEgQ0ECECjwd8EcNr3+X3QyR3AnLgMwDQYJKoZIhvcNAQEBBQAEggIA
# Z9HFskFS57/Z3QXDYpFKH+4IxthLKb7RIS2nHCfaGF3GUEDwB8gmN9tkdi58AGU8
# VR1SOORGT/6Q47S2xoztkX97sIAmURJjNADDFdu+GcZ2WOBdeWoJPMhtb7+JzXR4
# BubtgG/GBPlK2Wx4UnnCuOh04ILFoJmrtJluo0LWPFSJ0z7JtnLJg2hZLPg1QgWC
# y06H1dIIc/rhJUoIbZ5IX5+uWVut4v2bsT/f+hCztGCsYMwqFPBqqqHnr2xBur57
# wgELLEyhAZR3tK4taG6xJ2zyY0hndIaNqLsimdd37NVnQS9/ea5bGyagCYc4SrJq
# dBEMR0EgwK4Kc4Ji3ISDauxa31Az3QHxT/gtl9+dd0XiBDvpUN4h6tAHL3A+3XXw
# jPQk8rfASqs0dVafYDn9XyJRnQ/oLli0bWtJVx9W7oIDOiqVPYAWt5x4eKYxVXE7
# D5hyo1jnGp38twdKEivd0cH9xgRrxhgTx3mPho6nKxGbYDR8jot0aK91ntGfpqxP
# 3L68LB/fNiEr3EX2UjXcztXBn9gjBBeS1DO0osW5Ln4zYubzExTYQuEnAg6QqlNc
# TZV7xTpuDicgV+V8E5PL0m9CQIYhE4urK02f9eM3VKOUYGmq78uYuPugT3S5ephl
# ASemHv4ONkkbuJeNJ76OwoA0TZ/vg8iaOxL5t/KW4E0=
# SIG # End signature block
