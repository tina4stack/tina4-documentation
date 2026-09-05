# Unified Tina4 feature manager

## Outcome

Give every Tina4 project one language-neutral way to opt into optional
capabilities:

```bash
tina4 feature enable web-push
tina4 feature enable database postgres
tina4 feature enable graph neo4j
tina4 feature status
tina4 feature list
```

The Tina4 client owns the feature workflow. It records the project choice,
performs the correct language-specific package or extension check, writes only
safe configuration defaults, and reports a repairable error when the selected
capability is unavailable. Developers must not need to learn `uv add`,
`composer require`, `bundle add`, or `npm install` for a Tina4 feature.

The feature manager preserves the Tina4 core rule: the framework core remains
zero third-party runtime dependencies. A selected integration may add a real
package or require a language extension; language extensions do not count as
packages, and an optional package is installed only when the project selects
that feature.

## Scope

- [ ] Add `tina4 feature list`.
- [ ] Add `tina4 feature enable <feature> [variant]`.
- [ ] Add `tina4 feature status`.
- [ ] Add `tina4 feature disable <feature> [variant]`.
- [ ] Define and validate a committed `.tina4/features.json` project manifest.
- [ ] Add a versioned feature registry to the Tina4 Rust client.
- [ ] Add per-language installers and capability checks for Python, PHP, Ruby,
  and Node.js.
- [ ] Add Web Push as the first end-to-end feature.
- [ ] Add database variants, beginning with PostgreSQL, MySQL, MSSQL, Firebird,
  MongoDB, and ODBC where the framework exposes them.
- [ ] Add graph variants for Ultipa, Neo4j, Memgraph, and ArangoDB.
- [ ] Keep the default scaffold unchanged when no optional feature is enabled.
- [ ] Document the command and feature catalogue in the Tina4 books,
  documentation site, quick references, and all relevant AI skills.

## Contract decisions

### Command surface

The Rust Tina4 client is the only public entry point:

```text
tina4 feature list
tina4 feature enable <name> [variant]
tina4 feature status [name] [variant]
tina4 feature disable <name> [variant]
```

Feature names are stable logical names. Variants select a provider or engine.
The parser accepts both the readable two-argument form and an unambiguous
alias form for automation:

```text
tina4 feature enable database postgres
tina4 feature enable database:postgres
```

The canonical output always uses the two-column form. Unknown names and
variants fail before changing the project.

`enable` is idempotent. `disable` removes the manifest selection and generated
non-secret configuration, but does not uninstall packages by default. Package
removal is a separate, explicit cleanup operation so the command cannot remove
dependencies that the application still uses.

### Project manifest

The client writes a committed `.tina4/features.json` file. The initial schema
is intentionally small and language-neutral:

```json
{
  "version": 1,
  "features": [
    {"name": "web-push"},
    {"name": "database", "variant": "postgres"},
    {"name": "graph", "variant": "neo4j"}
  ]
}
```

The manifest is declarative state, not a secret store. VAPID keys, database
passwords, and provider tokens remain in `.env` or the deployment secret
manager. The manifest is sorted and deduplicated so repeated commands produce
stable diffs.

### Feature registry

Each registry entry contains:

| Field | Purpose |
| --- | --- |
| `name` / `variant` | Stable public identifier |
| `description` | CLI and documentation summary |
| `env` | Configuration keys and defaults, never secret values |
| `python` / `php` / `ruby` / `node` | Install and capability-check strategy |
| `health` | Non-destructive verification command or probe |
| `fixtures` | Shared contract fixture and required live services |
| `docs` / `skills` | Canonical documentation and skill references |

The registry is data, not four copies of branching logic. Language adapters
execute the registry instruction using the existing package manager or runtime
conventions. The client never edits framework source files.

### Dependency and extension policy

- Core framework dependencies remain unchanged.
- Python optional packages are added through the project environment only when
  the feature is enabled; Web Push may use lazy `cryptography`.
- PHP extensions such as `ext-openssl`, `ext-pdo`, and `ext-pgsql` are checked
  as runtime capabilities, not Composer packages.
- Ruby OpenSSL and database driver capabilities are checked through Bundler and
  the Ruby runtime; optional gems are added only for selected variants.
- Node uses built-in capabilities where available and installs an adapter only
  where the selected provider needs one.
- `status` distinguishes `enabled`, `ready`, `missing capability`,
  `misconfigured`, and `disabled`.
- A configured feature that lacks its required capability fails loudly at
  `status`, and framework boot fails when the feature is active. No silent
  fallback or algorithm downgrade is allowed.

## Feature rollout

### Phase 0 — Contract and registry

- [ ] Add an ADR for the feature-manager command, manifest, and failure rules.
- [ ] Add the registry schema and parser tests to the Tina4 client.
- [ ] Define the shared status envelope for human and `--json` output.
- [ ] Add the feature names and variants to the feature catalogue.
- [ ] Add the manifest to scaffolded projects and `.gitignore` rules only where
  the file is generated state rather than project intent.

### Phase 1 — Tina4 client commands

- [ ] Implement `list`, `enable`, `status`, and `disable` in the Rust CLI.
- [ ] Make all mutations atomic and preserve an existing manifest on failure.
- [ ] Support dry-run and `--json` output for automation and AI tooling.
- [ ] Detect the framework from the project rather than from a user-supplied
  package-manager command.
- [ ] Ensure commands work from the project directory and through
  `tina4 serve <project>` discovery.

### Phase 2 — Language adapters

- [ ] Python adapter: update the project environment for selected extras,
  verify imports lazily, and preserve `dependencies = []` in the framework.
- [ ] PHP adapter: check required extensions and optional Composer packages;
  report the exact platform repair without modifying system PHP silently.
- [ ] Ruby adapter: update the selected optional Bundler group and verify the
  OpenSSL/runtime capability.
- [ ] Node adapter: detect native support first, then install only a registry
  adapter that the selected provider actually needs.
- [ ] Add idempotence, rollback, and missing-tool tests for each adapter.

### Phase 3 — Web Push

- [ ] Add the shared Web Push contract and configuration names:
  `TINA4_WEB_PUSH`, `TINA4_VAPID_PUBLIC`, `TINA4_VAPID_PRIVATE`, and
  `TINA4_VAPID_SUBJECT`.
- [ ] Implement the Python optional crypto backend with a clear missing-extra
  error.
- [ ] Implement PHP and Ruby with their existing OpenSSL capabilities.
- [ ] Implement Node with built-in `node:crypto` and `fetch`.
- [ ] Add the tina4-js browser subscription helper without a new runtime
  dependency.
- [ ] Add key generation, subscription validation, encryption, delivery, and
  dead-subscription cleanup to the shared fixtures.

### Phase 4 — Database and graph variants

- [ ] Map every existing database adapter and graph provider to a feature
  variant rather than inventing new framework-specific install instructions.
- [ ] Make `enable` select the adapter, write non-secret env defaults, and
  leave the application code unchanged.
- [ ] Make `status` verify both the package/extension and the configured service
  URL without creating or mutating user data.
- [ ] Add real-service fixture runs on the lab for every provisioned provider;
  absent services must produce a labelled capability result, not a false pass.

### Phase 5 — Documentation and skills

- [ ] Add one canonical feature-manager chapter to the documentation site and
  Tina4 book.
- [ ] Add command reference and JSON output examples to the CLI chapters for
  Python, PHP, Ruby, and Node.js.
- [ ] Add database, graph, Web Push, and capability-status examples to each
  applicable language quick reference.
- [ ] Update `tina4-maintainer`, `tina4-architect`, `tina4-developer-python`,
  `tina4-developer-php`, `tina4-developer-ruby`, `tina4-developer-nodejs`, and
  `tina4-js` skills.
- [ ] Make the skills lead with `tina4 feature enable` and `tina4 feature
  status`; package-manager commands may appear only as troubleshooting output.
- [ ] Synchronize Claude, Codex, and Cursor skill copies from their canonical
  sources and test the installer output.
- [ ] Add documentation truth checks for every command, feature name, env key,
  and package/extension claim.

### Phase 6 — Verification and release gate

- [ ] Run Tina4 client unit and integration tests locally.
- [ ] Run all four framework feature-status and Web Push contract suites.
- [ ] Run database and graph variants against real lab services where enabled.
- [ ] Run docs truth, link, build, and skill-validation gates.
- [ ] Verify a clean project with no enabled features still has the current
  zero-dependency startup path.
- [ ] Commit the implementation and documentation changes.
- [ ] Do not release until the owner approves the completed parity dashboard.

## Parity dashboard

| Capability | Python | PHP | Ruby | Node.js | tina4-js |
| --- | --- | --- | --- | --- | --- |
| `feature list` | planned | planned | planned | planned | n/a |
| `feature enable/status` | planned | planned | planned | planned | n/a |
| Web Push | optional crypto backend | OpenSSL extension | OpenSSL stdlib | built-in crypto | browser API |
| Database variants | planned | planned | planned | planned | n/a |
| Graph variants | planned | planned | planned | planned | n/a |
| Shared fixtures | planned | planned | planned | planned | client cases |
| Documentation | planned | planned | planned | planned | planned |
| AI skills | planned | planned | planned | planned | planned |

## Acceptance criteria

- A developer can enable any supported optional capability through the Tina4
  client without learning a language-specific install command.
- The same feature name, variant, env keys, status states, failure semantics,
  and fixture contract apply across all four backend frameworks.
- The framework core remains dependency-free unless the project explicitly
  enables an optional integration.
- Extensions are reported as runtime capabilities, not counted as packages.
- A configured but unavailable feature fails loudly and explains the repair.
- `feature enable` is idempotent, atomic, and produces a stable manifest diff.
- `feature status --json` can drive CI and AI tooling.
- Documentation, book chapters, quick references, and all relevant skills use
  the Tina4 client as the primary path.
- A clean scaffold with no selected features behaves exactly as it does today.
- All changes are committed locally before any release decision.

## Bugs and open decisions

- [ ] Confirm whether the manifest should be named `.tina4/features.json` or
  become a section in a future `tina4.toml`; the first implementation should
  not support two sources of truth.
- [ ] Confirm whether `feature enable` may install packages automatically in CI,
  or must require an explicit `--install` confirmation there.
- [ ] Define the exact provider status probe for each database and graph engine
  so `status` remains read-only and does not create schema or data.
- [ ] Define the shared JSON envelope before the command is documented.

## Commits

- (pending implementation)

## Status: Plan drafted — awaiting implementation approval
