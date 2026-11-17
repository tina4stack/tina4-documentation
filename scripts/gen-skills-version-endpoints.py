#!/usr/bin/env python3
# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# gen-skills-version-endpoints.py — publish the stable skill-version endpoints the
# tina4-developer-<lang> skills GET at start-up to decide whether they are stale.
#
# The skills fetch  https://tina4.com/skills/tina4-developer-<lang>/version  and
# compare the plain-text semver it returns against their OWN `updated_for_version`
# frontmatter. Both sides MUST be the same quantity — the skill's
# `updated_for_version`, NOT the framework release number — or a skill installed
# from the current bundle would read as stale the moment it lands.
#
# The per-ref bundles under docs/public/skills/<ref>/ are FROZEN release artefacts
# (gen-skills-bundle.sh stages them at release time). This generator reads the
# LATEST such bundle, lifts each skill's `updated_for_version`, and writes:
#
#   docs/public/skills/tina4-developer-<lang>/version   (one per language)
#   docs/public/skills/latest/version                   (the newest bundle's ref)
#
# The two endpoints carry DIFFERENT quantities, on purpose. A per-language
# endpoint is a skill's `updated_for_version`, which the skill compares with its
# own frontmatter. `latest/version` is the newest published bundle REF (the
# <ref> directory name, e.g. 3.13.164): tina4/scripts/gen-skills-bundle.sh and
# check-skills-manifest-regression.sh use it as the baseline a new bundle must
# not shrink against, and no skill reads it. It used to carry the highest
# `updated_for_version`, so every deploy overwrote the bundle ref the release
# had committed (it served 3.13.147 while 3.13.164 was live), and the CI
# regression check compared new bundles against an old one.
#
# VitePress serves docs/public/ at the site root, so these resolve at
# https://tina4.com/skills/tina4-developer-<lang>/version and .../skills/latest/version.
#
# It is wired into `docs:build`, so every publish keeps the endpoints current.
# Run it directly to refresh them:  python3 scripts/gen-skills-version-endpoints.py
import re, sys, pathlib

REPO = pathlib.Path(__file__).resolve().parents[1]
SKILLS = REPO / "docs" / "public" / "skills"
LANGS = ["python", "php", "ruby", "nodejs"]
SEMVER = re.compile(r"^\s*(\d+)\.(\d+)\.(\d+)\s*$")
FRONT = re.compile(r"^updated_for_version:\s*(\d+\.\d+\.\d+)\s*$", re.M)


def semver_key(name: str):
    m = SEMVER.match(name)
    return tuple(int(x) for x in m.groups()) if m else None


def published_refs():
    """Version-named bundle dirs (docs/public/skills/<ref>/), newest first."""
    refs = []
    for child in SKILLS.iterdir():
        if child.is_dir() and semver_key(child.name):
            refs.append(child.name)
    return sorted(refs, key=semver_key, reverse=True)


def updated_for_version(ref: str, lang: str):
    skill = SKILLS / ref / f"tina4-developer-{lang}" / "SKILL.md"
    if not skill.is_file():
        return None
    m = FRONT.search(skill.read_text(encoding="utf-8"))
    return m.group(1) if m else None


def write_version(path: pathlib.Path, value: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value + "\n", encoding="utf-8", newline="\n")
    print(f"  wrote {path.relative_to(REPO)}  ->  {value}")


def main():
    refs = published_refs()
    if not refs:
        print("error: no published skill bundles under docs/public/skills/<ref>/", file=sys.stderr)
        return 1
    latest_seen = None
    wrote = 0
    for lang in LANGS:
        val = None
        for ref in refs:  # newest first; take the first bundle that ships this skill
            val = updated_for_version(ref, lang)
            if val:
                break
        if not val:
            print(f"error: no updated_for_version for tina4-developer-{lang} in any bundle", file=sys.stderr)
            return 1
        write_version(SKILLS / f"tina4-developer-{lang}" / "version", val)
        wrote += 1
        if latest_seen is None or semver_key(val) > semver_key(latest_seen):
            latest_seen = val
    write_version(SKILLS / "latest" / "version", refs[0])
    print(f"OK: {wrote} per-language endpoints (highest {latest_seen}) + latest bundle ref {refs[0]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
