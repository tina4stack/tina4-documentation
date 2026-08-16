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
- [ ] Build the four distributable artifacts and verify embedded versions.
- [ ] Merge release PRs into v3 and verify the exact merge heads.
- [ ] Tag 3.13.103, wait for all publish workflows, and verify registries.
- [ ] Delete the release branches and record final release commits.

## Parity

| Release property | Python | PHP | Ruby | Node.js |
| --- | --- | --- | --- | --- |
| Source version 3.13.103 | ✅ | ✅ | ✅ | ✅ |
| Changelog present | ✅ | ✅ | ✅ | ✅ |
| Tag/source guard | ✅ | ✅ | ✅ | ✅ |
| Full suite green | ✅ | ✅ | ✅ | ✅ |
| Public registry 3.13.103 | ⏳ | ⏳ | ⏳ | ⏳ |

## Tests

- [ ] Existing version-contract suites pass in all four frameworks.
- [ ] Python wheel metadata and runtime report 3.13.103.
- [ ] PHP runtime reports 3.13.103 and Composer validates the package.
- [ ] Both Ruby gems build as 3.13.103.
- [ ] Node tarball metadata reports 3.13.103.
- [ ] Documentation and book audits pass with matching release notes.
- [ ] Publish workflows fail before registry mutation when tag and source differ.
- [ ] Post-merge v3 workflows pass at the tagged commits.

## Bugs

- [x] RELEASE-102-RUBY: tag 3.13.102 built 3.13.101 and RubyGems rejected it.
- [x] RELEASE-102-NODE: tag 3.13.102 built 3.13.101 and npm rejected it.
- [x] RELEASE-VERSION-GUARD: publish workflows do not uniformly prove the tag
      matches the source package/runtime version before publishing.

## Commits

- Pending.

## Status: In progress
