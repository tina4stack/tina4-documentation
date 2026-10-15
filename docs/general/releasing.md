# Releasing Tina4

Merging never ships anything. A release happens only when the maintainer tags
it, and the tag is what the package registries build from - so a tag, once
pushed, can't be moved or deleted. This page traces a release from the version
bump to the tag that publishes it.

Tina4 releases on four tracks, each with its own version line:

| Track | Repositories | Version | Branch |
|---|---|---|---|
| Frameworks (parity) | `tina4-python`, `tina4-php`, `tina4-ruby`, `tina4-nodejs` | `3.13.x` - one number, the same everywhere | `v3` |
| Command-line tool | `tina4` | `3.8.x` | `main` |
| Frontend | `tina4-js` | `1.7.x` | `master` |
| AI skills | served from `tina4-documentation` + `tina4` | tracks the framework `3.13.x` | `main` |

The four frameworks move together: one change, all four, one shared version
number. The tool and the frontend version on their own. The skills pin follows
the framework number so `curl ... | sh` always pulls the skills from a tested tag.

## The order that holds

1. Land the work on the release branch through pull requests (see [Contributing](contributing.md)). Merging publishes nothing.
2. Bump every version-bearing file and let the per-repo guard check it.
3. Open the release pull request, get the checks green, merge.
4. Sign what must be signed.
5. Tag. The tag publishes.

Signing comes last because bumping a signed installer breaks its signature;
tagging comes after signing because the tag must point at the signed commit.

## Framework release (3.13.x)

Bump every version-bearing file, then run the repo's consistency guard - it
refuses the release if any gated file still carries the old number.

| Repository | Files the guard checks | Guard |
|---|---|---|
| `tina4-python` | `pyproject.toml`, the `tina4_python/__init__.py` floor, `CLAUDE.md`, `AGENTS.md` (plus `uv.lock` self-entry, `CHANGELOG.md`) | `scripts/check_version_consistency.py` |
| `tina4-php` | `Tina4/App.php` `$VERSION`, `CLAUDE.md`, `AGENTS.md` (plus `CHANGELOG.md`; no `composer.json` version - Packagist reads the tag) | `scripts/check-version-consistency.php` |
| `tina4-ruby` | `lib/tina4/version.rb`, `CLAUDE.md`, `AGENTS.md`, both `Gemfile.lock` `tina4ruby` pins, the `scripts/dependency-licenses.json` self-entry (plus `CHANGELOG.md`) | `scripts/check_version_consistency.rb` |
| `tina4-nodejs` | root and every `packages/*/package.json`, the `package-lock.json` self-entries, `CLAUDE.md`, `AGENTS.md` (plus `CHANGELOG.md`) | `npm run release:precheck` |

```bash
# from each framework repo, on a release branch off v3
<lang> <guard-script> 3.13.NNN     # fails on any unbumped gated file
```

Run order: bump, guard, CHANGELOG entry, pull request to `v3`, green, merge, then
tag `3.13.NNN` on all four.

## Command-line tool (3.8.x)

Bump `Cargo.toml`, the `Cargo.lock` self-entry and the `CLAUDE.md` header; add the
CHANGELOG entry. Leave the Scoop, Homebrew, Chocolatey and winget manifests alone
- `release-published.yml` renders them from the tag and `SHA256SUMS` after the tag
lands. Tag `v3.8.NNN`; the release workflow builds, signs the Windows binary and
publishes to every channel.

## Frontend (1.7.x)

Bump `package.json` and the `CLAUDE.md` header and footer; add the CHANGELOG entry;
tag `v1.7.NNN`.

## Skills release (tracks 3.13.x)

The skills ship as a bundle served from `tina4.com/skills/<ref>/`, with jsDelivr
and raw GitHub as fallbacks. The installer stages each file, then verifies it
against `skills.sha256` - so a dropped or truncated file fails loud rather than
installing half a skill. Bump the skills only when a skill's content changed; the
pin tracks the framework number.

From the `tina4` repo, with the framework repos checked out at the release content:

```bash
scripts/gen-skills-sha256.sh <idearoot> > skills.sha256   # 1. refresh the manifest
scripts/bump-skills-ref.sh 3.13.NNN                        # 2. bump the pin (after the tag is live)
scripts/sign-installers-mac.sh                             # 3. re-sign install-skills.ps1 (EV)
scripts/gen-skills-bundle.sh 3.13.NNN                      # 4. stage docs/public/skills/3.13.NNN/
```

Then set `docs/public/skills/latest/version` to the new ref, commit
`docs/public/install-skills.{sh,ps1}` and `docs/public/skills/3.13.NNN/` in
`tina4-documentation`, and push `main` - the deploy publishes it. `skills-list.sh`
is the one list of which files make up a release, shared by the manifest and the
bundle so the two can never disagree.

## Signing

Two files carry an Extended Validation (EV) Authenticode signature:
`install-skills.ps1` and the Windows CLI binary. The signature comes from the Code
Infinity EV certificate on the Certum SimplySign cloud card, which must be open and
logged in - EV signing is interactive, so it runs locally, never in continuous
integration.

- macOS: `scripts/sign-installers-mac.sh` (osslsigncode against the card).
- Windows: `scripts/sign-installers.ps1` (signtool).

Any edit to `install-skills.ps1`, bumping its pin included, breaks the signature,
so re-sign it in the same change or the Windows install fails its own check.

## The gates

Every pull request runs these, and they run locally too.

- **Doc truth** - every `tina4` command and `TINA4_*` env var the docs name exists in code, and every user-facing env var in code is documented (`scripts/audit-truth.py`, `scripts/audit-env-coverage.py`).
- **Version consistency** - the per-repo guard above.
- **Metrics ratchet** - `tina4 metrics --fail-on-regression` refuses a change that makes the code measurably worse.
- **Sign-off** - every commit carries a `Signed-off-by` line (Developer Certificate of Origin, DCO).
- **Licence policy** - every dependency matches a reviewed declaration.
- **No committed symlinks** - a guard in all four frameworks.
