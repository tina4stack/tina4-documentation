# Task: Release Tina4 frameworks 3.13.103 at parity

**Outcome:** Python, PHP, Ruby, and Node.js publish the same 3.13.103 release
from tested v3 commits, with truthful runtime/package versions and release
notes covering the native metrics contract and Frond maintenance work.

## Scope

- [x] Sweep open issues across the Tina4 organization before release.
- [x] Verify full GitHub Actions suites are green on the current v3 heads.
- [x] Audit the 3.13.102 tags and public registries.
- [x] Cut fresh `feature/release3.13.103` branches from v3.
- [x] Bump every runtime, package, lockfile, guide, and version assertion.
- [x] Add 3.13.103 changelog entries in all four frameworks.
- [x] Add the release notes to all four documentation and book editions,
      plus the documentation landing page.
- [x] Add publish guards that reject a tag/source version mismatch.
- [x] Build the four distributable artifacts and verify embedded versions.
- [x] Merge release PRs into v3 and verify the exact merge heads.
- [x] Tag 3.13.103, wait for all publish workflows, and verify registries.
- [x] Delete the release branches and record final release commits.

## Parity

| Release property | Python | PHP | Ruby | Node.js |
| --- | --- | --- | --- | --- |
| Source version 3.13.103 | ✅ | ✅ | ✅ | ✅ |
| Changelog present | ✅ | ✅ | ✅ | ✅ |
| Tag/source guard | ✅ | ✅ | ✅ | ✅ |
| Full suite green | ✅ | ✅ | ✅ | ✅ |
| Public registry 3.13.103 | ✅ | ✅ | ✅ | ✅ |

## Tests

- [x] Existing version-contract suites pass in all four frameworks.
- [x] Python wheel metadata and runtime report 3.13.103.
- [x] PHP runtime reports 3.13.103 and Composer validates the package.
- [x] Both Ruby gems build as 3.13.103.
- [x] Node tarball metadata reports 3.13.103.
- [x] Documentation and book audits pass with matching release notes.
- [x] Publish workflows fail before registry mutation when tag and source differ.
- [x] Post-merge v3 workflows pass at the tagged commits.

## Bugs

- [x] RELEASE-102-RUBY: tag 3.13.102 built 3.13.101 and RubyGems rejected it.
- [x] RELEASE-102-NODE: tag 3.13.102 built 3.13.101 and npm rejected it.
- [x] RELEASE-VERSION-GUARD: publish workflows do not uniformly prove the tag
      matches the source package/runtime version before publishing.
- [x] RELEASE-103-NODE-PUBLISH: Node 22/npm 10 rejected optional Vitest/esbuild
      peer metadata omitted by the npm 11 lock generator. The exact tested
      package was published with the authenticated `tina4stack` account, and
      PR 47 completes the lock metadata without changing `package.json` or
      runtime dependencies.

## Lab evidence

The canonical isolated runner completed as root on
`andre@192.168.88.99` against the exact release commits after updating the
signed native client from 3.8.71 to 3.8.76:

- Python: 5,527 passed.
- PHP: 5,444 tests and 19,094 assertions.
- Ruby: 5,449 examples and 0 failures.
- Node.js: 8,436 passed and 0 skipped.
- Documentation: 10 audit tests passed, 2 environment-specific tests skipped,
  276 Markdown files passed strict link and anchor checks, and all 135 feature
  entries aligned.
- Book: the JavaScript reference build reproduced byte for byte.

## Tagged release commits

- Python: `915ec30d7a853dc051316150499543dee6f89e9d`
- PHP: `d2af43f2b7243d8c508341d24e4458f75652d384`
- Ruby: `4c915473c9e439bf0953cf9285bbb5d3557916d5`
- Node.js: `24668fe4906242e9326ea0c791db9783e206453a`
- Documentation: `15b1d0db39e616f0a806a616c8a5800663b7c59c`
- Book: `a48dae4fddf2d026277035e5670b6598c375830d`

## Publication

- PyPI: `tina4-python 3.13.103`
- Packagist: `tina4stack/tina4php 3.13.103`
- RubyGems: `tina4ruby 3.13.103`
- npm: `tina4-nodejs 3.13.103`
- GitHub: four non-draft, non-prerelease `3.13.103` releases.

## Status: Complete
