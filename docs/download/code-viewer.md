---
title: Tina4 Code Viewer
description: Download the Tina4 Code Viewer, a read-only reviewer and code commenter for Tina4 codebases. Signed builds for macOS, Windows, and Linux.
---

# Tina4 Code Viewer

**Review Tina4 code. Hand the fixes to any AI agent.**

A lightweight, cross-platform desktop app that understands your Tina4 layout, lets you leave line-anchored review comments grounded against the Tina4 RAG, audits the live project over `/__dev/mcp`, and exports a portable `.tina4-review` bundle any agent can follow. It views and comments, it never edits your code.

## Download v0.1.0

| Platform | Build | Download |
|----------|-------|----------|
| macOS | Universal (Apple Silicon + Intel), signed and notarized | [.dmg](https://tina4.com/downloads/Tina4-Code-Viewer_0.1.0_universal.dmg) |
| Windows | x64, EV code-signed installer | [.exe](https://tina4.com/downloads/Tina4-Code-Viewer_0.1.0_x64-setup.exe) |
| Linux | x64, portable AppImage | [.AppImage](https://tina4.com/downloads/Tina4-Code-Viewer_0.1.0_amd64.AppImage) |
| Linux | Debian / Ubuntu package | [.deb](https://tina4.com/downloads/Tina4-Code-Viewer_0.1.0_amd64.deb) |

Checksums for every build: [SHA256SUMS.txt](https://tina4.com/downloads/SHA256SUMS.txt)

## What it does

::: cards
== Knows your stack
Fingerprints tina4-python / php / ruby / nodejs / js from layout and jumps you to routes, ORM, templates, and migrations.
== Click a line, comment
Severity, tags, and RAG-grounded context attached to exact `file:line` anchors.
== Live MCP audit
Read-only calls to `/__dev/mcp` snapshot routes, ORM, and migrations into the review.
== Live handoff
Stream each comment to `.tina4-review/live.jsonl` so an agent can start fixing mid-review.
== Editable plans
Author `plan/*.md` with live preview, the marching orders your agent follows.
== Portable handoff
Exports `review.md` and `review.json` that any AI agent (Claude Code, Cursor, and the rest) can act on.
:::

## Verify your download

macOS and Windows builds are code-signed (Apple Developer ID plus notarization on macOS; a Certum EV certificate on Windows). Every release also publishes checksums. Linux builds are verified by the same `SHA256SUMS.txt`.

```bash
# macOS / Linux: check the download against the published checksums
shasum -a 256 -c SHA256SUMS.txt

# macOS: confirm the signature and notarization
spctl -a -vvv "/Applications/Tina4 Code Viewer.app"
codesign -dv --verbose=4 "/Applications/Tina4 Code Viewer.app"
```

Built with [tina4-js](/js/index.md) and a small Rust/Tauri shell. Open source under MIT.
