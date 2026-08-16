# Documentation-to-code parity

## Scope

- Verify public installation, initialization, serving, migration, testing, and scaffolding commands against the current Tina4 client and package metadata.
- Correct canonical book sources first, then synchronize the public documentation copies.
- Add executable checks for package identifiers, public links, primary lifecycle commands, and the Tina4 JS scaffold port.
- Rebuild and visually verify every affected book PDF.

## Confirmed mismatches

- [x] PHP, Ruby, and Node.js installation package identifiers now match their package manifests.
- [x] PHP, Ruby, and Node.js chapters now present the unified Tina4 client as the primary lifecycle workflow.
- [x] Tina4 JS chapters now match the unified scaffold syntax and port 5173.
- [x] Get-started pages now use valid site-local documentation links.
- [x] The truth audit now validates these developer-facing facts.

## Verification

- [x] New regression audit failed against 31 categories of known stale documentation before correction.
- [x] Canonical books and synchronized documentation pass the regression audit (12 tests).
- [x] Existing truth, feature, contract, dispatch, health, and link audits pass (135 features, 282 proven invariants, 0 broken links).
- [x] Documentation site builds successfully (276 pages).
- [x] Five affected PDFs build and representative changed pages pass visual inspection.

## Commits

- tina4-book `21e0c54` - canonical chapters and rebuilt PDFs.
- tina4-documentation - synchronized public pages, expanded truth gate, and this record.

## Status

Complete.
