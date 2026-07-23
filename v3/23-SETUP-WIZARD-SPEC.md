# 23 — `tina4 setup`: turnkey bootstrap (zero prerequisites)

**Status:** DRAFT for review (Andre to adjust before any Rust is written)
**Owner:** tina4 CLI (Rust) — `tina4stack/tina4`
**Goal:** A developer on a bare machine (no git, no language runtime, no package manager) runs **one command** and reaches the point where they can **start working** — a running full-stack app, Claude Desktop installed and MCP-wired (if chosen), **and a ready-to-paste starting prompt that turns their own idea into code in the next minute.** Installing + running is the *means*; the finish line is "start building now." The current manual path (install CLI → new terminal → install a runtime → `init` → `serve`, with PATH gotchas) is too many steps for a true newcomer.

---

## 1. The experience

Bare Windows box. PowerShell is always present:

```powershell
irm https://tina4.com/setup.ps1 | iex
```

(mac/Linux: `curl -fsSL https://tina4.com/setup.sh | sh`)

That bootstrap installs the `tina4` CLI **and then runs `tina4 setup`**, an interactive wizard. The wizard asks **two** things — which language path, and how you want to work — then installs the package manager + everything chosen:

```
  Tina4 Setup

  ✓ Chocolatey installed   (needs an elevated PowerShell — see §4)

  Which language path?   [1] Python + tina4-js  (full-stack — default)
                         [2] Python  [3] Node  [4] PHP  [5] Ruby
  > ⏎

  How do you want to work?   (space to toggle, enter to accept)
     [x] Git                       choco install git
     [x] Claude Desktop (AI)       choco install claude   + wire tina4 MCP
     [ ] VS Code                   choco install vscode
  > ⏎

  Project name?  [my-app] > ⏎

  ✓ Git                  choco install git -y
  ✓ Python 3.13          choco install python -y
  ✓ Node.js LTS          choco install nodejs-lts -y      (for the tina4-js frontend)
  ✓ uv                   (uv official installer)
  ✓ Claude Desktop       choco install claude -y
  ✓ Wired the tina4 MCP server into Claude Desktop

  ✓ Scaffolded my-app  (Python backend + frontend/ = tina4-js SPA)
  ✓ git init + first commit  →  Starting…

  → Browser opens the "What's next?" welcome page (http://localhost:7146/__welcome):
      • your starting prompt, with a Copy button
      • how to add a route / a model / run a migration
      • "Open Claude Desktop and paste →" + docs links
  ★ The prompt is also in START-HERE.md and on your clipboard.
```

**Non-goals:** not a system package manager; not responsible for upgrading the OS; does not touch global config beyond PATH (done by install.ps1 today) and an *additive merge* into Claude's MCP config.

---

## 2. Entry points

| OS | One-liner | Does |
|----|-----------|------|
| Windows | `irm https://tina4.com/setup.ps1 \| iex` | downloads `tina4-windows-amd64.exe` → `%LOCALAPPDATA%\tina4`, adds to PATH, then runs `tina4 setup` |
| macOS/Linux | `curl -fsSL https://tina4.com/setup.sh \| sh` | downloads the right binary, adds to PATH, runs `tina4 setup` |

`setup.ps1`/`setup.sh` = today's `install.ps1`/`install.sh` **+ a final `& "$dest" setup`**. (Keep the plain installers too, for people who only want the binary.)

---

## 3. The `tina4 setup` command

New clap subcommand alongside `Init`/`Install`/`Doctor`/`Serve`:

```
tina4 setup [--stack <python-js|python|node|php|ruby>]
            [--name <project>]
            [--claude | --no-claude]
            [--yes]            # non-interactive: take all defaults
            [--no-serve]       # scaffold + install but don't start
```

- Interactive by default; `--yes` makes it CI/script friendly (defaults: stack=`python-js`, name=`my-app`, claude=off under `--yes` unless `--claude`).
- Pure orchestration over existing pieces: `doctor` (detect) → prerequisite install (§4) → `init` (scaffold, §5) → optional Claude (§6) → `git init` → deps → `serve`.
- Idempotent: every prerequisite is **detect-first, install-only-if-missing**; re-running on a half-done box completes it.

---

## 4. Package-manager backbone + prerequisite install

The setup standardises on a per-OS package manager and **installs the manager itself if it's missing**, then drives every other install through it (uniform, idempotent, uninstallable later). Today `install.rs` only auto-installs **uv** and hand-waves the interpreters — this replaces that.

| OS | Manager | Bootstrap if missing |
|----|---------|----------------------|
| Windows | **Chocolatey** | elevated PowerShell: `Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))` |
| macOS | **Homebrew** | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| Linux | apt / dnf / pacman (already present) | use the system manager |

Then the chosen runtimes/tools — **verified package names**:

| Need | choco (Windows) | brew (macOS) |
|------|-----------------|--------------|
| Git | `git` | `git` |
| Python | `python` | `python@3.13` |
| Node (tina4-js) | `nodejs-lts` | `node` |
| uv | uv installer (existing) | uv installer |
| Claude Desktop | `claude` | `--cask claude` |
| VS Code (optional) | `vscode` | `--cask visual-studio-code` |

Rules:
- **Chocolatey needs admin.** The Windows path must run elevated — `tina4 setup` detects a non-elevated shell and **relaunches itself elevated via a UAC prompt** before any `choco install` (or clearly instructs the user to re-run in an admin shell). This is the one unavoidable Windows friction point; surface it first. (Homebrew on macOS does *not* need sudo and installs to the user prefix.)
- After each install, **refresh PATH in-process** (we already do this for uv via `refresh_uv_path_windows`) so later steps find the new binary without a new terminal — removes the #1 newcomer gotcha.
- **Detect-first:** every package is skipped if already present (reuse `doctor`'s checks). Re-runs are idempotent.

---

## 5. Combined `python + tina4-js` template (the default stack)

Today `init` scaffolds one language; the Python scaffold only *reserves* an empty `frontend/`. New combined template:

```
my-app/
  app.py                  # Python backend (tina4-python) — serves /api/* + built frontend
  .env                    # TINA4_DATABASE_URL=sqlite:///data/app.db, TINA4_DEBUG=true, ...
  src/
    routes/api/           # JSON API routes
    orm/  templates/  public/   scss/
  migrations/
  frontend/               # tina4-js SPA (Vite)
    package.json          # tina4js + vite
    vite.config.ts        # dev: proxy /api → http://localhost:7146 ; build → ../src/public/app
    src/                  # signals/components
  data/
```

**Dev wiring (the decision to confirm):**
- **Option A (recommended): Vite proxy.** `tina4 serve` starts Python on `7146` (hot-reload) and Vite on its own port; Vite proxies `/api` → `7146`. You develop against the Vite URL with HMR for the frontend and Python hot-reload for the backend.
- **Option B: Python serves the build.** `frontend` builds into `src/public/app`; Python serves it. Simpler (one port) but no frontend HMR.
- This interacts with the dual-port AI mode (base hot-reloads, base+1000 stable) we shipped in 3.13.34 — the Python side keeps that; the Vite side has its own HMR.

**Welcome / "What's next?" page (`/__welcome`):** the scaffold ships a first-run route the browser opens after setup. It renders the **starting prompt with a Copy button**, copy-paste snippets for *add a route / add a model / run a migration*, an **"Open Claude Desktop and paste →"** callout, and docs links. It's a normal tina4 route served by the Python backend (works offline) — and doubles as a tiny worked example of the conventions a newcomer is about to use.

---

## 6. Claude Desktop + MCP (the standout — and the riskiest)

### Install (chosen in the "how do you want to work?" step)
- **Windows:** `choco install claude` (verified: the `claude` community package = Claude Desktop).
- **macOS:** `brew install --cask claude` (verified cask; note `claude-code` is the separate CLI cask, *not* this).

### Wire the tina4 MCP server into Claude Desktop
Claude Desktop reads **`%APPDATA%\Claude\claude_desktop_config.json`** (mac: `~/Library/Application Support/Claude/claude_desktop_config.json`), schema:

```json
{ "mcpServers": { "tina4-my-app": { "command": "tina4", "args": ["mcp", "--project", "C:\\Users\\me\\my-app"] } } }
```

So the setup must:
1. **Add a `tina4 mcp` stdio bridge command** to the CLI. The framework's built-in MCP (Python `tina4_python.mcp`, 24 dev tools) currently speaks **SSE in dev**; Claude Desktop speaks **stdio**. `tina4 mcp --project <path>` is a thin stdio↔framework bridge (spawn the project's MCP and pipe stdio, or re-expose the tools over stdio). **This is the one genuinely new capability and the main design risk.**
2. **Merge, don't clobber** `claude_desktop_config.json` (preserve the user's existing `mcpServers`); create the file + dirs if absent; use double-backslash Windows paths.
3. **Handle the MSIX gotcha:** an MSIX-installed Claude Desktop actually reads from a virtualized path (`…\Packages\Claude_*\LocalCache\Roaming\Claude\claude_desktop_config.json`), not the one the "Edit Config" button shows. Setup must detect the install type and write the path Claude truly reads (or write both). **Verify on a real Windows install.**
4. Tell the user to **restart Claude Desktop** for it to pick up the server.

---

## 7. The starting prompt — the actual finish line

Running the app is the *means*; the **goal is a developer who can start building in the next minute**. So the last thing `tina4 setup` does is hand them a ready-to-use **starting prompt** for their AI.

**What it is:** a short, project-aware opening message the developer pastes into Claude Desktop (or any assistant). It names the stack, points at the conventions (`CLAUDE.md`, installed by `tina4 ai`), notes the **tina4 MCP server is connected** (so the AI can introspect routes/models and run queries), and invites them to describe what they're building.

**Optional personalisation:** the wizard can ask *"What are you building? (one line)"* and inject the answer, so the prompt is already about *their* idea.

**Template** (written to `START-HERE.md` + copied to clipboard + printed):
> I just scaffolded a new **Tina4 full-stack app** — Python API backend + tina4-js frontend.
> Conventions live in `CLAUDE.md`, and the **tina4 MCP server is connected**, so you can inspect routes/models and run queries directly.
>
> I want to build: **{their one-liner — or "‹describe your app in a sentence›"}**
>
> Propose the data models and the first API routes + a frontend page, then scaffold them following tina4 conventions — migrations for schema, the ORM for models, tina4-js signals/components for the UI. Run the dev server on the hot-reload port (7146) and show me it working.

**Delivery (all three, so it can't be missed):**
1. Write `START-HERE.md` at the project root.
2. Copy the prompt to the clipboard (`clip` on Windows, `pbcopy` on macOS, `wl-copy`/`xclip` on Linux).
3. Print it in the terminal: *"Paste this into Claude Desktop to start →"*.

Because Claude Desktop is already installed + MCP-wired (§6) and the `CLAUDE.md` context is in place, pasting this prompt is a genuine zero-to-building moment — which is the whole point of `tina4 setup`.

## 8. Idempotency, failure, re-run
- Detect-first everywhere; safe to re-run.
- A failed prerequisite is **non-fatal where possible** (print the manual command, continue), fatal only if the chosen stack can't proceed.
- `tina4 doctor` after setup should show everything green.

---

## 9. Open decisions for Andre
1. **Frontend wiring:** Vite-proxy (A) vs Python-serves-build (B) for the default `python-js` template? (Rec: A.)
2. **Claude Desktop scope:** just install + MCP-wire, or also drop project context (`CLAUDE.md` via existing `tina4 ai`) at the same time? (Rec: yes, run `ai` too.)
3. **`tina4 mcp` bridge:** stdio re-expose of the framework MCP — acceptable to build, or do you want a different transport?
4. **Domain:** host `setup.ps1`/`setup.sh` at `tina4.com`, or keep the GitHub `raw.githubusercontent.com` URL?
5. **Non-Windows priority:** build mac/Linux paths in the same pass or Windows-first?
6. **Windows admin elevation:** Chocolatey needs admin — should `tina4 setup` auto-relaunch itself elevated (UAC prompt), or detect + instruct the user to re-run in an admin shell? (Rec: auto-relaunch with a clear prompt.)
7. **"How do you want to work?" tool list:** confirm the toggle set — Git (default on), Claude Desktop + MCP, VS Code. Add anything else (e.g. Windows Terminal, a DB GUI)?
8. **Starting prompt:** ask *"what are you building?"* and personalise it, or ship the generic template? (Rec: ask, with a skippable default.) And deliver via clipboard + `START-HERE.md` + print — all three?

---

## 10. Build phases (once the spec is agreed)
- **P1 — core:** `tina4 setup` command (the two prompts) + **choco/brew/apt** backbone — installs the package manager itself if missing (choco needs admin → self-elevate) — then git/python/node/uv + in-process PATH refresh. Bare box → tools ready.
- **P2 — template + prompt:** combined `python + tina4-js` scaffold + `tina4 serve` runs both (per §5) + **generate the `START-HERE.md` starting prompt** (clipboard + print). This phase alone delivers "zero → running → prompt in hand."
- **P3 — Claude:** `tina4 mcp` stdio bridge + Claude Desktop install + config merge (with MSIX handling) + `tina4 ai` context. Now the prompt is paste-and-go.
- **P4 — entry + polish:** `setup.ps1`/`setup.sh` auto-run setup; `--yes` non-interactive; `tina4 doctor` parity.

> Implementation note: all of this is Rust I can write and `cargo build` on macOS, but the winget / Claude-Desktop / Windows-PATH paths only **execute** on Windows — Andre runs the real verification there.

**Sources for the external facts:** Claude Desktop winget id [winstall Anthropic.Claude](https://winstall.app/apps/Anthropic.Claude); MCP config location/schema + MSIX gotcha [anthropics/claude-code#26073](https://github.com/anthropics/claude-code/issues/26073), [MCP quickstart](https://modelcontextprotocol.info/docs/quickstart/user/).
