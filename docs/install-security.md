---
title: Installer Security and Transparency
description: Exactly what the Tina4 CLI installer downloads, what it changes, and how to verify it came from us.
---

# Installer Security and Transparency

This page states, in plain terms, what the `tina4` command-line installer does to
a machine, what it does not do, and how anyone (including a security team) can
verify that a download is genuine. It exists so the tool can be reviewed and
approved without reading the install scripts line by line.

If you assess software for a managed environment, this page is written for you.

## What gets installed, and where

The base installer places exactly one file: the `tina4` binary.

- macOS / Linux: `/usr/local/bin/tina4` (a different directory can be set at install time).
- Windows: `%LOCALAPPDATA%\tina4\tina4.exe`, and that directory is added to the user PATH.

That is the whole footprint of the installer. It installs no services, no
drivers, and no background agents.

## Provenance and integrity

From version 3.8.53, every release is produced and protected as follows:

- **Signed (Windows).** `tina4-windows-amd64.exe` carries an Extended Validation
  (EV) Authenticode signature. Publisher: `Code Infinity (Pty) Ltd`, issued by
  the Certum Extended Validation Code Signing CA. EV signatures carry immediate
  Microsoft SmartScreen reputation.
- **Checksums (all platforms).** Each release publishes a `SHA256SUMS` file. The
  installer downloads it and verifies the binary against it before running
  anything, and refuses to install on a mismatch.
- **Build provenance (Linux / macOS).** Each binary carries a signed SLSA
  build-provenance attestation that ties it to the exact workflow run and commit
  that produced it.
- **Reproducible, audited build.** Binaries are built in GitHub Actions from a
  tagged, reviewed commit, with the dependency set locked (`cargo build
  --locked`) and screened by `cargo-deny` for known-vulnerable or yanked crates
  before the build runs. The private signing key never leaves its hardware
  security module; a person enters the signing two-factor code at release time.

## What the install script does, step by step

1. Detects your operating system and CPU architecture.
2. Reads the latest GitHub release to find the matching binary.
3. Downloads that binary from the versioned GitHub release (not from a moving branch).
4. Downloads `SHA256SUMS` and verifies the binary's hash against it. A mismatch aborts the install.
5. Moves the verified binary into the install directory and makes it runnable.
6. Prints the next command to run.

## What it does not do

- No scheduled tasks, cron entries, autorun, or registry run-keys.
- No telemetry, analytics, or phone-home.
- No modification of system-wide settings. The only environment change is adding
  the per-user install directory to PATH on Windows.

## A note on `tina4 setup`

`tina4 setup` is a separate, optional, interactive step. It can install language
runtimes (for example PHP and Composer) through Chocolatey or Homebrew and add
them to PATH, to get a new machine ready for development. That is normal for a
developer tool, but on a managed device it should run under your change-control
process. The base install above does none of this; you choose whether to run
`tina4 setup` at all.

## The reviewed install (recommended for managed machines)

Piping a script straight into a shell gives you nothing to inspect. On a managed
machine, download the script, read it, then run it:

macOS / Linux:

```bash
curl -fsSLO https://raw.githubusercontent.com/tina4stack/tina4/main/install.sh
less install.sh
sh install.sh
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/tina4stack/tina4/main/install.ps1 -OutFile install.ps1
notepad install.ps1
.\install.ps1
```

## Verify a download yourself

- **Windows signature:** right-click the `.exe`, Properties, Digital Signatures
  (expect `Code Infinity (Pty) Ltd`), or run
  `signtool verify /pa tina4-windows-amd64.exe`.
- **Build provenance (Linux / macOS):**
  `gh attestation verify <file> --repo tina4stack/tina4`.
- **Checksums (all platforms):** download `SHA256SUMS` from the release, then
  `sha256sum -c SHA256SUMS` (Linux) or `shasum -a 256 -c SHA256SUMS` (macOS).

The signing certificate fingerprints, for reference:

- SHA-1: `5F8628C6E64209D196553B09A272779458DB951A`
- SHA-256: `7DEA53EB97BAE848354052ADC0BC70C25CDD35BB9BE715B56B987E733545CFB1`

## Network endpoints

During install the scripts contact only:

- `api.github.com` and `objects.githubusercontent.com` (release metadata and downloads)
- `raw.githubusercontent.com` (the install script itself)

Signing additionally contacts the Certum timestamp service (`time.certum.pl`),
and provenance verification contacts GitHub. Allowlist these if your environment
restricts outbound traffic.

## Reporting a concern

Open an issue at <https://github.com/tina4stack/tina4> or contact the team via
<https://tina4.com>. Security reports are welcome and acted on.
