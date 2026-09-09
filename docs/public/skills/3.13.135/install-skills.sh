#!/usr/bin/env bash
# Tina4 AI skills installer for macOS / Linux.
#
# Choose a target explicitly:
#   curl -fsSL https://raw.githubusercontent.com/tina4stack/tina4/main/install-skills.sh | TINA4_SKILLS_TARGET=claude sh
#   curl -fsSL https://raw.githubusercontent.com/tina4stack/tina4/main/install-skills.sh | TINA4_SKILLS_TARGET=codex sh
#   curl -fsSL https://raw.githubusercontent.com/tina4stack/tina4/main/install-skills.sh | TINA4_SKILLS_TARGET=cursor sh
# Use TINA4_SKILLS_TARGET=all only when every supported tool should receive the skills.
#
# POSIX sh ONLY -- no bashisms. Every example above pipes into `sh`, and on
# Debian/Ubuntu that is dash. This script used `set -euo pipefail` and bash
# arrays, so the DOCUMENTED command died on line 9 with
# "set: Illegal option -o pipefail" and installed nothing. It worked on macOS,
# where /bin/sh is bash in POSIX mode and accepts pipefail, which is exactly why
# it survived: the break was invisible to anyone testing on a Mac.
#
# pipefail is not replaced with anything. Every download below uses `curl -f`,
# so a failed fetch is a non-zero exit that `set -e` already catches.
set -eu

# Pin skills to a released tag, not a moving branch, so an install is reproducible.
# Bump this when the skills change in a new release. Override with TINA4_SKILLS_REF.
ref="${TINA4_SKILLS_REF:-3.13.135}"
target="${TINA4_SKILLS_TARGET:-}"
skill_home="${TINA4_SKILLS_HOME:-$HOME}"
# Three sources, tried in this order per file: tina4.com (Tina4's own infra),
# jsDelivr (a cached CDN mirror), then raw.githubusercontent (the GitHub origin).
# tina4.com is FIRST so the common path never depends on GitHub raw, which 503s
# during GitHub incidents; jsDelivr and raw remain as automatic fallbacks and the
# sha256 manifest still gates every downloaded file. Each source has its OWN path
# shape (tina4.com is flat; jsDelivr uses repo@ref; raw uses repo/ref), composed
# per-tier in skill_urls and in verify_checksums rather than by swapping one root
# prefix. Override any tier for a self-hosted mirror or an air-gapped install.
tina4_root="${TINA4_SKILLS_TINA4_ROOT:-https://tina4.com/skills}"
jsdelivr_root="${TINA4_SKILLS_JSDELIVR_ROOT:-https://cdn.jsdelivr.net/gh/tina4stack}"
raw_root="${TINA4_SKILLS_RAW_ROOT:-https://raw.githubusercontent.com/tina4stack}"
retry_count="${TINA4_SKILLS_RETRY_COUNT:-3}"
retry_delay="${TINA4_SKILLS_RETRY_DELAY:-2}"

# Space separated, not an array: dash has no arrays. Neither path can contain a
# space, because both are literals under $HOME.
case "$target" in
  claude) destinations="$skill_home/.claude/skills" ;;
  codex)  destinations="$skill_home/.agents/skills" ;;
  cursor) destinations="$skill_home/.cursor/skills" ;;
  all)    destinations="$skill_home/.claude/skills $skill_home/.agents/skills $skill_home/.cursor/skills" ;;
  *)
    echo "error: set TINA4_SKILLS_TARGET to claude, codex, cursor, or all" >&2
    exit 2
    ;;
esac

stage="$(mktemp -d)"
manifest_file="$(mktemp)"
trap 'rm -rf "$stage" "$manifest_file"' EXIT

# download_file <destination> <primary-url> <fallback-url>
download_file() {
  destination="$1"; shift
  for url in "$@"; do
    if curl -fsSL --retry "$retry_count" --retry-delay "$retry_delay" "$url" -o "$destination"; then
      return 0
    fi
    rm -f "$destination"
    echo "  ! download failed, trying next source: $url" >&2
  done
  echo "error: every download source failed for $destination" >&2
  return 1
}

# skill_urls <repo> <skill> <relative-path>
# Echo the candidate URLs for one skill file, in priority order: tina4.com (flat,
# stage-relative), jsDelivr, raw. Whitespace-safe because URLs never contain a
# space, so the caller can pass the result unquoted to download_file.
skill_urls() {
  echo "${tina4_root}/${ref}/$2/$3"
  echo "${jsdelivr_root}/$1@${ref}/.claude/skills/$2/$3"
  echo "${raw_root}/$1/${ref}/.claude/skills/$2/$3"
}

# install_skill <repo> <skill> <reference.md ...>
install_skill() {
  repo="$1"; skill="$2"; shift 2
  mkdir -p "$stage/$skill/references"
  download_file "$stage/$skill/SKILL.md" $(skill_urls "$repo" "$skill" "SKILL.md")
  for reference in "$@"; do
    download_file "$stage/$skill/references/$reference" \
      $(skill_urls "$repo" "$skill" "references/$reference")
  done
  echo "  + $skill  ($repo)"
}

# Verify every staged skill file against the checksum manifest published in THIS
# repo (tina4) at $ref by scripts/gen-skills-sha256.sh, so a tampered or truncated
# download can never be published. A mismatch or a missing tool aborts with nothing
# installed. install-skills.sh needs no code signature; this is its integrity layer.
verify_checksums() {
  download_file "$manifest_file" \
    "${tina4_root}/${ref}/skills.sha256" \
    "${jsdelivr_root}/tina4@${ref}/skills.sha256" \
    "${raw_root}/tina4/${ref}/skills.sha256"
  if [ ! -s "$manifest_file" ]; then
    echo "error: skills checksum manifest is empty -- refusing to install" >&2
    return 1
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    verify_cmd="sha256sum -c"
  elif command -v shasum >/dev/null 2>&1; then
    verify_cmd="shasum -a 256 -c"
  else
    echo "error: no sha256 tool (sha256sum/shasum) to verify skills -- refusing to install" >&2
    return 1
  fi
  if ! ( cd "$stage" && $verify_cmd "$manifest_file" ) >/dev/null 2>&1; then
    echo "error: a skill file failed checksum verification (tampering or a stale manifest) -- nothing installed" >&2
    return 1
  fi
  echo "  verified $(grep -c . "$manifest_file") skill files against skills.sha256 (ref $ref)"
}

publish_skills() {
  for destination in $destinations; do
    mkdir -p "$destination"
    for legacy_skill in $LEGACY_SKILLS; do
      if [ -e "$destination/$legacy_skill" ]; then
        rm -rf "$destination/$legacy_skill"
        echo "  - removed legacy $legacy_skill"
      fi
    done
    for source in "$stage"/*; do
      skill="$(basename "$source")"
      replacement="$destination/.${skill}.tina4-new"
      rm -rf "$replacement"
      cp -R "$source" "$replacement"
      rm -rf "$destination/$skill"
      mv "$replacement" "$destination/$skill"
    done
    printf '%s\n' "$ref" > "$destination/.tina4-skills-ref"
    echo "  installed for $destination"
  done
}

# Every file under references/, not most of them. ai-coder-rule-path.svg was
# missing, so a SUCCESSFUL install still produced an incomplete skill -- the
# quiet half of this bug, which no error would ever have reported.
DEV_REFS="auth-and-services.md data-and-orm.md deployment.md routes-and-api.md templates-and-frontend.md realtime.md web-push.md ai-coder-rule-path.svg"
LEGACY_SKILLS="tina4-developer"

echo ""
echo "  Tina4 Skills Installer"
echo "  Target: $target  (ref: $ref)"
echo ""

# Per-language developer skills (each from its own framework repo).
install_skill tina4-python  tina4-developer-python  $DEV_REFS
install_skill tina4-php     tina4-developer-php     $DEV_REFS
install_skill tina4-ruby    tina4-developer-ruby    $DEV_REFS
install_skill tina4-nodejs  tina4-developer-nodejs  $DEV_REFS
# Shared skills (canonical copy served from tina4-python).
install_skill tina4-python  tina4-js          html-and-components.md signals-and-reactivity.md persistence.md rtc.md
install_skill tina4-python  tina4-maintainer  cli-and-deployment.md frond-and-frontend.md routing-and-orm.md subsystems.md
install_skill tina4-python  tina4-architect

verify_checksums
publish_skills

echo ""
echo "  Done - seven skills installed for $target (ref $ref). Restart your coding tool to pick them up."
