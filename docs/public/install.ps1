# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

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

# Download to a TEMP file first. The binary reaches its final path
# ($installDir\tina4.exe) ONLY after both the checksum and the Authenticode
# signature pass, so a tampered or unverified download can never land as the
# installed CLI.
$dest = "$installDir\tina4.exe"
$tmp = Join-Path $installDir ([IO.Path]::GetRandomFileName() + ".exe")
try {
Write-Host "Downloading $binary..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp

# Verify integrity against the release SHA256SUMS before trusting the binary.
# FAIL CLOSED: if SHA256SUMS is not published we cannot prove the download is
# the published binary, so we refuse to install rather than skip the check.
# (Keep all output ASCII-only - see the cp1252 note further down.)
$sumsAsset = $release.assets | Where-Object { $_.name -eq "SHA256SUMS" }
if (-not $sumsAsset) {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Write-Error "SHA256SUMS is not available for $tag - refusing to install an unverified binary."
    exit 1
}
# GitHub serves release assets as application/octet-stream, so
# Invoke-WebRequest returns .Content as a byte[] (NOT a string). Splitting a
# byte[] on "`n" yields per-byte garbage, the regex never matches, and every
# lookup wrongly reports "is not listed". Decode to UTF-8 text first. (Guard
# the type so a future string response still works.)
$sumsRaw = (Invoke-WebRequest -Uri $sumsAsset.browser_download_url -UseBasicParsing).Content
$sums = if ($sumsRaw -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($sumsRaw) } else { $sumsRaw }
$lines = @($sums -split "`n" | Where-Object { $_ -match "^[0-9a-fA-F]{64} [ *]$([regex]::Escape($binary))\s*$" })
$line = if ($lines.Count -eq 1) { $lines[0] } else { $null }
if (-not $line) {
    Remove-Item $tmp -Force
    Write-Error "$binary is not listed in SHA256SUMS for $tag"
    exit 1
}
$expected = (($line -split '\s+')[0]).ToLower()
$actual = (Get-FileHash $tmp -Algorithm SHA256).Hash.ToLower()
if ($expected -ne $actual) {
    Remove-Item $tmp -Force
    Write-Host ""
    Write-Host "  Error: checksum mismatch for $binary - refusing to install" -ForegroundColor Red
    Write-Host "    expected: $expected" -ForegroundColor Red
    Write-Host "    actual:   $actual" -ForegroundColor Red
    exit 1
}
Write-Host "Checksum verified (sha256)." -ForegroundColor Green

# Verify the Authenticode signature: the released .exe is EV-signed by Code
# Infinity (scripts/sign-release.ps1). A valid checksum only proves the bytes
# match SHA256SUMS; the signature proves WHO produced them. Refuse anything not
# validly signed by Code Infinity.
$sig = Get-AuthenticodeSignature $tmp
if ($sig.Status -ne 'Valid' -or $null -eq $sig.SignerCertificate -or $sig.SignerCertificate.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false) -ne 'Code Infinity (Pty) Ltd') {
    Remove-Item $tmp -Force
    Write-Host ""
    Write-Host "  Error: Authenticode verification failed for $binary - refusing to install" -ForegroundColor Red
    Write-Host "    status: $($sig.Status)" -ForegroundColor Red
    Write-Host "    signer: $($sig.SignerCertificate.Subject)" -ForegroundColor Red
    exit 1
}
Write-Host "Signature verified: $($sig.SignerCertificate.Subject)" -ForegroundColor Green

# Both checks passed - promote the verified download to its final path.
Move-Item -Path $tmp -Destination $dest -Force
} finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
}

# Put the install dir FIRST on the user PATH so a fresh install always wins
# over a stale tina4.exe sitting earlier on PATH (e.g. an old copy dropped in a
# Ruby / MSYS / Scoop bin dir by a previous install or `tina4 update`). Just
# appending left the old binary shadowing the new one -- `tina4 --version` kept
# reporting the old version and `tina4 setup` ran old code.
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$parts = @()
if ($userPath) { $parts = $userPath -split ';' | Where-Object { $_ -and $_ -ne $installDir } }
$newUserPath = (@($installDir) + $parts) -join ';'
[Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
$env:Path = "$installDir;$env:Path"
Write-Host "Put $installDir first on PATH"

# A tina4.exe in a MACHINE/system PATH dir is searched before any user-PATH dir
# in a new terminal, so a user install can't reorder it. Surface any other copy
# so the user knows why `tina4 --version` might still report an old version.
$others = @(Get-Command tina4 -All -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Source } | Where-Object { $_ -and $_ -ne $dest })
if ($others.Count -gt 0) {
    Write-Host ""
    Write-Host "  Heads up: other tina4 copies are also on PATH:" -ForegroundColor Yellow
    $others | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
    Write-Host "  If 'tina4 --version' doesn't show $tag in a new terminal, remove the" -ForegroundColor Yellow
    Write-Host "  one(s) above (or their folder from PATH)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  tina4 $tag installed successfully" -ForegroundColor Green
Write-Host ""

# Do NOT auto-launch `tina4 setup` here. This script is normally run via
#   irm https://tina4.com/install.ps1 | iex
# which means the PowerShell host's stdin IS the download pipe -- already at EOF.
# `tina4 setup` is an interactive wizard; launched from that dead stdin its menu
# can't be answered and it would silently default, then fail on UAC elevation --
# the "Starting setup -> drops to the prompt" symptom. Instead, point the user at
# the next step. They run it in their own fresh terminal where stdin is a real
# console and the menu works. (`tina4 setup` itself also now refuses a
# non-interactive stdin, as a backstop.)
# NOTE: keep all Write-Host output ASCII-only. Windows PowerShell 5.1 reads this
# UTF-8 script as cp1252, so an em dash / ellipsis renders as mojibake (the
# reported "any time | open a new terminal" garbage). Plain ASCII renders right.
Write-Host "  Next step - run this in your terminal:" -ForegroundColor Cyan
Write-Host ""
Write-Host "    tina4 setup" -ForegroundColor Green -NoNewline
Write-Host "    Guided onboarding: language + AI tool + first project"
Write-Host ""
Write-Host "  Other commands (any time):"
Write-Host "    tina4 doctor   - Check your environment"
Write-Host "    tina4 serve    - Start the dev server"
Write-Host ""

# SIG # Begin signature block
# MIIoHQYJKoZIhvcNAQcCoIIoDjCCKAoCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDeqo9T0UYKe67l
# 3nRVZwRYZx4TO5KPKrXYauDeczQLq6CCINgwggXJMIIEsaADAgECAhAbtY8lKt8j
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
# BAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg3aac16MM9gnO3bYGdZ8DCET4vpDMJmDa
# mIzugCJ3W50wDQYJKoZIhvcNAQEBBQAEggGAQYZP0RcMOvZ53ncyHcOBRrP8EO8u
# IBrjqt5QOH4n4ixa6tXr6ifjzVRF7zN+Zk9gy24AA4PCBy7Vk6WLPHozmkTCfk/o
# bH1lRje4gMvz23NB0Cef5euESZAht0YqvZW6o6pUGGSz6ak3e4Krf6Kpu0AAqv2u
# Ba7VlnO3j1ZEP0gXmmab8bqoLt/NGp9ueAVbLGRjSK4cNr9KlZIZcTJgMDQOtuHI
# 49D7OVajrXVw+2mfAueWCQv2evYAso2brmtyBZAwoHHbR68v3xXijPq+rJFY/0g6
# DqK2MYK/P6GCWoRv8C+mB5L8659hILe9UjmMIZD97Hu0rxJoD9mYkJ0tTK+Y7BV2
# kSNv36iEuKv3aQhBY3qVoX4zgaP53Ysfdfdq1h+i9mrtmHXUgxcIa9ra/taa96V0
# Wd0HeMcZmUzEaOExWXe+4hPpTTvWuIMKLHiaMM4TzuRsSdOb1m4Aa+gJ4jdLB1xO
# /ltRZgIln3o5SiE8+NYjq3LnIxO5wwpSO2OuoYIEAjCCA/4GCSqGSIb3DQEJBjGC
# A+8wggPrAgEBMGowVjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRh
# IFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGluZyAyMDIx
# IENBAhAo8HfBHDa9/l90MkdwJy4DMA0GCWCGSAFlAwQCAgUAoIIBVjAaBgkqhkiG
# 9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDkyNDE3MzU1
# NlowNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQghb6Q4QrSQ418ySi2r0iwmrIIF3zs
# +LASbFjTkQUlxDwwPwYJKoZIhvcNAQkEMTIEMN6qcPI18yT5POpndSyfsfChfqTh
# SX23uMC5h2PYV5dn6xBzJ0ugV2Whp0E8QOroAjCBnwYLKoZIhvcNAQkQAgwxgY8w
# gYwwgYkwgYYEFFcUaEEMqFrzQk75FkpRNhD0042YMG4wWqRYMFYxCzAJBgNVBAYT
# AlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMT
# G0NlcnR1bSBUaW1lc3RhbXBpbmcgMjAyMSBDQQIQKPB3wRw2vf5fdDJHcCcuAzAN
# BgkqhkiG9w0BAQEFAASCAgB/klfMkySubssnidAtByfueRqGr/qOWNWhDH+3TLi5
# k+El9Qo+N24U77jJ4VWP5bJZm5jEGfP3r5edm5oS89pDasQeistBbzFc0SmFPmho
# LGtoqihKcQXe+P5o5L46tOwi7JsUQITdDxA0MWq2Dz0A6/ZtuqaFT0N5rmgvUAbP
# ZdLl/dMfviEJik3fR4VxnwcWhyT9Q7RI4xUl7Ey/eS1oZwYRQe4PF1h1Jseggi2D
# 2EIs+VnRZieqJMBQo9a5OLc0MbLKrO4Rgxea4pnSSAQoLHa6ep335GIVG0dqJ6Xi
# S7m2xjG0+Uqcen8jEQtjVEJdnhfpLNVJnaniH3IdgJnFk4N42ZM1JghyYQXV2cIu
# 2luBV++7FndbL3DhdHO3+jk/o3I1yC3rojlkYfIvksnCOVHMXQWLJ+03HLGi75Rz
# iapzuTL5c3GCcO3a81NHPsCNadgJYb8rRlQ9yeBYR2tiSp7Cfa1UcVOTnJlRtWcp
# EQcpJKVrRF4jHmNxCKzoA3bu7p/Im1u9/idrWrNHQ5cXRLj1dQ0loOHAIAphnCg8
# sSTyV0QIpAWeQk/20KSp9RUpNHafdniM/4ZCnc3XdGbaWlCx1JNv8sCp0qf89sLZ
# IEKs1WXxJJrR/UGRl42ba5Mors60e0lEANJkhJDzWUME+VwF7yLsSMDkD+1+lQtE
# eA==
# SIG # End signature block
