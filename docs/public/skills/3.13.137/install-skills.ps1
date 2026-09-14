# Tina4 AI skills installer for Windows.
#
# Choose a target explicitly:
#   $env:TINA4_SKILLS_TARGET = "claude"; irm https://tina4.com/install-skills.ps1 | iex
#   $env:TINA4_SKILLS_TARGET = "codex"; irm https://tina4.com/install-skills.ps1 | iex
#   $env:TINA4_SKILLS_TARGET = "cursor"; irm https://tina4.com/install-skills.ps1 | iex
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

# Hosts that have stopped answering during THIS run.
#
# A host that is down stays down for the seconds an install takes, and there are 48
# files to fetch from three tiers. Without this, an outage costs a full retry walk
# per file per dead tier -- ($retryCount + 1) doomed requests and
# $retryCount x $retryDelay seconds, 48 times over -- to re-establish something the
# first file already proved.
$script:tina4DeadHosts = @()

# The unit that goes down is the host, not the path.
function Get-Tina4Host {
  param([Parameter(Mandatory = $true)][string]$Url)

  try {
    $parsed = [uri]$Url
    return "$($parsed.Scheme)://$($parsed.Authority)"
  } catch {
    return $Url
  }
}

# 0 when the request never got an HTTP answer at all -- refused, DNS, timeout.
function Get-Tina4StatusCode {
  param($ErrorRecord)

  # Both guards matter under Set-StrictMode, which a caller can have set: the
  # bootstrap runs this script through iex, in the caller's scope.
  $response = $null
  try {
    $response = $ErrorRecord.Exception.Response
  } catch {
    $response = $null
  }
  if ($null -eq $response) { return 0 }

  $code = 0
  try {
    $code = [int]$response.StatusCode
  } catch {
    $code = 0
  }
  return $code
}

# One full retry walk against one URL.
#
#   0  got it
#   1  this path is not on this host (4xx) -- says nothing about the next file, and
#      is expected while a tier is still catching up with a freshly published ref
#   2  the host is not answering (5xx, or no answer at all) -- which is equally true
#      for every file still to come, and is the only thing worth remembering
function Invoke-Tina4Fetch {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Destination
  )

  $code = 0
  for ($attempt = 0; $attempt -le $retryCount; $attempt++) {
    try {
      Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Destination
      return 0
    } catch {
      Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
      $code = Get-Tina4StatusCode $_
      if ($attempt -lt $retryCount) {
        Start-Sleep -Seconds $retryDelay
      }
    }
  }
  if ($code -eq 0 -or ($code -ge 500 -and $code -le 599)) {
    return 2
  }
  return 1
}

# Two passes. The first skips hosts already known to be down, which is what makes an
# outage cost one retry walk instead of 48. The second tries exactly those skipped
# hosts, so nothing is ever lost: a host is only skipped while another source is
# still worth trying, and if every remaining source fails, the run still attempts the
# skipped one before giving up.
function Invoke-Tina4Download {
  param(
    [Parameter(Mandatory = $true)][string[]]$Urls,
    [Parameter(Mandatory = $true)][string]$Destination
  )

  $skipped = @()
  foreach ($url in $Urls) {
    # Not $host: PowerShell already owns that name.
    $urlHost = Get-Tina4Host -Url $url
    if ($script:tina4DeadHosts -contains $urlHost) {
      $skipped += $url
      continue
    }
    $status = Invoke-Tina4Fetch -Url $url -Destination $Destination
    if ($status -eq 0) {
      return
    }
    if ($status -eq 2) {
      $script:tina4DeadHosts += $urlHost
      Write-Warning "$urlHost is not answering; using the next source for the rest of this run"
    } else {
      Write-Warning "Not served by $urlHost, trying next source: $url"
    }
  }

  foreach ($url in $skipped) {
    if ((Invoke-Tina4Fetch -Url $url -Destination $Destination) -eq 0) {
      return
    }
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
# MIIpMgYJKoZIhvcNAQcCoIIpIzCCKR8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCACj08K4vwINMe8
# sJWTQWCT4j9DEnKg4qDJKxMzyWaHr6CCDcgwggbNMIIEtaADAgECAhEAu/DMtbe4
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
# C6sxghrAMIIavAIBATB+MGoxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28g
# RGF0YSBTeXN0ZW1zIFMuQS4xODA2BgNVBAMTL0NlcnR1bSBFeHRlbmRlZCBWYWxp
# ZGF0aW9uIENvZGUgU2lnbmluZyAyMDIxIENBAhBSHYi/fckVnuNEWGHbEmHGMA0G
# CWCGSAFlAwQCAQUAoHwwEAYKKwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZI
# hvcNAQkEMSIEIPy/3cR+dZKy06dOppQ5vqU5LA2w7ZMuMv/Im+TCZxMTMA0GCSqG
# SIb3DQEBAQUABIIBgArMblDHaVJFjxltTpH7oBsnSeOR22pwrDgl9jmA6+7G321j
# 4Q4CQpVwVr0uVESm4zbvKZZ7GHY+hEcAs5JaCAI9Q2Zc2eJkkR4kSZMD5hl5b3na
# 7oYrCbyt49WjQSzeZfrNyVK5r+O+ZbBM0X3rXl65CKAxnjc3G5ZmQm2U7si+ulGP
# Wmix+e5EE4Vc1sFIpXoBssTxP2G6RjlGE/owljCa+rL/+Dq0pMBOa26BY4KpapmG
# Woj40FPWU6Er9LYGpA6DEkZKGEHxCtGeJlsluN9qEj2YxActkh0qb3cJYye7k8Jy
# Xim1VoWuVGsiNB82nH3ss19JlgdnhDI9FXx+e6/VJV3QQPw+4gt8GCJHUYdPUSSi
# WBglCf3ROWL7k0G0PeIQGJ4A9nrRgFCCUnEkMNSwS0qBnnaBIEgiW5VLm8/vf9H7
# Whq5P6fjXblezrZJG34lLyAPpApGTZicnEG6phSlEmBXNPP7UWWBs36OJ0XK22Zz
# dUFWSJ3rFxsqQAW5aqGCGBUwghgRBgorBgEEAYI3AwMBMYIYATCCF/0GCSqGSIb3
# DQEHAqCCF+4wghfqAgEDMQ0wCwYJYIZIAWUDBAICMIHOBgsqhkiG9w0BCRABBKCB
# vgSBuzCBuAIBAQYLKoRoAYb2dwIFAQswMTANBglghkgBZQMEAgEFAAQg9YJ/UFwq
# fDXwdquYDgC/BZL6feJgl/r4tOizZC4HiOMCBwqofHFyidgYDzIwMjYwOTE0MDkz
# NTIwWjADAgEBoFSkUjBQMQswCQYDVQQGEwJQTDEhMB8GA1UECgwYQXNzZWNvIERh
# dGEgU3lzdGVtcyBTLkEuMR4wHAYDVQQDDBVDZXJ0dW0gVGltZXN0YW1wIDIwMjag
# ghMQMIIGgjCCBGqgAwIBAgIQKPB3wRw2vf5fdDJHcCcuAzANBgkqhkiG9w0BAQwF
# ADBWMQswCQYDVQQGEwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEgU3lzdGVtcyBT
# LkEuMSQwIgYDVQQDExtDZXJ0dW0gVGltZXN0YW1waW5nIDIwMjEgQ0EwHhcNMjYw
# MzExMDczNDU0WhcNMzYwMjI3MDczNDU0WjBQMQswCQYDVQQGEwJQTDEhMB8GA1UE
# CgwYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMR4wHAYDVQQDDBVDZXJ0dW0gVGlt
# ZXN0YW1wIDIwMjYwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC4vc3w
# cPsSNdoYthfbjUATTkk5EyItd37odw4lsmyOd/dmwXycOrTu8w7O1Kj/63o1X+MR
# U1N1zTj7LjhZD+UjxbJ1sJ91SS/jYTYbLro72LELWkJ7zaNcJOOq3k4MLNS/DhRH
# SmsYMqk+MzkMfNZi8DWUqlzVPUa2/aACViReDMnc/gtXm7tA9Pr4DN7agEPE1NtN
# 36oCgj6iHR5aGhah/XskfvLZ6ZstoZ5zefWTrZrLh3kcH+YkzoZYX9Hf6qqrizki
# Bj4BlS9R4+VwVKMdjhO7UEa/pf8cTWy+jrsATuAGthG7sWIN+3KV7+Ytv5Uy+DQE
# gf3bn/VuH4wN0aPhj/mwueJ9jmIjNwqvM/dno8fBeR1jtnuP++XgveQfbTMP3qu9
# dPRg8ltvtrreQZ9KPDFyUxEZMsrLVm6nJ1JKJgPe6n4gwsL6VrjjHX0zpLF3vUvs
# Q8TiWgm4sk4r4D7pcXE/rX0E0Vwa+VMLT73PiDZ2nzhIpc1RwNdbb/qR3Mpa8sQX
# NPHFIoX/7bapGUtG5sd1cUGsvLqIWk6dP/xAgPb2BludUinSTCYV7ysiHQS8vFmD
# XIU7fMkSE7/QHcYPSahro4fk5z9W1t2kIxbZRJe0s4DXiPDlQPwiQFllLkU9wLvU
# 6DqR8v35a65J4TeIXhMO/+iCzL+B0rI9GGeKLQIDAQABo4IBUDCCAUwwdQYIKwYB
# BQUHAQEEaTBnMDsGCCsGAQUFBzAChi9odHRwOi8vc3ViY2EucmVwb3NpdG9yeS5j
# ZXJ0dW0ucGwvY3RzY2EyMDIxLmNlcjAoBggrBgEFBQcwAYYcaHR0cDovL3N1YmNh
# Lm9jc3AtY2VydHVtLmNvbTAfBgNVHSMEGDAWgBS+VAIvv0Bsc0POrAklTp5DRBru
# 4DAMBgNVHRMBAf8EAjAAMDkGA1UdHwQyMDAwLqAsoCqGKGh0dHA6Ly9zdWJjYS5j
# cmwuY2VydHVtLnBsL2N0c2NhMjAyMS5jcmwwFgYDVR0lAQH/BAwwCgYIKwYBBQUH
# AwgwDgYDVR0PAQH/BAQDAgeAMCIGA1UdIAQbMBkwCAYGZ4EMAQQCMA0GCyqEaAGG
# 9ncCBQELMB0GA1UdDgQWBBQjOWooq5oSp6Sn8h/5RZq/jf6CAzANBgkqhkiG9w0B
# AQwFAAOCAgEAZv6Tm6wL3k6mBTwkrYcTVcAR01uE37gUGNihgnTJR+gC41T2H9lw
# ETRjE10nEdCUNv3Ni8S6aBx4UcMRX93fd9w4RUteua2I+oj0kCpuNa3PQDKUwozH
# ZmotWivaPO9KTs08y0YVhVSMZvuUH/reFec9eLT6FLAFnX0Sg9Wc7833uQB5RPa8
# TmXBkTolC8bNxHX+2SfEWSNI8w/Y7o9qBF9l0uwVSrjQitVtIdZo2qb9NvMqqPFL
# WYef9SG+PGMqfPAQ2EoYeT0hlFLkubWF1X3HbiDwXtz3TU2EWHU+VTcZMC4IzMyH
# K/+kh9n3oxSQ45wsY71y7mqxKyYPyHSPoV3RiAQ1Thr9c65BeJLaELxWSKeQyAGI
# dBsMlIXPO6qp+VGmE49vosogQ0jYe2hgq5LgJ6oO0Ie364V/kITBnifUqS6Zxu+q
# jfOYS8o72EeoEWIi04/BuH8Y6leNNP27j8NKwaPciWcqv/HBnQjizzmH/aqXn03K
# 2SnjvaYPlCR8fFAAW2k6os0cZvLFEhMnHHAghYSIrdwCP98BrkjgA3ogOu+jXEO/
# nbD9OGL873Te6U2TcoOu9lqQQyXYNHiLR5eMqJrzXiDlodarOEKjlukyPDnLIuLk
# g0y6K8S1A5wU8CkM86cXdWFHLRIEYd9kdCfRZBZHhK7iVPeEZYxa9bgwgga5MIIE
# oaADAgECAhEA5/9pxzs1zkuRJth0fGilhzANBgkqhkiG9w0BAQwFADCBgDELMAkG
# A1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAl
# BgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMb
# Q2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMB4XDTIxMDUxOTA1MzIwN1oXDTM2
# MDUxODA1MzIwN1owVjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRh
# IFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGluZyAyMDIx
# IENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA6RIfBDXtuV16xaaV
# Qb6KZX9Od9FtJXXTZo7b+GEof3+3g0ChWiKnO7R4+6MfrvLyLCWZa6GpFHjEt4t0
# /GiUQvnkLOBRdBqr5DOvlmTvJJs2X8ZmWgWJjC7PBZLYBWAs8sJl3kNXxBMX5Xnt
# jqWx1ZOuuXl0R4x+zGGSMzZ45dpvB8vLpQfZkfMC/1tL9KYyjU+htLH68dZJPtzh
# qLBVG+8ljZ1ZFilOKksS79epCeqFSeAUm2eMTGpOiS3gfLM6yvb8Bg6bxg5yglDG
# C9zbr4sB9ceIGRtCQF1N8dqTgM/dSViiUgJkcv5dLNJeWxGCqJYPgzKlYZTgDXfG
# IeZpEFmjBLwURP5ABsyKoFocMzdjrCiFbTvJn+bD1kq78qZUgAQGGtd6zGJ88H4N
# PJ5Y2R4IargiWAmv8RyvWnHr/VA+2PrrK9eXe5q7M88YRdSTq9TKbqdnITUgZcjj
# m4ZUjteq8K331a4P0s2in0p3UubMEYa/G5w6jSWPUzchGLwWKYBfeSu6dIOC4Lke
# APvmdZxSB1lWOb9HzVWZoM8Q/blaP4LWt6JxjkI9yQsYGMdCqwl7uMnPUIlcExS1
# mzXRxUowQref/EPaS7kYVaHHQrp4XB7nTEtQhkP0Z9Puz/n8zIFnUSnxDof4Yy65
# 0PAXSYmK2TcbyDoTNmmt8xAxzcMCAwEAAaOCAVUwggFRMA8GA1UdEwEB/wQFMAMB
# Af8wHQYDVR0OBBYEFL5UAi+/QGxzQ86sCSVOnkNEGu7gMB8GA1UdIwQYMBaAFLah
# VDkCw6A/joq8+tT4HKbROg79MA4GA1UdDwEB/wQEAwIBBjATBgNVHSUEDDAKBggr
# BgEFBQcDCDAwBgNVHR8EKTAnMCWgI6Ahhh9odHRwOi8vY3JsLmNlcnR1bS5wbC9j
# dG5jYTIuY3JsMGwGCCsGAQUFBwEBBGAwXjAoBggrBgEFBQcwAYYcaHR0cDovL3N1
# YmNhLm9jc3AtY2VydHVtLmNvbTAyBggrBgEFBQcwAoYmaHR0cDovL3JlcG9zaXRv
# cnkuY2VydHVtLnBsL2N0bmNhMi5jZXIwOQYDVR0gBDIwMDAuBgRVHSAAMCYwJAYI
# KwYBBQUHAgEWGGh0dHA6Ly93d3cuY2VydHVtLnBsL0NQUzANBgkqhkiG9w0BAQwF
# AAOCAgEAuJNZd8lMFf2UBwigp3qgLPBBk58BFCS3Q6aJDf3TISoytK0eal/JyCB8
# 8aUEd0wMNiEcNVMbK9j5Yht2whaknUE1G32k6uld7wcxHmw67vUBY6pSp8QhdodY
# 4SzRRaZWzyYlviUpyU4dXyhKhHSncYJfa1U75cXxCe3sTp9uTBm3f8Bj8LkpjMUS
# VTtMJ6oEu5JqCYzRfc6nnoRUgwz/GVZFoOBGdrSEtDN7mZgcka/tS5MI47fALVvN
# 5lZ2U8k7Dm/hTX8CWOw0uBZloZEW4HB0Xra3qE4qzzq/6M8gyoU/DE0k3+i7bYOr
# Ok/7tPJg1sOhytOGUQ30PbG++0FfJioDuOFhj99b151SqFlSaRQYz74y/P2XJP+c
# F19oqozmi0rRTkfyEJIvhIZ+M5XIFZttmVQgTxfpfJwMFFEoQrSrklOxpmSygpps
# UDJEoliC05vBLVQ+gMZyYaKvBJ4YxBMlKH5ZHkRdloRYlUDplk8GUa+OCMVhpDSQ
# urU6K1ua5dmZftnvSSz2H96UrQDzA6DyiI1V3ejVtvn2azVAXg6NnjmuRZ+wa7Px
# y0H3+V4K4rOTHlG3VYA6xfLsTunCz72T6Ot4+tkrDYOeaU1pPX1CBfYj6EW2+ELq
# 46GP8KCNUQDirWLU4nOmgCat7vN0SD6RlwUiSsMeCiQDmZwgwrUwggXJMIIEsaAD
# AgECAhAbtY8lKt8jAEkoya49fu0nMA0GCSqGSIb3DQEBDAUAMH4xCzAJBgNVBAYT
# AlBMMSIwIAYDVQQKExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQL
# Ex5DZXJ0dW0gQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxIjAgBgNVBAMTGUNlcnR1
# bSBUcnVzdGVkIE5ldHdvcmsgQ0EwHhcNMjEwNTMxMDY0MzA2WhcNMjkwOTE3MDY0
# MzA2WjCBgDELMAkGA1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9n
# aWVzIFMuQS4xJzAlBgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0
# eTEkMCIGA1UEAxMbQ2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAvfl4+ObVgAxknYYblmRnPyI6HnUBfe/7
# XGeMycxca6mR5rlC5SBLm9qbe7mZXdmbgEvXhEArJ9PoujC7Pgkap0mV7ytAJMKX
# x6fumyXvqAoAl4Vaqp3cKcniNQfrcE1K1sGzVrihQTib0fsxf4/gX+GxPw+OFklg
# 1waNGPmqJhCrKtPQ0WeNG0a+RzDVLnLRxWPa52N5RH5LYySJhi40PylMUosqp8Di
# kSiJucBb+R3Z5yet/5oCl8HGUJKbAiy9qbk0WQq/hEr/3/6zn+vZnuCYI+yma3cW
# KtvMrTscpIfcRnNeGWJoRVfkkIJCu0LW8GHgwaM9ZqNd9BjuiMmNF0UpmTJ1AjHu
# KSbIawLmtWJFfzcVWiNoidQ+3k4nsPBADLxNF8tNorMe0AZa3faTz1d1mfX6hhpn
# eLO/lv403L3nUlbls+V1e9dBkQXcXWnjlQ1DufyDljmVe2yAWk8TcsbXfSl6RLpS
# pCrVQUYJIP4ioLZbMI28iQzV13D4h1L92u+sUS4Hs07+0AnacO+Y+lbmbdu1V0vc
# 5SwlFcieLnhO+NqcnoYsylfzGuXIkosagpZ6w7xQEmnYDlpGizrrJvojybawgb5C
# AKT41v4wLsfSRvbljnX98sy50IdbzAYQYLuDNbdeZ95H7JlI8aShFf6tjGKOOVVP
# ORa5sWOd/7cCAwEAAaOCAT4wggE6MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE
# FLahVDkCw6A/joq8+tT4HKbROg79MB8GA1UdIwQYMBaAFAh2zcsH/yT2xc3tu5C8
# 4oQ3RnX3MA4GA1UdDwEB/wQEAwIBBjAvBgNVHR8EKDAmMCSgIqAghh5odHRwOi8v
# Y3JsLmNlcnR1bS5wbC9jdG5jYS5jcmwwawYIKwYBBQUHAQEEXzBdMCgGCCsGAQUF
# BzABhhxodHRwOi8vc3ViY2Eub2NzcC1jZXJ0dW0uY29tMDEGCCsGAQUFBzAChiVo
# dHRwOi8vcmVwb3NpdG9yeS5jZXJ0dW0ucGwvY3RuY2EuY2VyMDkGA1UdIAQyMDAw
# LgYEVR0gADAmMCQGCCsGAQUFBwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9DUFMw
# DQYJKoZIhvcNAQEMBQADggEBAFHCoVgWIhCL/IYx1MIy01z4S6Ivaj5N+KsIHu3V
# 6PrnCA3st8YeDrJ1BXqxC/rXdGoABh+kzqrya33YEcARCNQOTWHFOqj6seHjmOri
# Y/1B9ZN9DbxdkjuRmmW60F9MvkyNaAMQFtXx0ASKhTP5N+dbLiZpQjy6zbzUeulN
# ndrnQ/tjUoCFBMQllVXwfqefAcVbKPjgzoZwpic7Ofs4LphTZSJ1Ldf23SIikZbr
# 3WjtP6MZl9M7JYjsNhI9qX7OAo0FmpKnJ25FspxihjcNpDOO16hO0EoXQ0zF8ads
# 0h5YbBRRfopUofbvn3l6XYGaFpAP4bvxSgD5+d2+7arszgoxggPvMIID6wIBATBq
# MFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMu
# QS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1lc3RhbXBpbmcgMjAyMSBDQQIQKPB3wRw2
# vf5fdDJHcCcuAzANBglghkgBZQMEAgIFAKCCAVYwGgYJKoZIhvcNAQkDMQ0GCyqG
# SIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNjA5MTQwOTM1MjBaMDcGCyqGSIb3
# DQEJEAIvMSgwJjAkMCIEIIW+kOEK0kONfMkotq9IsJqyCBd87PiwEmxY05EFJcQ8
# MD8GCSqGSIb3DQEJBDEyBDCg+FK1qftpGu/eXUzABosK0l6fFoDYcOP+LhgzGdxG
# IOcYQAvjqfsOEMCQLacA1/QwgZ8GCyqGSIb3DQEJEAIMMYGPMIGMMIGJMIGGBBRX
# FGhBDKha80JO+RZKUTYQ9NONmDBuMFqkWDBWMQswCQYDVQQGEwJQTDEhMB8GA1UE
# ChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0dW0gVGlt
# ZXN0YW1waW5nIDIwMjEgQ0ECECjwd8EcNr3+X3QyR3AnLgMwDQYJKoZIhvcNAQEB
# BQAEggIAMXQyJh87JESGNNCqFdDomRKEWqIHlRHJoOeIn8Vj9qId2IsnOBmkC60F
# Bsxon29xX0pbRnnPLkba2eAAEuC7ZlhN5BiJFCMR4gVNQbyeG3dGckUj/N4FBVL5
# eZ6/aGt+5cuFPSIZNTZtUnmOO0D3Jl5/ypKuR1xpelvHczAvPPc5IcgsI88jAA+F
# sXpH7FOno9tqNjQGOKH9DyOAjHag+WOme4rifZJ2Os2SNC3SeFDkXhsu2F6uyZyx
# AN/mFMnpDE9EsYtaMH83G7FqGaePTFbgAfAldC5xticfNUlrnNJymqZDjjb6d6Pd
# r/liUUUoEaocflx4haJe/6k9jvyFwvkmPh9VuD9bCawRQeUwGD9zLn844mKD/SPA
# qXUO6z07C/jBD34MUK65VUuYJw6+J+xv/FQxF0UNL8f46rkW80KwZeYOa774VoQ8
# qdqtp0AT/Hn+3BmkThoz68QXts2cmf8wwGJ+H//qRagwwBnSkgw3LA/Pm3TwO/JE
# yEJll2gg5FVE9rNkWSylta94IMfxxHnwllSCtXi3JxImEPfpd/6CaK/UffbwlVTA
# 9x65uXUUwgX76HJ2xQL8u6M9kxZG2Khbfr5rpAPgIvv5oYxy+vm8nbZ9AcTYSGyj
# iYVgn2fJG97anbYW/X8of/DjKgMX4Zcmnu9BD3pyO8+hjCA9MVo=
# SIG # End signature block
