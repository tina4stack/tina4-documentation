#!/usr/bin/env python3
"""Compile tina4css once and ship the SAME bytes to all four frameworks.

Every framework serves ``/css/tina4.css`` from its own public directory, and
all four must serve the IDENTICAL artefact. Measured 2026-08-06: they do -
sha f115a8c88d04, 35962 bytes, in Python, PHP, Ruby and Node alike, and a
fresh grass compile of the .scss source reproduces it exactly.

That is true today by luck, not by construction. Nothing regenerated the CSS
and nothing checked it, so editing a .scss partial and shipping would leave
four committed .css files describing the previous design. This script is the
thing that makes it true by construction.

WHY THE MINIFIED FILE CHANGED
    The shipped tina4.min.css was 28472 bytes and NOT reproducible from the
    current toolchain - a fresh build gives 28487. The difference is fifteen
    single bytes: the old minifier emitted ``@media(min-width: 576px)`` and
    grass emits ``@media (min-width: 576px)``. Both are valid CSS. The old
    minifier was the per-framework SCSS compiler, which has been deleted
    (the Rust CLI owns SCSS), so that artefact had no producer left. It is
    now regenerated from grass and is reproducible.

USAGE
    build-tina4css.py            regenerate and write to all four
    build-tina4css.py --check    verify only; exit 1 if anything is stale
                                 or if the four sources have drifted apart

--check is the gate. Run it in CI and on release, next to audit-truth.py.
"""
import hashlib
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
REPOS = ROOT.parent

# (framework, scss source dir, compiled output dir)
#
# PHP's source and output live under src/ rather than inside the framework
# namespace directory the way the other three do. That is a real divergence,
# but it is NOT a defect: composer ships the whole package, so a consumer gets
# vendor/tina4stack/tina4php/src/public/css/ and PHP serves /css/tina4.css from
# it exactly like the others. MEASURED on a real `composer require` project.
# Relocating it would be churn for symmetry's sake.
TARGETS = [
    ("python", "tina4-python/tina4_python/scss/tina4css", "tina4-python/tina4_python/public/css"),
    ("php", "tina4-php/src/scss/tina4css", "tina4-php/src/public/css"),
    ("ruby", "tina4-ruby/lib/tina4/scss/tina4css", "tina4-ruby/lib/tina4/public/css"),
    ("nodejs", "tina4-nodejs/packages/core/scss/tina4css", "tina4-nodejs/packages/core/public/css"),
]

# base.scss is one line - `@import 'tina4';` - so it compiles to the SAME bytes
# as tina4.scss. Only the two artefacts anyone loads are shipped.
ARTEFACTS = ["tina4.css", "tina4.min.css"]


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12]


def tree_sha(d: pathlib.Path) -> str:
    """One hash over every .scss in a tina4css directory, name-ordered."""
    h = hashlib.sha256()
    for f in sorted(d.glob("*.scss")):
        h.update(f.name.encode())
        h.update(f.read_bytes())
    return h.hexdigest()[:12]


def find_cli() -> str | None:
    """The tina4 CLI owns SCSS compilation (grass). Prefer a local build."""
    for candidate in [
        REPOS / "tina4/target/release/tina4",
        REPOS / "tina4/target/debug/tina4",
    ]:
        if candidate.exists():
            return str(candidate)
    return shutil.which("tina4")


def compile_once(source: pathlib.Path, cli: str) -> dict[str, bytes]:
    """Compile tina4css in a scratch project and return the artefact bytes.

    The CLI compiles src/scss/*.scss to src/public/css/. Its compile_dir is
    NOT recursive, so the partials have to sit directly in src/scss - handing
    it src/scss/tina4css/ silently produces nothing, which is exactly how this
    was first got wrong.
    """
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        (work / "src" / "scss").mkdir(parents=True)
        (work / "src" / "public" / "css").mkdir(parents=True)
        for f in source.glob("*.scss"):
            shutil.copy2(f, work / "src" / "scss" / f.name)

        out: dict[str, bytes] = {}
        for args, produced, name in [
            (["scss"], "tina4.css", "tina4.css"),
            (["build"], "tina4.min.css", "tina4.min.css"),
        ]:
            subprocess.run([cli, *args], cwd=work, capture_output=True, check=False)
            path = work / "src" / "public" / "css" / produced
            if not path.exists():
                raise SystemExit(f"FAIL: `tina4 {args[0]}` produced no {produced}")
            out[name] = path.read_bytes()
        return out


def main() -> int:
    check = "--check" in sys.argv

    # 1. The four sources must be identical. A divergence here means someone
    #    edited tina4css in one framework only, and the compiled output would
    #    then differ per framework however carefully it was rebuilt.
    sources = {}
    for name, src, _out in TARGETS:
        d = REPOS / src
        if not d.exists():
            print(f"  MISSING source: {src}")
            return 1
        sources[name] = tree_sha(d)

    if len(set(sources.values())) != 1:
        print("FAIL: the four tina4css sources have drifted apart:")
        for name, h in sources.items():
            print(f"    {h}  {name}")
        return 1
    print(f"sources: all four identical ({next(iter(sources.values()))})")

    cli = find_cli()
    if cli is None:
        # An instrument that cannot fail proves nothing: without the compiler
        # this script cannot tell current from stale, so it must not pass.
        print("FAIL: the tina4 CLI is not on PATH and no local build exists.")
        print("      It owns SCSS compilation, so nothing can be verified without it.")
        return 1

    built = compile_once(REPOS / TARGETS[0][1], cli)
    for name, data in built.items():
        print(f"built:   {name}  {len(data)} bytes  {hashlib.sha256(data).hexdigest()[:12]}")

    # 2. Compare or write.
    stale: list[str] = []
    for fw, _src, out in TARGETS:
        outdir = REPOS / out
        outdir.mkdir(parents=True, exist_ok=True)
        for name in ARTEFACTS:
            target = outdir / name
            want = built[name]
            if check:
                if not target.exists() or target.read_bytes() != want:
                    stale.append(f"{fw}: {out}/{name}")
            else:
                if not target.exists() or target.read_bytes() != want:
                    target.write_bytes(want)
                    print(f"  wrote  {out}/{name}")

    if check:
        if stale:
            print("\nFAIL: the committed CSS does not match a fresh compile of its source:")
            for s in stale:
                print(f"    {s}")
            print("\n  Run scripts/build-tina4css.py to regenerate, and commit the result.")
            return 1
        print("\nOK: every framework ships the current compile of tina4css.")
        return 0

    print("\nDone. Commit the regenerated CSS with the .scss change that caused it.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
