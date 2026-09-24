# ISO alignment plan

- **Status:** in progress (started 2026-09-24)
- **Program lead:** Andre van Zuydam (Code Infinity)
- **Scope (phase 1):** `tina4` (CLI), `tina4-python`, `tina4-php`, `tina4-ruby`, `tina4-nodejs`, `tina4-js`, `tina4-documentation`
- **Standing rule:** ADR-0073 makes the controls below mandatory for every change.
- **Not for marketing.** Nothing in this plan is to be claimed publicly until the matching evidence exists. The first public statement is the OpenChain conformance declaration at the end of Phase 5.

## Goal

Developers who work inside an ISO/IEC 27001 programme must show their auditor that the tools they build with are developed and shipped securely. Tina4 should give them that evidence out of the box, so choosing Tina4 closes controls for them instead of opening findings.

## Targets

An open-source framework cannot itself be "ISO 27001 certified". The certifiable and defensible targets, in order:

| # | Target | Standard | Earned by | When |
|---|---|---|---|---|
| T1 | Tina4's open-source security assurance programme conforms to ISO/IEC 18974 | OpenChain Security Assurance | Self-certification against the specification checklist (optional third-party assessment) | Phase 5 |
| T2 | Tina4's licence compliance programme conforms to ISO/IEC 5230 | OpenChain Licence Compliance | Self-certification, as T1 | Phase 5 |
| T3 | Every release ships an SBOM, checksums, provenance, and advisories for fixed vulnerabilities | ISO/IEC 5962 (SPDX), ISO/IEC 29147 (disclosure), ISO/IEC 30111 (handling) | Release pipeline and process | Phases 1-2 |
| T4 | A published ISO/IEC 27001:2022 Annex A shared-responsibility matrix | ISO/IEC 27001 Annex A | Documentation page, every row backed by code and tests | Phase 4 |
| T5 | Tina4 is developed under an ISO/IEC 27001-certified ISMS | ISO/IEC 27001 | Code Infinity ISMS, audited by an accredited body | Decision D6 |

## Phase 0 - Repository governance (target 2026-10-02)

These are the controls an assessor checks first: that every change to released code is traceable, reviewed by CI, and cannot be rewritten.

| ID | Control | How | Status |
|---|---|---|---|
| G1 | Release branches require a pull request and passing CI; no force-push or deletion | Rulesets `tina4-release-line` and `tina4-maintenance-lines` | Done 2026-09-24 (`plan/iso/evidence/2026-09-24-github-controls.txt`) |
| G2 | Release tags cannot be moved or deleted | Ruleset `tina4-release-tags` | Done 2026-09-24 |
| G3 | Private vulnerability reporting | GitHub private vulnerability reporting | Done 2026-09-24 |
| G4 | Secret scanning with push protection | GitHub secret scanning | Done 2026-09-24 |
| G5 | Dependabot vulnerability alerts | GitHub | Done 2026-09-24 |
| G6 | A published security policy in every repository | `SECURITY.md` (supported versions, reporting channels, response targets, disclosure) | Done: merged in all seven repositories |
| G7 | CI runs on every pull request in every in-scope repository | tina4-js had none; `ci.yml` added (tina4-js#17) | Done |
| G8 | Release automation works under branch protection | CLI `release-published.yml` opens a manifests PR instead of pushing to `main` (tina4#32) | Done |
| G9 | Two-factor authentication on every account with write access | Each collaborator confirms; enforced automatically once D2 is done | Done 2026-09-24: access reduced to tina4stack + andrevanzuydam, both with 2FA (`plan/iso/evidence/2026-09-24-access-and-2fa.txt`) |
| G10 | Static analysis runs on the active line | tina4-php CodeQL targets `main`, not `v3`; extend CodeQL to all four frameworks and tina4-js | Done 2026-09-24 for 6 repos (CodeQL default setup, extended); tina4-php pending tina4-php#221 (Semgrep for PHP source, then CodeQL default setup for JS/Actions) |

Controls G1-G5 are declared in `scripts/governance/github-controls.json` and applied or verified by `scripts/governance/github_controls.py`:

```bash
python3 scripts/governance/github_controls.py --check   # anyone, read-only; the output is audit evidence
python3 scripts/governance/github_controls.py --apply   # repository admin only
```

**Working-practice change:** once G1 is applied, nothing is pushed straight to `v3`, `main` or `master`. Every change, including releases and hotfixes, goes through a pull request.

## Phase 1 - Vulnerability handling (target 2026-10-31)

ISO/IEC 18974 asks for a documented method to detect known vulnerabilities, respond to them, and follow them up after release. ISO/IEC 29147 and 30111 describe how.

1. **Process document** (`plan/iso/VULNERABILITY-HANDLING.md`, written 2026-09-24): intake (the G3 channel or email), triage with CVSS v3.1, fix in all four frameworks (the parity rule), private GitHub Security Advisory, CVE request, coordinated release, public advisory, release note. The response targets are the ones in `SECURITY.md`.
2. **Advisories for already-fixed issues:** publish advisories for security fixes that shipped without one, starting with the SQL injection fixed under tina4-php #209.
3. **Security audit remediation:** the September 2026 audit covered injection, authentication and sessions, the HTTP surface, development surfaces, templates, the frontend library and the supply chain. Findings are tracked in private draft advisories and fixed through the process in step 1. They are not listed here until each is fixed and disclosed.
4. **Security regression tests:** every fixed vulnerability gets a no-mock regression test in each affected framework, plus a shared contract fixture wherever the behaviour is cross-framework.
5. **Missing contract gates:** make every contract an ADR cites exist and run in CI (for example `cors_contract.json`, cited by ADR-0048).

## Phase 2 - Supply chain and release integrity (target 2026-11-13)

| ID | Control | Notes |
|---|---|---|
| S1 | SBOM (SPDX 2.3 JSON, ISO/IEC 5962 lineage) attached to every release | Generated by our own tooling from the lockfiles/manifests: no new dependencies |
| S2 | Every GitHub Action pinned by commit SHA | Already true for the CLI release; not yet for the framework and tina4-js publish workflows |
| S3 | Registry publishing through trusted publishing (OIDC) | PyPI, npm and RubyGems; retire the long-lived tokens |
| S4 | Publish jobs behind a protected `release` environment with a required reviewer | Creates a human approval record for every release |
| S5 | Build provenance attestations for every artefact | npm `--provenance` on tina4-nodejs as well as tina4-js; GitHub attestations for the CLI binaries and images |
| S6 | Signing verifies before it signs | The EV-signing scripts check each asset against the CI attestation and CI checksums before signing |
| S7 | Installers and `tina4 update` verify integrity | No checksum skip; signature check on Windows |
| S8 | Package namespaces that the docs reference are owned by us | Includes claiming the `@tina4` npm scope |
| S9 | The zero-dependency claim is true for every framework | Ruby and Node currently ship runtime or default-installed dependencies; make the claim true (the zero-dependency rule), not the docs vaguer |
| S10 | Container images: non-root, digest-pinned bases, published with provenance | Deploy templates and framework images |

## Phase 3 - Licence compliance, ISO/IEC 5230 (target 2026-11-27)

1. Licence policy: which inbound licences are acceptable, and how contributions are licensed (DCO sign-off).
2. Licence inventory per release, produced with the S1 SBOM. The CLI's crate graph is the largest item; the frameworks are near zero by design.
3. Licence check on every PR: `cargo-deny` licences for the CLI, and an equivalent own-tooling check for the frameworks and tina4-js.
4. Third-party notices shipped with the CLI binary.
5. Programme roles and competence: who approves what, recorded in this directory.

## Phase 4 - Annex A shared-responsibility matrix (target 2026-12-04)

A public page, `docs/general/security-controls.md`, maps ISO/IEC 27001:2022 Annex A controls to what Tina4 does by default and what the application developer still owns. The first draft covers:

| Annex A | Topic | Tina4 provides (to be evidenced per row) |
|---|---|---|
| A.5.8 / A.8.25 | Secure development life cycle | This programme: protected branches, CI, advisories, SBOM |
| A.8.5 | Secure authentication | Signed tokens with a pinned algorithm, PBKDF2 password hashing |
| A.8.9 | Configuration management | Secure defaults, debug off by default, startup refusal of unsafe settings |
| A.8.12 | Data leakage prevention | Production error pages without internals |
| A.8.15 / A.8.16 | Logging and monitoring | Structured logs, request ids |
| A.8.24 | Use of cryptography | Constant-time comparisons, CSPRNG session ids, HMAC and RS256 |
| A.8.26 | Application security requirements | Security headers, CSRF protection, CORS denied by default |
| A.8.28 | Secure coding | Parameterised queries, auto-escaping templates |
| A.8.29 | Security testing | No-mock test suites, contract fixtures, the security audit |
| A.8.8 | Technical vulnerability management | Advisories, supported-version policy, SBOM |

This page lives under `docs/`, so the truth gate applies: a row is published only when the behaviour exists in all four frameworks and a test proves it. It goes live only after the related Phase 1 fixes ship.

## Phase 5 - OpenChain self-certification (target 2026-12-11)

1. Walk the ISO/IEC 18974 and ISO/IEC 5230 conformance checklists; record the evidence for each requirement in `plan/iso/CONFORMANCE.md` (policy, competence, awareness, scope, SBOM, known-vulnerability method, adherence, review period).
2. Internal review, then submit the OpenChain self-certification for both.
3. Only then publish a conformance statement on tina4.com.
4. Re-certify every 18 months, or when the programme changes materially.

## Decisions needed

| ID | Decision | Default until decided |
|---|---|---|
| D1 | Required approving reviews on release branches: 0 or 1 | 0: most repositories have one maintainer, and GitHub does not let authors approve their own PRs. Compensating controls: mandatory PR, required CI, immutable history. Move to 1 when a second maintainer reviews. |
| D2 | Move the repositories from the `tina4stack` user account to a GitHub organisation | Stay. An organisation adds enforced 2FA, an audit log, teams, organisation-wide rulesets and a default `SECURITY.md`, all of which an assessor will ask about. |
| D3 | 2.x support window | "Critical and High fixes only, best effort", as `SECURITY.md` states |
| D4 | Response targets in `SECURITY.md` (3 / 10 / 30 / 90 days) | As published |
| D5 | Dedicated security contact (for example `security@tina4.com`) | `info@tina4.com` |
| D6 | Pursue ISO/IEC 27001 certification for Code Infinity (T5) | Not before T1 and T2 are done |
| D7 | Scope phase 2: tina4-css, tina4press, tina4delphi, tina4pascal, the `tina4php-*` packages, tina4-book | Phase 1 repositories only |

## Evidence register

| Evidence | Where |
|---|---|
| Repository controls | `github_controls.py --check` output, kept with each quarterly review |
| Change history | Pull requests on the release branches |
| Vulnerability handling | GitHub Security Advisories per repository, CVE records, release notes |
| SBOM and provenance | Release assets and registry attestations |
| Test evidence | CI runs on each release commit, lab sweep logs |
| Decisions | This file, and `plan/v3/decisions/` for technical ADRs |

## Log

- 2026-09-24: plan written. `SECURITY.md` and CI prerequisites opened as PRs in all seven repositories. Control script and configuration added; `--check` reports 46 controls missing, pending the admin `--apply`. Security audit under way.
- 2026-09-24: G1-G8 done. The repository admin applied the rulesets, private vulnerability reporting, secret scanning with push protection and Dependabot alerts to all seven repositories; `--check` reports all controls in place (evidence file above). ADR-0073 makes the controls a standing rule.
- 2026-09-24: G9 done. Direct access reduced to the owner (tina4stack) and the maintainer (andrevanzuydam); four write collaborators removed, now contributing through fork pull requests. Both remaining accounts confirmed with 2FA enabled.
- 2026-09-24: G10 started. CodeQL default setup (extended suite) enabled on tina4, tina4-python, tina4-ruby, tina4-nodejs, tina4-js and tina4-documentation; it scans the default branch and every pull request. CodeQL cannot analyse PHP, so tina4-php#221 adds Semgrep for PHP source and retires the old main-only CodeQL workflow. `github_controls.py` now checks and applies default setup. First-scan alerts are triaged under Phase 1.
- 2026-09-24: Policies written. Public: `docs/general/contributing.md` (contributors), `docs/general/security-research.md` (investigators, with safe harbour, no bounty) and `docs/general/contributor-licence-agreement.md` (draft, pending legal review). Internal: `plan/iso/VULNERABILITY-HANDLING.md` (ISO/IEC 30111). Licence decision recorded as ADR-0075 (MPL-2.0 plus a Code Infinity commercial licence; copyright holder Code Infinity), pending legal review and outside-contributor consent; the author list is held privately.

- 2026-09-24: The maintainer confirmed ADR-0075 legal review and contributor consent complete. MPL-2.0, Code Infinity copyright and the optional commercial-licence notice apply from 3.13.138; previously published versions retain their historical licensing. Release PRs add an explicit inbound-dependency licence inventory and fail-closed policy check (ADR-0073 control 6); final CI evidence remains pending.
