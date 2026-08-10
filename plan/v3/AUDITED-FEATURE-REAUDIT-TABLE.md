# Re-audit inventory from `98-feature-audit.md`

Date: 2026-08-09. Source: the Progress table and its explicit count in
`98-feature-audit.md`. Audit-first phase; no framework code or tests changed.

## Count reconciliation

The audit file does **not** substantiate 44 completed features. It explicitly
states **32 of 98 features audited**. Expanding its grouped rows into individual
canonical feature numbers produces the same 32:

- Features 1-20: 20
- Feature 27: 1
- Features 28-32: 5
- Features 37-38: 2
- Features 41-43: 3
- Feature 48: 1
- **Total: 32**

Feature 47 Swagger, Feature 50 HTTP client and Feature 55 Messenger have evidence
elsewhere in the contract map or later work, but the audit file does not include
them in its stated 32. They are listed separately below rather than silently
changing the audit's denominator. There is no evidence-backed route from 32 to
44 in the audit file.

Every prior closure is reopened for the owner-directed 3.14 adversarial audit and
its one-feature/one-file language-port packet. "Prior state" is historical
evidence, not a current completed verdict.

## The 32 features recorded as audited

| # | Feature | Prior audit state in `98-feature-audit.md` | Current 3.14 state | Individual packet |
| ---: | --- | --- | --- | --- |
| 1 | DotEnv parser | Re-closed, then contradicted again | **Contract complete 2026-08-09; implementation pending after full audit** | `001-dotenv.md` has settled owner decisions, exact conformance cases and complete porting capsule |
| 2 | Structured logger | Closed after five fixes | **Contract complete 2026-08-09; implementation pending after full audit** | `002-structured-logger.md` has 59 cases and a complete porting capsule |
| 3 | Database adapter interface | Closed after redesign | **Contract complete 2026-08-10; implementation pending after full audit** | `003-database-adapter-interface.md` supersedes the false 14-method boundary; ADR-0044 + 38-case fixture |
| 4 | Database adapters / SQLite write path | Effectively closed; one item deferred | Reopened / queued; provider split required | `004-sqlite-adapter.md` exists; 4.1-4.7 packets owed |
| 5 | DATABASE_URL parser | Shipped all four | Reopened / queued | `005-database-url-parser.md` exists |
| 6 | Router and dispatch | Closed with one follow-on | Reopened / queued | `006-router-and-dispatch.md` exists |
| 7 | Middleware pipeline | Closed / merged | Reopened / queued | `007-middleware-pipeline.md` exists |
| 8 | Health endpoint | Closed / merged | Reopened / queued | `008-health-check.md` exists |
| 9 | Graceful shutdown | Closed / merged | Reopened / queued | `009-graceful-shutdown.md` exists |
| 10 | CORS middleware | Closed / merged | Reopened / queued | `010-cors-middleware.md` exists |
| 11 | Rate limiter | Closed only inside 11/12/79 bundle | Reopened / queued | Own `011-*.md` owed |
| 12 | Response types | Closed only inside 11/12/79 bundle | Reopened / queued | Own `012-*.md` owed |
| 13 | ORM base class | Closed | Reopened / queued | `013-orm-base-class.md` exists |
| 14 | Soft delete | Closed with one outstanding item | Reopened / queued | `014-soft-delete.md` exists |
| 15 | Relationships and eager load | Closed | Reopened / queued | `015-relationships.md` exists |
| 16 | Scopes | Closed | Reopened / queued | `016-scopes.md` exists |
| 17 | Field mapping | Closed / ADR-0008 | Reopened / queued | `017-field-mapping.md` exists |
| 18 | Paginated results | Incorrectly closed, then reopened | **Known correctness defects** | `018-paginated-results.md` exists; port capsule incomplete |
| 19 | ORM/result caching | Closed | Reopened / queued | `019-orm-result-caching.md` exists |
| 20 | Input validation | Closed after verdict revision | Reopened / queued | `020-input-validation.md` exists |
| 27 | Migrations | New audit in progress | **Known discovery, rollback and shape defects** | `027-migrations.md` exists; port capsule incomplete |
| 28 | Frond lexer | Closed only inside 28-31 bundle | Reopened / queued | Own `028-*.md` owed |
| 29 | Frond parser | Closed only inside 28-31 bundle | Reopened / queued | Own `029-*.md` owed |
| 30 | Frond compiler | Closed only inside 28-31 bundle | Reopened / queued | Own `030-*.md` owed |
| 31 | Frond runtime | Closed only inside 28-31 bundle | Reopened / queued | Own `031-*.md` owed |
| 32 | Frond filters | Closed | Reopened / queued | `032-frond-filters.md` exists |
| 37 | Frond auto-escaping | Closed with an owner call recorded | Reopened / queued | `037-auto-escaping.md` exists |
| 38 | Frond sandboxing | Shipped all four | Reopened / queued | `038-sandboxing.md` exists |
| 41 | JWT authentication | Closed only inside 41/42 bundle | Reopened / queued | Own `041-*.md` owed |
| 42 | Session handling | Closed only inside 41/42 bundle | Reopened / queued; 42.1-42.6 packets owed | Own `042-*.md` owed |
| 43 | Cache backends | Closed / merged | Reopened / queued; 43.1-43.7 packets owed | `043-caching.md` exists |
| 48 | Queue backends | Closed / merged | Reopened / queued; 48.1-48.4 packets owed | `048-queue-backends.md` exists |

## Audited or contracted outside the stated 32

| # | Feature | Evidence source | Current treatment |
| ---: | --- | --- | --- |
| 47 | Swagger / OpenAPI | Layer-2 contract map, 10 invariants | Re-audit in numeric order; own packet owed |
| 50 | HTTP client | Later surface-parity work, no fixture | Re-audit in numeric order; own packet owed |
| 55 | Email / Messenger | Historical pilot + 14-invariant fixture + GreenMail | Re-audit in numeric order; `055-email-messenger.md` started |

DocStore and tina4css also have Layer-2 fixtures but no settled canonical feature
numbers. They remain outside the numbered count until the union matrix assigns
their identities.

## Honest dashboard

| Claim | Supported? | Evidence-backed replacement |
| --- | --- | --- |
| 44 completed features | **No** | No 44-row completed set exists in the audit file |
| 32 previously audited features | **Yes, historically** | Exact expansion above |
| 32 currently complete under the 3.14 rules | **No** | All are reopened; Features 1, 18 and 27 already have known defects |
| Individual language-port packets complete | **No** | Existing grouped plans must be split and every packet needs the new capsule |

The current audit queue therefore starts with Feature 1 and processes these
features in numeric order, while separately adding every feature missing from
the old audit's 98-row universe. Completion will be claimed only from the final
canonical union table, never from the old 44, 55, 93 or 98 marketing counts.
