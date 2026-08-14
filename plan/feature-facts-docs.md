# Task: Correct public feature facts

Outcome: The books and website describe the 3.14 feature catalog without turning an inventory count into a parity claim. The catalog, audit ledger, contract map, and public feature pages agree on their counts and boundaries.

## Scope

- [x] Reconcile the flat catalog with Features 134 and 135.
- [x] Correct stale 133-feature references in the active audit ledger.
- [x] Replace the four unsupported 97-feature parity claims with catalog-backed facts.
- [x] Distinguish backend features, the shared Rust CLI, and separate frontend tooling.
- [x] State the fixture coverage exactly: 55 fixtures and 282 proven invariants, not 135 fully proven features.
- [x] Keep known PHP and Node parity gaps visible.
- [x] Define dependencies as extra installable packages; do not count language extensions.
- [x] Correct stale feature-count and parity claims in package metadata.
- [x] Add a repeatable catalog and public-page fact gate.
- [x] Sync the canonical books into the website and regenerate affected PDFs.
- [x] Commit each affected repository with the Tina4 co-author trailer.

## Parity

| Documentation fact | Python | PHP | Ruby | Node.js |
|---|---:|---:|---:|---:|
| 135-entry public catalog | ✅ Aligned | ✅ Aligned | ✅ Aligned | ✅ Aligned |
| Entire catalog at parity | ⚠️ Not proven | ⚠️ Not proven | ⚠️ Not proven | ⚠️ Not proven |
| Fixture-covered contracts | ✅ 282 proven | ✅ 282 proven | ✅ 282 proven | ✅ 282 proven |

## Tests

- [x] Validate `FEATURE-CATALOG.json`: 135 unique, contiguous IDs and valid packet paths.
- [x] Run the contract fixture auditor and use its reported counts.
- [x] Run book synchronization, strict truth audit, strict link audit, and the tina4press build.
- [x] Rebuild the Understanding and four backend PDFs, prove reproducibility, and inspect the corrected pages.

## Bugs

- [x] `FEATURE-CATALOG.json` stops at Feature 133 although the active matrix includes 134 and 135.
- [x] `98-feature-audit.md` still defines the walk as 1 through 133.
- [x] All four public feature chapters claim 97 identical features and complete four-language test coverage.
- [x] The feature chapters count the shared Rust CLI and separate tina4-js package as backend-built-ins.
- [x] The feature chapters still list metrics inside each backend framework.
- [x] PHP, Ruby, and Node package metadata advertises stale feature counts or unsupported parity facts.
- [x] The catalog generator can erase audited matrix evidence and does not understand Features 134-135.
- [x] Catalog packet paths for Features 26 and 37 do not match their files.
- [x] The Understanding book uses unsupported tree glyphs in PDF output and lists Node.js 20 instead of 22.

## Commits

- `4cb3edd9` - Correct PHP package feature facts.
- `6243d3a` - Correct Ruby package feature and parity facts.
- `eb66d0b` - Correct Node.js package feature facts.
- `19cc763` - Replace the book feature claims and regenerate verified PDFs.
- This commit - Align the audit catalog, website, fact gate, and completed plan.

## Status: Complete
