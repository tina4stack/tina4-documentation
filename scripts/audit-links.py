#!/usr/bin/env python3
"""
audit-links.py — Find broken links in the VitePress docs.

Usage:
    python3 scripts/audit-links.py            # report only (exit 0)
    python3 scripts/audit-links.py --strict   # exit 1 if any missing files
    python3 scripts/audit-links.py --strict-anchors  # also fail on stale anchors

What it checks:
- Markdown links [text](path) where path is internal (no http/mailto/etc)
- Resolves filesystem-style: docs/<path> AND docs/public/<path> (VitePress
  serves docs/public/ at the site root, so /images/foo.png lives in public/)
- Validates anchors against the target file's heading slugs
- Skips node_modules, .vitepress/dist, .vitepress/cache

Designed for CI:
- Default mode (report-only) is human-facing
- --strict gates merges on a clean missing-file count, leaves stale anchors
  as warnings since legacy v2 docs have many. Tighten over time.
"""
import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

DOCS = Path(__file__).resolve().parent.parent / "docs"
PUBLIC = DOCS / "public"

LINK_RE = re.compile(r'(!?)\[([^\]]*)\]\(([^)]+)\)')
HEADING_RE = re.compile(r'^(#{1,6})\s+(.+?)\s*$', re.MULTILINE)
EXPLICIT_ANCHOR_RE = re.compile(r'\{#([a-zA-Z0-9_\-]+)\}')

EXCLUDE_DIRS = ('node_modules', '.vitepress/dist', '.vitepress/cache')

# Known broken links that are accepted by --strict. Empty as of the
# sync-books.sh cross-book path rewriter landing — every synced reference
# now resolves. Add an entry here only as a temporary measure when a real
# fix is queued upstream; document why and the issue/PR that retires it.
ALLOWLIST: set[tuple[str, str]] = set()


def slugify(text: str) -> str:
    """GitHub / VitePress-style heading slug."""
    s = text.strip().lower()
    s = re.sub(r'[^\w\s\-]', '', s)
    return re.sub(r'\s+', '-', s)


_anchor_cache: dict = {}


def file_anchors(p: Path) -> set:
    if p in _anchor_cache:
        return _anchor_cache[p]
    if not p.exists():
        _anchor_cache[p] = set()
        return set()
    text = p.read_text(encoding='utf-8', errors='ignore')
    anchors = {slugify(m.group(2)) for m in HEADING_RE.finditer(text)}
    anchors |= {m.group(1).lower() for m in EXPLICIT_ANCHOR_RE.finditer(text)}
    _anchor_cache[p] = anchors
    return anchors


def resolve(target: str, source: Path):
    """
    Returns (resolved_path | None, anchor | None, kind).
    kind: 'skip' | 'self-anchor' | 'file' | 'missing'
    """
    target = target.strip().split(' "', 1)[0].split(" '", 1)[0]
    if not target:
        return None, None, 'skip'
    if target.startswith(('http://', 'https://', 'mailto:', 'tel:', 'data:')):
        return None, None, 'skip'
    if target.startswith('#'):
        return source, target.lstrip('#').lower(), 'self-anchor'

    anchor = None
    if '#' in target:
        target, anchor = target.split('#', 1)
        anchor = anchor.lower()
    if not target:
        return source, anchor, 'self-anchor'

    # Build candidate paths. VitePress serves docs/public/* at site root, so
    # /foo.png is found at docs/public/foo.png OR docs/foo.png.
    candidates = []
    if target.startswith('/'):
        rel = target.lstrip('/')
        candidates.append(DOCS / rel)
        candidates.append(PUBLIC / rel)
    else:
        candidates.append(source.parent / target)

    for c in candidates:
        c = c.resolve()
        if c.exists():
            return c, anchor, 'file'
        if c.suffix == '':
            md = c.with_suffix('.md')
            if md.exists():
                return md, anchor, 'file'
            idx = c / 'index.md'
            if idx.exists():
                return idx, anchor, 'file'
    return candidates[0].resolve(), anchor, 'missing'


def audit():
    issues = defaultdict(list)
    files_checked = 0

    for md in sorted(DOCS.rglob('*.md')):
        s = str(md)
        if any(x in s for x in EXCLUDE_DIRS):
            continue
        files_checked += 1
        text = md.read_text(encoding='utf-8', errors='ignore')
        rel = str(md.relative_to(DOCS))
        for m in LINK_RE.finditer(text):
            is_image = m.group(1) == '!'
            target = m.group(3)
            resolved, anchor, kind = resolve(target, md)
            if kind in ('skip', 'self-anchor'):
                if anchor and resolved and anchor not in file_anchors(resolved):
                    issues['missing-anchor'].append((rel, target))
                continue
            if kind == 'missing':
                key = 'missing-image' if is_image else 'missing-file'
                issues[key].append((rel, target))
                continue
            if anchor and anchor not in file_anchors(resolved):
                issues['missing-anchor'].append((rel, target))

    return files_checked, issues


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('--strict', action='store_true',
                    help='exit 1 if any non-allowlisted missing-file/image found')
    ap.add_argument('--strict-anchors', action='store_true',
                    help='also exit 1 on stale anchors')
    args = ap.parse_args()

    files_checked, issues = audit()

    # Split out allowlisted issues so we can report them separately.
    def split_allow(items):
        gated, allowed = [], []
        for src, tgt in items:
            (allowed if (src, tgt) in ALLOWLIST else gated).append((src, tgt))
        return gated, allowed

    file_gated, file_allowed = split_allow(issues['missing-file'])
    image_gated, image_allowed = split_allow(issues['missing-image'])

    print(f"audit-links.py: scanned {files_checked} markdown files")
    print(f"  missing-file:    {len(issues['missing-file'])} ({len(file_allowed)} allowlisted)")
    print(f"  missing-image:   {len(issues['missing-image'])} ({len(image_allowed)} allowlisted)")
    print(f"  missing-anchor:  {len(issues['missing-anchor'])}")

    if file_gated:
        print(f"\n── missing-file ({len(file_gated)}) ──")
        for src, tgt in file_gated:
            print(f"  {src}  →  {tgt}")
    if image_gated:
        print(f"\n── missing-image ({len(image_gated)}) ──")
        for src, tgt in image_gated:
            print(f"  {src}  →  {tgt}")
    if issues['missing-anchor']:
        print(f"\n── missing-anchor ({len(issues['missing-anchor'])}) ──")
        for src, tgt in issues['missing-anchor']:
            print(f"  {src}  →  {tgt}")
    if file_allowed or image_allowed:
        print(f"\n── allowlisted (known, tracked for fix) ──")
        for src, tgt in file_allowed + image_allowed:
            print(f"  {src}  →  {tgt}")

    fail = 0
    if args.strict and (file_gated or image_gated):
        fail = 1
        print("\nFAIL: --strict and non-allowlisted missing files/images present")
    if args.strict_anchors and issues['missing-anchor']:
        fail = 1
        print("\nFAIL: --strict-anchors and stale anchors present")
    if fail == 0:
        print("\nOK")
    sys.exit(fail)


if __name__ == '__main__':
    main()
