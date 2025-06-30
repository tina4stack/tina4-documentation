---
description: >-
  An introduction to the Tina4 mindset and code bases across the various
  language sets, using MkDocs for documentation.
---

# Tina4 Documentation Setup

This guide will help you set up a local environment to serve or build Tina4 documentation using **MkDocs** and **UV**, with steps tested on **Windows**, and guidance for macOS/Linux.

---

##  1. Install Chocolatey (Windows Only)

Open **PowerShell as Administrator**, then paste and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; `
[System.Net.ServicePointManager]::SecurityProtocol = `
[System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```
# 2. Install UV
On Windows:
```bash
choco install uv -y
```
# On macOS/Linux:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```
# After installation, confirm UV is working:
```bash
uv --version
```

UV will automatically install Python 3.12+ when syncing the project environment.
You do not need to install Python manually.

# 3. Sync Environment
From the root of the repo (where uv.lock is located), run:

```bash
uv sync
```
This installs MkDocs and all required plugins/themes.


# 4. Preview Docs Locally
Start the local development server:

```bash
uv run mkdocs serve

```
Then open: http://127.0.0.1:8000

# 5. (Optional) Build Static Site
This step is optional. It's handled by CI/CD, but you can build locally to preview the final HTML:

```bash
uv run mkdocs build
```
This will generate a static site in the `/site` directory.


