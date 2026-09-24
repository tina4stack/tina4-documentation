# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
$ref = if ($env:TINA4_SKILLS_REF) { $env:TINA4_SKILLS_REF } else { "3.13.138" }
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
# MIIoHQYJKoZIhvcNAQcCoIIoDjCCKAoCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCl8Gc9GpnE7qLb
# mrkAtDLnqoDldoSZ9XqhSztxVwn5fKCCINgwggXJMIIEsaADAgECAhAbtY8lKt8j
# AEkoya49fu0nMA0GCSqGSIb3DQEBDAUAMH4xCzAJBgNVBAYTAlBMMSIwIAYDVQQK
# ExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkxIjAgBgNVBAMTGUNlcnR1bSBUcnVzdGVkIE5l
# dHdvcmsgQ0EwHhcNMjEwNTMxMDY0MzA2WhcNMjkwOTE3MDY0MzA2WjCBgDELMAkG
# A1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAl
# BgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMb
# Q2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEAvfl4+ObVgAxknYYblmRnPyI6HnUBfe/7XGeMycxca6mR5rlC
# 5SBLm9qbe7mZXdmbgEvXhEArJ9PoujC7Pgkap0mV7ytAJMKXx6fumyXvqAoAl4Va
# qp3cKcniNQfrcE1K1sGzVrihQTib0fsxf4/gX+GxPw+OFklg1waNGPmqJhCrKtPQ
# 0WeNG0a+RzDVLnLRxWPa52N5RH5LYySJhi40PylMUosqp8DikSiJucBb+R3Z5yet
# /5oCl8HGUJKbAiy9qbk0WQq/hEr/3/6zn+vZnuCYI+yma3cWKtvMrTscpIfcRnNe
# GWJoRVfkkIJCu0LW8GHgwaM9ZqNd9BjuiMmNF0UpmTJ1AjHuKSbIawLmtWJFfzcV
# WiNoidQ+3k4nsPBADLxNF8tNorMe0AZa3faTz1d1mfX6hhpneLO/lv403L3nUlbl
# s+V1e9dBkQXcXWnjlQ1DufyDljmVe2yAWk8TcsbXfSl6RLpSpCrVQUYJIP4ioLZb
# MI28iQzV13D4h1L92u+sUS4Hs07+0AnacO+Y+lbmbdu1V0vc5SwlFcieLnhO+Nqc
# noYsylfzGuXIkosagpZ6w7xQEmnYDlpGizrrJvojybawgb5CAKT41v4wLsfSRvbl
# jnX98sy50IdbzAYQYLuDNbdeZ95H7JlI8aShFf6tjGKOOVVPORa5sWOd/7cCAwEA
# AaOCAT4wggE6MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFLahVDkCw6A/joq8
# +tT4HKbROg79MB8GA1UdIwQYMBaAFAh2zcsH/yT2xc3tu5C84oQ3RnX3MA4GA1Ud
# DwEB/wQEAwIBBjAvBgNVHR8EKDAmMCSgIqAghh5odHRwOi8vY3JsLmNlcnR1bS5w
# bC9jdG5jYS5jcmwwawYIKwYBBQUHAQEEXzBdMCgGCCsGAQUFBzABhhxodHRwOi8v
# c3ViY2Eub2NzcC1jZXJ0dW0uY29tMDEGCCsGAQUFBzAChiVodHRwOi8vcmVwb3Np
# dG9yeS5jZXJ0dW0ucGwvY3RuY2EuY2VyMDkGA1UdIAQyMDAwLgYEVR0gADAmMCQG
# CCsGAQUFBwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9DUFMwDQYJKoZIhvcNAQEM
# BQADggEBAFHCoVgWIhCL/IYx1MIy01z4S6Ivaj5N+KsIHu3V6PrnCA3st8YeDrJ1
# BXqxC/rXdGoABh+kzqrya33YEcARCNQOTWHFOqj6seHjmOriY/1B9ZN9DbxdkjuR
# mmW60F9MvkyNaAMQFtXx0ASKhTP5N+dbLiZpQjy6zbzUeulNndrnQ/tjUoCFBMQl
# lVXwfqefAcVbKPjgzoZwpic7Ofs4LphTZSJ1Ldf23SIikZbr3WjtP6MZl9M7JYjs
# NhI9qX7OAo0FmpKnJ25FspxihjcNpDOO16hO0EoXQ0zF8ads0h5YbBRRfopUofbv
# n3l6XYGaFpAP4bvxSgD5+d2+7arszgowggaCMIIEaqADAgECAhAo8HfBHDa9/l90
# MkdwJy4DMA0GCSqGSIb3DQEBDAUAMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhB
# c3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1lc3Rh
# bXBpbmcgMjAyMSBDQTAeFw0yNjAzMTEwNzM0NTRaFw0zNjAyMjcwNzM0NTRaMFAx
# CzAJBgNVBAYTAlBMMSEwHwYDVQQKDBhBc3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4x
# HjAcBgNVBAMMFUNlcnR1bSBUaW1lc3RhbXAgMjAyNjCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBALi9zfBw+xI12hi2F9uNQBNOSTkTIi13fuh3DiWybI53
# 92bBfJw6tO7zDs7UqP/rejVf4xFTU3XNOPsuOFkP5SPFsnWwn3VJL+NhNhsuujvY
# sQtaQnvNo1wk46reTgws1L8OFEdKaxgyqT4zOQx81mLwNZSqXNU9Rrb9oAJWJF4M
# ydz+C1ebu0D0+vgM3tqAQ8TU203fqgKCPqIdHloaFqH9eyR+8tnpmy2hnnN59ZOt
# msuHeRwf5iTOhlhf0d/qqquLOSIGPgGVL1Hj5XBUox2OE7tQRr+l/xxNbL6OuwBO
# 4Aa2EbuxYg37cpXv5i2/lTL4NASB/duf9W4fjA3Ro+GP+bC54n2OYiM3Cq8z92ej
# x8F5HWO2e4/75eC95B9tMw/eq7109GDyW2+2ut5Bn0o8MXJTERkyystWbqcnUkom
# A97qfiDCwvpWuOMdfTOksXe9S+xDxOJaCbiyTivgPulxcT+tfQTRXBr5UwtPvc+I
# NnafOEilzVHA11tv+pHcylryxBc08cUihf/ttqkZS0bmx3VxQay8uohaTp0//ECA
# 9vYGW51SKdJMJhXvKyIdBLy8WYNchTt8yRITv9Adxg9JqGujh+TnP1bW3aQjFtlE
# l7SzgNeI8OVA/CJAWWUuRT3Au9ToOpHy/flrrknhN4heEw7/6ILMv4HSsj0YZ4ot
# AgMBAAGjggFQMIIBTDB1BggrBgEFBQcBAQRpMGcwOwYIKwYBBQUHMAKGL2h0dHA6
# Ly9zdWJjYS5yZXBvc2l0b3J5LmNlcnR1bS5wbC9jdHNjYTIwMjEuY2VyMCgGCCsG
# AQUFBzABhhxodHRwOi8vc3ViY2Eub2NzcC1jZXJ0dW0uY29tMB8GA1UdIwQYMBaA
# FL5UAi+/QGxzQ86sCSVOnkNEGu7gMAwGA1UdEwEB/wQCMAAwOQYDVR0fBDIwMDAu
# oCygKoYoaHR0cDovL3N1YmNhLmNybC5jZXJ0dW0ucGwvY3RzY2EyMDIxLmNybDAW
# BgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4AwIgYDVR0gBBsw
# GTAIBgZngQwBBAIwDQYLKoRoAYb2dwIFAQswHQYDVR0OBBYEFCM5aiirmhKnpKfy
# H/lFmr+N/oIDMA0GCSqGSIb3DQEBDAUAA4ICAQBm/pObrAveTqYFPCSthxNVwBHT
# W4TfuBQY2KGCdMlH6ALjVPYf2XARNGMTXScR0JQ2/c2LxLpoHHhRwxFf3d933DhF
# S165rYj6iPSQKm41rc9AMpTCjMdmai1aK9o870pOzTzLRhWFVIxm+5Qf+t4V5z14
# tPoUsAWdfRKD1Zzvzfe5AHlE9rxOZcGROiULxs3Edf7ZJ8RZI0jzD9juj2oEX2XS
# 7BVKuNCK1W0h1mjapv028yqo8UtZh5/1Ib48Yyp88BDYShh5PSGUUuS5tYXVfcdu
# IPBe3PdNTYRYdT5VNxkwLgjMzIcr/6SH2fejFJDjnCxjvXLuarErJg/IdI+hXdGI
# BDVOGv1zrkF4ktoQvFZIp5DIAYh0GwyUhc87qqn5UaYTj2+iyiBDSNh7aGCrkuAn
# qg7Qh7frhX+QhMGeJ9SpLpnG76qN85hLyjvYR6gRYiLTj8G4fxjqV400/buPw0rB
# o9yJZyq/8cGdCOLPOYf9qpefTcrZKeO9pg+UJHx8UABbaTqizRxm8sUSEycccCCF
# hIit3AI/3wGuSOADeiA676NcQ7+dsP04YvzvdN7pTZNyg672WpBDJdg0eItHl4yo
# mvNeIOWh1qs4QqOW6TI8Ocsi4uSDTLorxLUDnBTwKQzzpxd1YUctEgRh32R0J9Fk
# FkeEruJU94RljFr1uDCCBrkwggShoAMCAQICEQDn/2nHOzXOS5Em2HR8aKWHMA0G
# CSqGSIb3DQEBDAUAMIGAMQswCQYDVQQGEwJQTDEiMCAGA1UEChMZVW5pemV0byBU
# ZWNobm9sb2dpZXMgUy5BLjEnMCUGA1UECxMeQ2VydHVtIENlcnRpZmljYXRpb24g
# QXV0aG9yaXR5MSQwIgYDVQQDExtDZXJ0dW0gVHJ1c3RlZCBOZXR3b3JrIENBIDIw
# HhcNMjEwNTE5MDUzMjA3WhcNMzYwNTE4MDUzMjA3WjBWMQswCQYDVQQGEwJQTDEh
# MB8GA1UEChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0
# dW0gVGltZXN0YW1waW5nIDIwMjEgQ0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAw
# ggIKAoICAQDpEh8ENe25XXrFppVBvoplf0530W0lddNmjtv4YSh/f7eDQKFaIqc7
# tHj7ox+u8vIsJZlroakUeMS3i3T8aJRC+eQs4FF0GqvkM6+WZO8kmzZfxmZaBYmM
# Ls8FktgFYCzywmXeQ1fEExflee2OpbHVk665eXRHjH7MYZIzNnjl2m8Hy8ulB9mR
# 8wL/W0v0pjKNT6G0sfrx1kk+3OGosFUb7yWNnVkWKU4qSxLv16kJ6oVJ4BSbZ4xM
# ak6JLeB8szrK9vwGDpvGDnKCUMYL3NuviwH1x4gZG0JAXU3x2pOAz91JWKJSAmRy
# /l0s0l5bEYKolg+DMqVhlOANd8Yh5mkQWaMEvBRE/kAGzIqgWhwzN2OsKIVtO8mf
# 5sPWSrvyplSABAYa13rMYnzwfg08nljZHghquCJYCa/xHK9acev9UD7Y+usr15d7
# mrszzxhF1JOr1Mpup2chNSBlyOObhlSO16rwrffVrg/SzaKfSndS5swRhr8bnDqN
# JY9TNyEYvBYpgF95K7p0g4LguR4A++Z1nFIHWVY5v0fNVZmgzxD9uVo/gta3onGO
# Qj3JCxgYx0KrCXu4yc9QiVwTFLWbNdHFSjBCt5/8Q9pLuRhVocdCunhcHudMS1CG
# Q/Rn0+7P+fzMgWdRKfEOh/hjLrnQ8BdJiYrZNxvIOhM2aa3zEDHNwwIDAQABo4IB
# VTCCAVEwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUvlQCL79AbHNDzqwJJU6e
# Q0Qa7uAwHwYDVR0jBBgwFoAUtqFUOQLDoD+Oirz61PgcptE6Dv0wDgYDVR0PAQH/
# BAQDAgEGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMDAGA1UdHwQpMCcwJaAjoCGGH2h0
# dHA6Ly9jcmwuY2VydHVtLnBsL2N0bmNhMi5jcmwwbAYIKwYBBQUHAQEEYDBeMCgG
# CCsGAQUFBzABhhxodHRwOi8vc3ViY2Eub2NzcC1jZXJ0dW0uY29tMDIGCCsGAQUF
# BzAChiZodHRwOi8vcmVwb3NpdG9yeS5jZXJ0dW0ucGwvY3RuY2EyLmNlcjA5BgNV
# HSAEMjAwMC4GBFUdIAAwJjAkBggrBgEFBQcCARYYaHR0cDovL3d3dy5jZXJ0dW0u
# cGwvQ1BTMA0GCSqGSIb3DQEBDAUAA4ICAQC4k1l3yUwV/ZQHCKCneqAs8EGTnwEU
# JLdDpokN/dMhKjK0rR5qX8nIIHzxpQR3TAw2IRw1Uxsr2PliG3bCFqSdQTUbfaTq
# 6V3vBzEebDru9QFjqlKnxCF2h1jhLNFFplbPJiW+JSnJTh1fKEqEdKdxgl9rVTvl
# xfEJ7exOn25MGbd/wGPwuSmMxRJVO0wnqgS7kmoJjNF9zqeehFSDDP8ZVkWg4EZ2
# tIS0M3uZmByRr+1Lkwjjt8AtW83mVnZTyTsOb+FNfwJY7DS4FmWhkRbgcHRetreo
# TirPOr/ozyDKhT8MTSTf6Lttg6s6T/u08mDWw6HK04ZRDfQ9sb77QV8mKgO44WGP
# 31vXnVKoWVJpFBjPvjL8/Zck/5wXX2iqjOaLStFOR/IQki+Ehn4zlcgVm22ZVCBP
# F+l8nAwUUShCtKuSU7GmZLKCmmxQMkSiWILTm8EtVD6AxnJhoq8EnhjEEyUoflke
# RF2WhFiVQOmWTwZRr44IxWGkNJC6tTorW5rl2Zl+2e9JLPYf3pStAPMDoPKIjVXd
# 6NW2+fZrNUBeDo2eOa5Fn7Brs/HLQff5Xgris5MeUbdVgDrF8uxO6cLPvZPo63j6
# 2SsNg55pTWk9fUIF9iPoRbb4QurjoY/woI1RAOKtYtTic6aAJq3u83RIPpGXBSJK
# wx4KJAOZnCDCtTCCBs0wggS1oAMCAQICEQC78My1t7gx/SGuMneK5AyJMA0GCSqG
# SIb3DQEBDAUAMIGAMQswCQYDVQQGEwJQTDEiMCAGA1UEChMZVW5pemV0byBUZWNo
# bm9sb2dpZXMgUy5BLjEnMCUGA1UECxMeQ2VydHVtIENlcnRpZmljYXRpb24gQXV0
# aG9yaXR5MSQwIgYDVQQDExtDZXJ0dW0gVHJ1c3RlZCBOZXR3b3JrIENBIDIwHhcN
# MjEwNTE5MDUzMjEzWhcNMzYwNTE4MDUzMjEzWjBqMQswCQYDVQQGEwJQTDEhMB8G
# A1UEChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMTgwNgYDVQQDEy9DZXJ0dW0g
# RXh0ZW5kZWQgVmFsaWRhdGlvbiBDb2RlIFNpZ25pbmcgMjAyMSBDQTCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBAJS++PCWqN/1551FMr42hq9mVXGZBM8g
# 3WcrldBFRBbI9bAcPnjBrZoPaREOsCMF/vX9PRc306qazkwv8miWCvK/clbv/JqG
# nuWD/Cfc8Oc3DMLUGUUzIJ0SS1CZRcyYTiabFK61FjU4YZqAQ1Y+NtDVH/Hge5MH
# JZsb5NRXt0g/ETtMzL02lyjh/T0M3pAVFd2TttlO7nyTG7owUfqbNCQLche8TF+j
# Rz8JPj+FNkPZeSceNcvOL2PMidIdL0ZCp5d3qdZuTAS7vOcqk0RxISWisNIRxGFz
# U5I4uNQrTHRw7DzCHNDR9YaQ+iqAKyVuNmiSjtTuSP8WfhNZDyzvkseOFVqj7DZJ
# Yw/QQtZgiSrUKiYarfCoEPtVTqu0IOhR/bfseSBEHEtcWPCnjjigpadyFgxnt6lZ
# fyOqe1KvhAd6J0vvZzpezBAghmwWCVXgE7byM7TbJLvDiLJjRzo9CzfgZntJamGw
# 3UNqJf3KxzqGi9VihUD3i37enhMjVG0r0DKHRq2Z9g8mq0F+TmQnWHic1rHSVmYk
# v1yEmNlBv7tdbwxCCy2JB2x6BrPZAvoR2b73g3whbpNhpqXI70t5HfkD0yhMujv2
# t0HTidpOpZ09MEqHsOlLndkBCfl1izal6v6btl4jGcRZo1wb49tGH5myUVvozvkm
# A3jezMH79VhVAgMBAAGjggFVMIIBUTAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW
# BBSsV8oIFtw/xTEcCk3b+/HemSctNDAfBgNVHSMEGDAWgBS2oVQ5AsOgP46KvPrU
# +Bym0ToO/TAOBgNVHQ8BAf8EBAMCAQYwEwYDVR0lBAwwCgYIKwYBBQUHAwMwMAYD
# VR0fBCkwJzAloCOgIYYfaHR0cDovL2NybC5jZXJ0dW0ucGwvY3RuY2EyLmNybDBs
# BggrBgEFBQcBAQRgMF4wKAYIKwYBBQUHMAGGHGh0dHA6Ly9zdWJjYS5vY3NwLWNl
# cnR1bS5jb20wMgYIKwYBBQUHMAKGJmh0dHA6Ly9yZXBvc2l0b3J5LmNlcnR1bS5w
# bC9jdG5jYTIuY2VyMDkGA1UdIAQyMDAwLgYEVR0gADAmMCQGCCsGAQUFBwIBFhho
# dHRwOi8vd3d3LmNlcnR1bS5wbC9DUFMwDQYJKoZIhvcNAQEMBQADggIBALuSGVmM
# VtT6CxF1ytoUUkqPU8vrcxW52eb8Agu41rGbsshk5i2tlpFYSlHSp3e6FKlQQjb1
# 8wFm+67cIdcmwznyFskWjhigefIMmBOR5WZzXR93U0j/9wjedEPX8CXHT3JaE9mX
# N7QD8G/Bzctxm1PLB+wvm0PdAAvxmp6Wse3URvwCcMScDMo1ubWbBiYP/l3LVeQg
# p+wzWmZEzZkNwniqnBV7ATuD7h75j6KrjYu5oc+80CTCrR1oD0enep6aTRxEV8zn
# bnsy8Sy77rDz7jialBQ6CkBJUiNjeXa91/oFR8El+x3elyn/aF8OddqqX0CgHumz
# t4Jlv1Vcqb+7aVNEx/l6w5xkXLi52ycYFo7BJJR7RyFi6x8n0iOyamgyXgJbkTRH
# 9TnkHPpOkOj6BpdAkviL/O/RRHmlqkawOC4EBKn2D85+e8ZN5atL2XmisSS270TG
# sV8+8ArFkr7gA71tqk+EwBOtoqjqTHornWlLVk7al/WvcH6Vc3ltMuCnyD93KBRm
# bZyZq4EDMkDm/+Ic5vRvhvgy6pzx3GBxfWNlEu0u/GcBbGQogx+PsDgzQms3issF
# Sk8UzT4GnaxHuu0Wo1lbnqG5oOTE7vl41E3bPgD3n1HkYFGcVa2ATrn4HVEcBBD9
# M4XiZTRjegiFVCvetSHi11K8jGvxCmwMoi+wMIIG8zCCBNugAwIBAgIQUh2Iv33J
# FZ7jRFhh2xJhxjANBgkqhkiG9w0BAQsFADBqMQswCQYDVQQGEwJQTDEhMB8GA1UE
# ChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMTgwNgYDVQQDEy9DZXJ0dW0gRXh0
# ZW5kZWQgVmFsaWRhdGlvbiBDb2RlIFNpZ25pbmcgMjAyMSBDQTAeFw0yNTA3MDgx
# MDMzMjNaFw0yNzA3MDgxMDMzMjJaMIH9MR0wGwYDVQQPExRQcml2YXRlIE9yZ2Fu
# aXphdGlvbjETMBEGCysGAQQBgjc8AgEDEwJaQTEXMBUGA1UEBRMOMjAxNC8wMDM4
# NjYvMDcxCzAJBgNVBAYTAlpBMRUwEwYDVQQIDAxXZXN0ZXJuIENhcGUxEjAQBgNV
# BAcMCUNhcGUgVG93bjENMAsGA1UEERMENzU3MDEjMCEGA1UECQwaMUIgTWFkcmlk
# IFN0cmVldCwgVWl0emljaHQxIDAeBgNVBAoMF0NvZGUgSW5maW5pdHkgKFB0eSkg
# THRkMSAwHgYDVQQDDBdDb2RlIEluZmluaXR5IChQdHkpIEx0ZDCCAaIwDQYJKoZI
# hvcNAQEBBQADggGPADCCAYoCggGBANbvUpERu2NwodnGGxZr/bbzD0MYo3OoSGpq
# PNBOO5AWpL6Fq8l+PoAMBZ2bEvAk/TMDNQyrFZ7zrmQZRJhxfWLkEIurPFo4hFfp
# 3iq70iuwwAMYIJidKJKJfFm8aznY2QTTh8SE/ThEgzuq5EGbT4fbhPIde97U4KoC
# nOW1EMh5BrXA/qrVD24+1A4hQ5704+xIzLQaGuPpMo9Xl7/4kslhuTVDhQg2r4ay
# +feK47hB3D8EXBfANzaCfRk2j5Xd1m5sMgbnf6tspkiybtA//bAHiwP05a3snQZr
# 264GaGcLE8EwWgJYxDDhIqU0yOZuYnR9mT2YCwuMDLNLeE+ADzfRujDZhmPG5Qei
# 3gBp9q2riIgcGLLZbQCOY7GAk7f9Wp91P8YiDWZc0/YPihyYcyCobhhz4iKI62CG
# cVlQCAOhPw+bqCHckrT9GgAMBZ94NrVFw/W1n+XRpve40BjSEyDPsbjQDQk8JMGh
# 5rF1AIIfmWeCLqpNb/DKEm2NLGQB2wIDAQABo4IBfzCCAXswDAYDVR0TAQH/BAIw
# ADBBBgNVHR8EOjA4MDagNKAyhjBodHRwOi8vY2V2Y3NjYTIwMjEuY3JsLmNlcnR1
# bS5wbC9jZXZjc2NhMjAyMS5jcmwwdwYIKwYBBQUHAQEEazBpMC4GCCsGAQUFBzAB
# hiJodHRwOi8vY2V2Y3NjYTIwMjEub2NzcC1jZXJ0dW0uY29tMDcGCCsGAQUFBzAC
# hitodHRwOi8vcmVwb3NpdG9yeS5jZXJ0dW0ucGwvY2V2Y3NjYTIwMjEuY2VyMB8G
# A1UdIwQYMBaAFKxXyggW3D/FMRwKTdv78d6ZJy00MB0GA1UdDgQWBBRiwGM3zjka
# tT29wM2wBQGaWH4wajBKBgNVHSAEQzBBMAcGBWeBDAEDMDYGCyqEaAGG9ncCBQEH
# MCcwJQYIKwYBBQUHAgEWGWh0dHBzOi8vd3d3LmNlcnR1bS5wbC9DUFMwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4IC
# AQARziix3C4lREs8oRFu2oaTqAPTNKNXhA/kA7KPj2HmLlrpiPkx/WB3wV5uy0ca
# Nga/extnvhjksmfGLW3MYE+ThUF5h3Q0U8pXD9pZUKlWKLemsbggt4cK3aWNX5dJ
# l6LY1dNwMmuP4G64TJPsiwl4TpoTuL+rIRjPSuL34mUR/87Vc1eEcjhKYyQzk5Po
# 04RAPUa/9hkNz5bvfNQKf0374ZjwQ34J3FKQ/hJvEU+ifiosclXVwJy5491y/pA/
# CnLBLXriyHnavsC3v3TWkecSoTTORd1TfEvmTTd+zbkPJiuN43OjOJdt7trm0X1m
# iz/k8k3qsjrBJg8VEvKh2uVg3B4Im9U40xXGGPcIAavOgwKkt9BANoAgoY526HPh
# 8T0emd3vDomkLN7h5b5QEAYZnzbvXnKUnIKMHcnmIEGt9IzCEzmHoHBuiLQKgnyF
# 5gzF+F+Fel5ulonDwgjGb4bSKtKFqRabKlQb750kNtz/s3Q4/b7o/iHnFZQKluqW
# AqZDM/oSfXtIVsIQzMmvCU/n9h82zZYggEZN/5TeRAe/Kz7vRqtPphsFO1Ko3qkv
# Oluu8JV6gVSS5u0X48nYRmiE4FG8tlbicUjM4tZ69X9RCOC2nsmADu0SbrcXF+ZB
# ZWa0p0z2y8MnNZ3wa+xhqveZDGqWS/IyiZWH2KH9STsLqzGCBpswggaXAgEBMH4w
# ajELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5B
# LjE4MDYGA1UEAxMvQ2VydHVtIEV4dGVuZGVkIFZhbGlkYXRpb24gQ29kZSBTaWdu
# aW5nIDIwMjEgQ0ECEFIdiL99yRWe40RYYdsSYcYwDQYJYIZIAWUDBAIBBQCgajAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgzy7cPkFlUG0c25y9h5dXJGYLBp1CpKsz
# rcvlG9Y573IwDQYJKoZIhvcNAQEBBQAEggGAtYC6nUdQKIAIpLZbG/Co989M7uta
# EvU5wuvWEq8q0UdETfK2Q+b2M5/BFaYkoThaJgFjd0izFTennN0p8SFRGtNI7UUl
# k+0/9wHQdrXXswlB2csHVqQEskmxnUb7WK3Hu0YJH9usmLqAgCqEjqxDqqx2EAnO
# fdPCFTQCP7NWJi6dHcit/OlCpds8y3a+E8GHvJlCwZiiRHu6bUeL9K+t9JPVAUj4
# 17qcRakWx+Bu1YEPdlGgoiTUyucFomt/hVQVclAQmcisQKKPid36O1Dw8Kh6OY8T
# QQNus5O+0BHt6wMswsZ+dVZcclGJj773hBP08wp+eFQI/JcRpr7+Tsmb9+iTLTf/
# tcdi/6B6sslJWEQpflTqQfJmWjUwuHXsw1VHWAleyeCSESNPQ9wftZCDPvl3EVeB
# 7W26GFmBT/kme+vavxosTBaTXP8VTXDDg+TIaNGZCW95Ck/iDtSfyU+/zkLTl8O1
# /kS3BK54t6AfSL/lWISVAJ1uDxumGP4GU61moYIEAjCCA/4GCSqGSIb3DQEJBjGC
# A+8wggPrAgEBMGowVjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRh
# IFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGluZyAyMDIx
# IENBAhAo8HfBHDa9/l90MkdwJy4DMA0GCWCGSAFlAwQCAgUAoIIBVjAaBgkqhkiG
# 9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDkyNDEzMjUw
# OVowNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQghb6Q4QrSQ418ySi2r0iwmrIIF3zs
# +LASbFjTkQUlxDwwPwYJKoZIhvcNAQkEMTIEMDiKHgALQzyx/HBI3tjtZUukixpy
# TQs34NLyjRwOph04+pU+GXEW+xq6A7PvMoI0mTCBnwYLKoZIhvcNAQkQAgwxgY8w
# gYwwgYkwgYYEFFcUaEEMqFrzQk75FkpRNhD0042YMG4wWqRYMFYxCzAJBgNVBAYT
# AlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMT
# G0NlcnR1bSBUaW1lc3RhbXBpbmcgMjAyMSBDQQIQKPB3wRw2vf5fdDJHcCcuAzAN
# BgkqhkiG9w0BAQEFAASCAgAamSTORuzyAImH/R9fNsqemwbZ9u26d+XDSYsaR+/t
# 1Z4kH+nJkTX8+N40S+9/bpfGhOmyEoY7Mdpa7CYqPoTWjFjqZrWee5cvheXeX3s2
# E5JBJTs7jPZp7OaL+YfQ2F285JQYw04U6UdSVfPYmF8aQn/p9qsB1NLKBRbp7Fu0
# EwSqd1KIvP4xhMPitNdMC4Zg//p8XSUDIud1uWv/OmaxHIz1wh5JAcJmJw6IKlHt
# qC1qV819GDWTDJc2t0rk+ZlzoNrb5eW/IemvM4XFg8cgW0PxBAKCfsfulLw3glpo
# SuZHefXYbmd44BGt4FY9UcE+ovtsfE8VIRCu4qQgUVNqQ54KiJs7XFVnQNK+XvW/
# x7NpiymxGSRoGZEU/wWVq7cYLs3BJZZ2KsJk1Ru/RWVK+TA5rx4eLDYWo5TVSCoN
# zlLQBoCHUlsxh3RvuuVeA1j+a0EcXZSim6EbWt41gkAPUHPfaeLk15lAm2MYs9pa
# wmsZdnKUvL88Gn1Ssr3eupquXoFiq9Mzm6yh1G5Z/xWtoIiwF2NqvqJFpqkvVxQ3
# hKI0R0/rAv8rIQgX9eE69quIOkZQtsX7nT+x4bNow5AkXpIRBBvEe0ufL6OxIuFz
# cHNUKiZT7RX3SNsJU6ojyveLGNOYw0KiEs6tTHKTyrsLIdFkFpbmSTOWIB1xpARP
# og==
# SIG # End signature block
