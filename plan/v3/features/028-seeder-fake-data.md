# Feature 028: Seeder and fake data

## Identity and status

- Matrix identity: 28 - Seeder and fake data
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (Python `seeder/__init__.py`, Node
  `fakeData.ts`, PHP `FakeData.php`/`SeedSummary.php`, Ruby `seeder.rb`). No framework code
  changed.
- Dependencies: Feature 17 ORM base class (a seed writes model rows), the language stdlib PRNG
  (no faker dependency - zero-dependency by design)
- Dependants: test fixtures, demo data, and Feature 113 (the `tina4 seed` CLI command that
  wraps this module)
- Existing ADRs: the zero-dependency principle (own PRNG, no faker library)
- Shared fixtures: `fake_data_contract.json` is required

## Why this feature exists

A developer fills a database with realistic test rows - names, emails, phone numbers, numbers,
booleans - without hand-typing them and without pulling in a faker dependency, and can make
that output DETERMINISTIC with a seed so a test is reproducible.

## Boundary

This feature owns the `FakeData` generator: the seeded PRNG, the field-generator vocabulary
(`name`, `email`, `integer`, and the rest), and the programmatic seeding entry points
(`run(fn, count)`, `seed_dir(folder)`). It DELEGATES the actual row insert to the ORM (Feature
17) and the `tina4 seed` CLI command to Feature 113. It owns NO third-party dependency: the
PRNG and the generators are hand-rolled.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Class | `FakeData` (`seeder/__init__.py`) | `FakeData` (`FakeData.php`) | seeder (`seeder.rb`) | `FakeData` (`fakeData.ts`) |
| Optional seed | `FakeData(seed=None)` -> `random.Random(seed)` | yes | yes | `FakeData(seed?)` -> `mulberry32(seed)` |
| PRNG | stdlib Mersenne Twister | stdlib | stdlib | hand-rolled `mulberry32` |
| Deterministic with a seed | yes (per-language) | yes | yes | yes |
| Field generators (measured, Python) | `name`, `first_name`, `last_name`, `email`, `phone`, `integer(min,max)`, `decimal(min,max,decimals)`, `boolean` | present | present | present |
| Generate N | `run(fn, count=1) -> list` | present | present | present |
| Seed from a directory | `seed_dir("seeds")` | `SeedSummary` | present | present |
| Third-party faker dependency | NONE | NONE | NONE | NONE (zero-dep, own PRNG) |

All four ship a `FakeData` generator with an optional seed that makes output deterministic, a
vocabulary of field generators, and a run/seed-directory mechanism -- all hand-rolled with no
faker dependency, matching the zero-dependency principle. Determinism holds WITHIN a language:
Python uses the stdlib Mersenne Twister and Node uses a hand-rolled `mulberry32`, which are
different algorithms, so the same seed produces a reproducible sequence in each language but
NOT the same sequence across languages.

## Public surface contract

`FakeData(seed=None)` constructs a generator; a given seed makes its output reproducible. The
field generators return realistic values: `name`, `first_name`, `last_name`, `email`, `phone`,
`integer(min, max)`, `decimal(min, max, decimals)`, `boolean` (idiomatic spelling per
language). `run(fn, count=1)` calls a generator function `count` times and returns the list.
`seed_dir(folder="seeds")` executes the seed files in a directory. Method names follow each
language's convention; the generator vocabulary is the same set in all four.

## Inputs and outputs

- Input: an optional integer seed; per-generator bounds (`integer(min, max)`,
  `decimal(min, max, decimals)`).
- Output: realistic fake values of the right native type -- a string name/email/phone, a
  native integer, a native float, a native boolean.
- `run(fn, count)` returns a list of `count` generated items.
- With the same seed, a language reproduces the same sequence; without a seed, output varies.
- Cross-language determinism is NOT guaranteed (different PRNGs) and is not required.

## Lifecycle and operation graph

1. `FakeData(seed)` initializes the PRNG (seeded or not).
2. A field generator draws from the PRNG and returns a value of the correct type.
3. `run(fn, count)` invokes the caller's generator function `count` times, collecting a list
   (typically model instances to insert via the ORM).
4. `seed_dir(folder)` discovers and runs the seed files in the folder, returning a summary of
   what was seeded.

## Configuration and precedence

- A seed makes output deterministic; no seed makes it random. An explicit seed is the only
  control.
- The seed directory defaults to `seeds`; an explicit folder overrides it.
- There is no environment variable and no third-party dependency.

## Failures, side effects and security

- FakeData generates VALUES; it has no side effect until the caller inserts the results, so
  generation itself cannot corrupt data.
- `seed_dir` runs developer-written seed files; they are trusted code, and a failing seed file
  reports in the summary rather than silently skipping.
- The generators are for TEST/DEMO data, not security tokens: the PRNG is not cryptographic and
  must never be used to generate a password, key or token (documented, so no one mistakes a
  reproducible fake for a secret).
- A seeded run is reproducible, which is a feature for tests, not a leak.

## Wire and persistence contract

There is no wire format; the outputs are native language values. When `seed_dir` reports, the
summary shape (what was seeded, counts) is the contract and is the same across the four. A seed
inserts through the ORM, so the persisted shape is the model's own.

## Providers and substitutability

Generation is engine-agnostic; only the eventual insert touches a provider, through the ORM. A
future runtime hand-rolls its own PRNG and the same generator vocabulary, deterministic within
itself, with no faker dependency.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| SEED-01 | Determinism is per-language (Python Mersenne Twister vs Node `mulberry32`); the same seed does NOT reproduce across languages. | Decide and DOCUMENT that determinism is per-language, not cross-language (the expected and acceptable contract for fake data); state it so no one relies on cross-language reproducibility. |
| SEED-02 | The field-generator vocabulary is measured fully only in Python; parity of the generator SET across the four is not gated. | Pin one generator vocabulary (`name`, `first_name`, `last_name`, `email`, `phone`, `integer`, `decimal`, `boolean`, and any agreed additions) present in all four. |
| SEED-03 | `run`/`seed_dir` and the seed-summary shape are not proven identical. | Gate `run(fn, count)` returning `count` items and `seed_dir` reporting the same summary shape in all four. |
| SEED-04 | The PRNG must never be used for secrets, but nothing states it. | Document the not-for-secrets boundary on the class in all four. |
| SEED-05 | No shared fixture exists. | Add `fake_data_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. `FakeData(seed)` is deterministic PER-LANGUAGE, not cross-language; this is stated in the
   docs (fake data does not need a shared PRNG, and hand-rolling a shared one would add cost for
   no benefit).
2. One generator vocabulary present in all four, with idiomatic method spelling per language.
3. `run(fn, count)` returns a `count`-length list; `seed_dir(folder="seeds")` runs seed files
   and returns a uniform summary shape.
4. Zero third-party dependency: the PRNG and generators are hand-rolled (the zero-dependency
   principle).
5. The PRNG is explicitly NOT for secrets; documented on the class.

## Proposed conformance fixture

Add `fake_data_contract.json` with stable ids for: a seeded `FakeData` reproducing its own
sequence (same seed, same output, within a language); each field generator returning the right
native type and honoring bounds (`integer(1, 10)` stays in range); `run(fn, 5)` returning five
items; `seed_dir` running a folder and reporting a uniform summary; and the generator
vocabulary being present in all four. Every case runs real generation (and real inserts where a
seed writes rows); no mock is needed because the generator IS the unit under test.

## Integration map

- The ORM (Feature 17) inserts seeded rows; Feature 113 (`tina4 seed`) is the CLI that invokes
  this module; the dev-admin UI may trigger seeding.
- Central fixtures, four runners, the CI matrix, release notes and the seeder docs update
  together.

## Breaking changes and migration

- None expected to the public surface; the audit pins the generator vocabulary and documents
  the per-language determinism and the not-for-secrets boundary. Any generator missing from one
  language is added (additive).

## Implementation backlog

1. Add `fake_data_contract.json` and wire four runners.
2. Pin and gate the generator vocabulary across the four (SEED-02).
3. Gate `run`/`seed_dir` and the summary shape (SEED-03).
4. Document per-language determinism (SEED-01) and the not-for-secrets boundary (SEED-04).
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement a `FakeData` class with an optional seed that initializes a hand-rolled or stdlib
PRNG (no faker dependency). Provide the generator vocabulary (`name`, `first_name`,
`last_name`, `email`, `phone`, `integer(min, max)`, `decimal(min, max, decimals)`, `boolean`)
returning native-typed values, `run(fn, count)` returning a list, and `seed_dir(folder="seeds")`
running seed files with a uniform summary. Make output deterministic within the language for a
given seed; do not attempt cross-language determinism. Document that the PRNG is not for
secrets. Prove the port with a seeded-reproducibility case and a bounds case.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (SEED-01..05).
- [x] Owner ambiguities recorded (5 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
