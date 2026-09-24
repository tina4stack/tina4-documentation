# Contributing to Tina4

Tina4 is one framework in four languages - Python, PHP, Ruby and Node.js - plus the tina4-js frontend and the `tina4` command-line tool. A change you make in one of them is usually expected in all four. This page follows a contribution from the pull request you open to the release it lands in.

The rules below are the ones the project holds itself to. They come from the Tina4 decision log (ADR-0073). They line up with ISO/IEC 18974 for security and ISO/IEC 5230 for licences. Tina4 is working towards both, and it doesn't claim either yet.

## Where changes go

| Repository | Release branch |
|---|---|
| `tina4stack/tina4-python`, `tina4-php`, `tina4-ruby`, `tina4-nodejs` | `v3` |
| `tina4stack/tina4` (command-line tool) | `main` |
| `tina4stack/tina4-js` | `master` |
| `tina4stack/tina4-documentation` | `main` |

- **Fork the repository** and work on a branch in your fork. Direct access to these repositories is limited to the project owner and the maintainer, so every outside change arrives as a pull request.
- **Open the pull request against the release branch.** The release branch won't accept a direct push from anyone, and it won't accept a pull request until the required checks pass.
- **Release tags can't be moved or deleted.** A tag, once published, is what the package registries built from.

## What a pull request must carry

When you open a pull request, the checks will run your change through the full test suite. A reviewer will then look for the points below. A pull request missing any of them goes back to you.

- **Real tests, written first.** A test that touches a database, a queue, a cache, a socket or a mail server must talk to the real thing. Mocks, stubs and fakes that stand in for a dependency aren't accepted. Include a positive case and a negative case.
- **A regression test for every bug fix.** Show it failing on the old code and passing on yours. The test stays in the suite for good.
- **Parity.** If the behaviour exists in all four frameworks, change all four, or say in the pull request why the change belongs to one language only. The Python framework is the reference implementation.
- **No new runtime dependencies.** The frameworks ship with no third-party runtime dependencies. Database drivers and optional servers are the application's choice, never the framework's (ADR-0067). A new development dependency needs a written reason.
- **An ADR for a contract change.** If your change alters something developers can see - a response shape, an error message, a status code, an environment variable - it needs a decision record in `plan/v3/decisions/`, or it must cite the one that governs it.
- **Green checks.** The required checks can't be skipped, not even by the maintainer.

## Licensing your contribution

- **Current releases** are published under the licence in each repository's `LICENSE` file.
- **From the next release,** Tina4 moves to the Mozilla Public License 2.0 (MPL-2.0), with a commercial licence from Code Infinity for companies that don't want the MPL terms (ADR-0075). Anybody who changes Tina4's own files and distributes the result must share those changes under MPL-2.0; applications built with Tina4 can stay closed.
- **Contributor Licence Agreement (CLA).** Before your first pull request can merge, you'll be asked to agree to the [Tina4 Contributor Licence Agreement](contributor-licence-agreement.md). It confirms you have the right to contribute the code, and it lets Code Infinity offer your contribution under both licences.
- **Sign-off on every commit.** Add a `Signed-off-by:` line (`git commit -s`) to each commit. It records, commit by commit, that you wrote the change or have the right to submit it. A check on each pull request will look for it.
- **Third-party code.** Don't copy code from elsewhere unless its licence allows it under the terms above, and keep the original copyright and licence notice with it. If you're not sure, ask in the pull request before you copy.

## Security-sensitive changes

- **Don't disclose a vulnerability in public.** If you find a security flaw, report it privately - see the [security research policy](security-research.md) - rather than opening an issue or a pull request that describes it.
- **Fixes stay quiet until they ship.** A pull request that fixes an undisclosed vulnerability describes the change plainly and carries no exploit, payload or proof of concept. The advisory tells the full story once the fix is released.
- **Secrets are blocked at the door.** Secret scanning with push protection is on, so a push that contains a credential will be refused. If a secret does reach a repository, tell the maintainer so it can be revoked.

## AI-assisted contributions

Code written with an AI assistant follows every rule on this page, and the same reviewer will read it. Keep the assistant's co-author trailer on the commit, and make sure you've run the tests yourself rather than trusting the assistant's report of them.

## Review and merge

- **Who merges:** the maintainer reviews and merges pull requests. The project owner account is kept for administration.
- **What the checks cover:** the full test suite, the Docker boot check, the Firebird suite, and code scanning (CodeQL, and Semgrep for PHP source).
- **Releases:** merging never publishes anything. A release happens only when the maintainer tags it.

## Why these rules exist

Developers who build on Tina4 inside a regulated business have to show that their tools are made with care. Every rule above leaves proof an assessor can check: a pull request, a green run, a signed commit, an advisory. So choosing Tina4 closes questions for them, it doesn't open new ones.

If you'd like to talk a change through before you write it, open a discussion on the repository and the maintainer will pick it up...
