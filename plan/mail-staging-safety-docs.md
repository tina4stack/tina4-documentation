# Task: Document staging mail safety controls

**Outcome:** Developers can disable real delivery or redirect every recipient on
staging from each language email guide and environment-variable registry.

## Scope

- [x] Verify the released behavior in all four framework implementations.
- [x] Read the mail redirect and messenger contract fixtures.
- [x] Document `TINA4_MAIL_CAPTURE` and `TINA4_MAIL_REDIRECT_TO` in all four email chapters.
- [x] Register both variables in all four language environment references and the general registry.
- [x] Remove the false claim that `TINA4_DEBUG` disables SMTP delivery.
- [x] Synchronize the corrected chapters into `tina4-book`.
- [ ] Build, audit, merge, and verify the live pages and regenerated PDFs.

## Parity

| Documentation | Python | PHP | Ruby | Node.js |
| --- | --- | --- | --- | --- |
| Email safety guide | Complete | Complete | Complete | Complete |
| Environment registry | Complete | Complete | Complete | Complete |
| Correct capture rule | Correct | Correct | Correct | Correct |

## Tests

- [x] Strict documentation truth audit passes.
- [x] Strict link and anchor audit passes.
- [x] Feature catalog audit passes.
- [x] Tina4Press builds every page.
- [ ] Source-book PDF build passes and mirrors the PDFs.
- [ ] Live email and environment pages show both settings.

## Bugs

- [x] DOC-MAIL-SAFETY-MISSING: staging capture and recipient redirect are absent from public docs.
- [x] DOC-MAIL-DEBUG-FALSE: the email guides claim debug mode suppresses delivery, but code does not.
- [x] DOC-MAILBOX-DISABLE-FALSE: the guides recommend a mailbox-directory value as a delivery switch.

## Commits

- `f4955cc` - correct and expand the source-book mail safety documentation.

## Status: In progress
