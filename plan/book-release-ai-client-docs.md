# Task: Restore release notes and document the AI client

Outcome: `tina4-book` becomes the canonical source for the 3.13.98 through 3.13.101 release notes and a complete app-facing AI client chapter in Python, PHP, Ruby, and Node.js; the website and downloadable PDFs carry the same material.

## Scope

- [x] Backfill release notes 3.13.98 through 3.13.101 into all four backend books.
- [x] Add one AI client chapter with language-idiomatic examples to all four books.
- [x] Distinguish the app-facing AI client from the `tina4 ai` skills installer.
- [x] Add the chapter to the book contents and website sidebar.
- [x] Sync the canonical books into `tina4-documentation`.
- [x] Update the four backend book version stamps to 3.13.101.
- [x] Regenerate the backend PDFs.
- [x] Commit the book and documentation repositories with the Tina4 co-author trailer.

## Parity

| Documentation | Python | PHP | Ruby | Node.js |
|---|---:|---:|---:|---:|
| 3.13.98-3.13.101 release notes | ✅ Complete | ✅ Complete | ✅ Complete | ✅ Complete |
| AI client chapter | ✅ Complete | ✅ Complete | ✅ Complete | ✅ Complete |
| Website page | ✅ Complete | ✅ Complete | ✅ Complete | ✅ Complete |
| Regenerated PDF | ✅ Complete | ✅ Complete | ✅ Complete | ✅ Complete |

## Tests

- [x] Confirm every documented class, method, option, response field, error, provider, and environment variable exists in released source.
- [x] Run the book reproducibility test and build all backend PDFs.
- [x] Run `sync-books.sh`, the strict truth audit, link audit, and documentation build.
- [x] Confirm the synced release notes contain 3.13.100 and the synced AI client pages exist in all four sections.

## Bugs

- [x] The publishing direction was reversed: release notes were edited in `tina4-documentation`, although `tina4-book` is the sync source.
- [x] The four backend `book.yml` files still stamp PDFs as v3.13.85.
- [x] `audit-truth.py` used ripgrep's ambiguous `-h` flag, which ripgrep 15 treats as help, and parsed the help page as the environment manifest.
- [x] The truth gate classified bracketed framework constants such as `[TINA4_LOG_ALL]` as operating-system environment variables.

## Commits

- `tina4-book`: `0f771bd` (`docs: add 3.13.101 AI client guides`)
- `tina4-documentation`: this task's completion commit

## Status: Complete
