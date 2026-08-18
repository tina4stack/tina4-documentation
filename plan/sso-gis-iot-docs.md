# Task: Complete SSO, GIS, and IoT documentation

**Outcome:** A developer can discover and use SSO, GIS, and MQTT from every
language quick reference and sidebar, with examples that match the released
3.13.104 APIs.

## Scope

- [x] Audit public chapters, quick references, sidebar registration, and live URLs.
- [x] Read Features 94, 136, and 137 plus ADR-0056 and ADR-0057.
- [x] Expand all four SSO chapters to the complete public lifecycle and security contract.
- [x] Expand all four GIS chapters to the complete Point, query, and GeoJSON contract.
- [x] Add one IoT/MQTT chapter for each backend with the idiomatic released API.
- [x] Add SSO, GIS, and IoT/MQTT to all four quick references.
- [x] Register all three chapter stems in the shared backend sidebar.
- [x] Build the site, run strict truth/link/catalog audits, and check rendered pages.
- [x] Merge to documentation `main` and verify tina4.com navigation.
- [x] Update the source books and regenerate the four backend PDFs.

## Parity

| Documentation | Python | PHP | Ruby | Node.js |
| --- | --- | --- | --- | --- |
| SSO chapter | Complete | Complete | Complete | Complete |
| GIS chapter | Complete | Complete | Complete | Complete |
| IoT/MQTT chapter | Complete | Complete | Complete | Complete |
| Quick reference | Complete | Complete | Complete | Complete |
| Sidebar | Complete | Complete | Complete | Complete |

## Tests

- [x] Every documented `tina4` command and `TINA4_*` variable passes `audit-truth.py --strict --strict-env`.
- [x] Every internal link and anchor passes `audit-links.py --strict --strict-anchors`.
- [x] The feature catalog audit passes.
- [x] Tina4Press builds every page.
- [x] Rendered navigation contains SSO, GIS, and IoT/MQTT for all four backends.
- [x] Live chapter URLs return 200 after deployment.

## Bugs

- [x] DOC-NAV-SSO-GIS: SSO and GIS pages exist but have no sidebar or quick-reference entry.
- [x] DOC-IOT-MISSING: MQTT ships in all four frameworks but has no public guide.
- [x] DOC-PARITY-SHALLOW: PHP, Ruby, and Node.js SSO/GIS pages omit major public operations.

## Commits

- `ac52dbe` - complete the SSO, GIS, and IoT/MQTT documentation across all four backends.
- `7145d32` - merge documentation pull request 58.
- `76bc0f8` - synchronize the source books in tina4-book pull request 154.
- `dea762f` - mirror the regenerated PDFs back into the documentation repository.

## Status: Complete
