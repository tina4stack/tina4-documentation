---
description: >-
  An introduction to the Tina4 mindset and code bases across the various
  language sets, using MkDocs for documentation.
---

# Tina4 Documentation Setup

This guide will help you set up a local environment to serve or build Tina4 documentation using **MkDocs** and **UV**, with steps tested on **Windows**, and guidance for macOS/Linux.

---

##  Prerequisites

You’ll need:

- **Python 3.8+** installed
- **[Chocolatey](https://chocolatey.org/)** (for Windows users)
- **PowerShell (as Admin)** on Windows

---

##  1. Install Chocolatey (Windows only)

Open PowerShell **as Administrator** and run the following to install Chocolatey:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; `
[System.Net.ServicePointManager]::SecurityProtocol = `
[System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```
# 2. Install UV
On Windows:
```powershell
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

# 3. Create & Set Up Project Folder
Choose or create your documentation project folder:

```powershell
mkdir C:\Users\YourName\PycharmProjects\mkdocs-test
cd C:\Users\YourName\PycharmProjects\mkdocs-test
```
Replace YourName with your Windows username.

# 4. Create Virtual Environment Using UV
From inside your project folder:

```powershell
uv venv
```
This creates a .venv folder and sets up your Python virtual environment.

## Enable Script Execution (One-Time Setup)
Still inside PowerShell:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass                       
```
Select Y if prompted.

# 5. Activate the Virtual Environment

```powershell
.venv\Scripts\Activate.ps1
```
# 6. Install MkDocs & Theme Dependencies

```powershell
uv pip install mkdocs mkdocs-material
```
# 7. Initialize MkDocs Project
Run:

```powershell
mkdocs new 
```
This will create a basic project structure with a mkdocs.yml file and a docs/ folder containing index.md.

# 8. Serve Documentation Locally
To preview your docs in the browser:
```powershell
mkdocs serve
```
Then open: http://127.0.0.1:8000

# 9. Build Static Site
To generate the HTML files for deployment:

```powershell 
mkdocs build
```
Output will be in the site/ folder.

# 10. Troubleshooting
#### If uv or mkdocs commands aren't recognized:

- Make sure your virtual environment is activated.

-  Run: .venv\Scripts\Activate.ps1 again.

#### If PowerShell blocks script execution:

- Run: Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 11. Test Installation Checklist
- Chocolatey installed
- UV installed (uv --version)
- Virtual environment created and activated
- MkDocs + theme installed
- mkdocs serve runs and shows docs in the browser

