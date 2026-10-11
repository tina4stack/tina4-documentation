# Tina4 local AI server - one command on Windows: install the deps, download the
# model, serve it. Tina4 is the server (no FastAPI, no Flask); the model engine is
# vendored under lib\ (nothing is cloned).
#
#   .\setup.ps1
#
# GPU vs CPU is automatic: an NVIDIA GPU (nvidia-smi present) gets the CUDA build of
# torch, otherwise the CPU build. Override before running:
#   $env:AI_SERVER_PORT = "7788"
#   $env:HARNESS_CUDA  = "cu126"   # pin a CUDA build to your driver
#   $env:HARNESS_CUDA  = "cpu"     # force CPU even with a GPU present
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$venv = ".venv"
$port = if ($env:AI_SERVER_PORT) { $env:AI_SERVER_PORT } else { "11437" }

# 0) The tina4 Rust CLI runs Tina4 apps - it must be on PATH.
if (-not (Get-Command tina4 -ErrorAction SilentlyContinue)) {
    Write-Host "tina4 CLI not found. Install it: https://tina4.com/cli"; exit 1
}

# The model engine is vendored under lib\ - the server clones nothing.

# 2) A virtual environment and the dependencies.
$useUv = [bool](Get-Command uv -ErrorAction SilentlyContinue)
$py = Join-Path $venv "Scripts\python.exe"
if (-not (Test-Path $py)) {
    if ($useUv) {
        Write-Host "> creating $venv with uv (Python 3.12) ..."
        uv venv --python 3.12 $venv | Out-Null
    } else {
        Write-Host "> creating $venv with py -3.12 venv ..."
        py -3.12 -m venv $venv
        & $py -m pip install --upgrade pip | Out-Null
    }
}

$cuda = $env:HARNESS_CUDA
if (-not $cuda) { if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) { $cuda = "cu128" } else { $cuda = "cpu" } }
if ($cuda -ne "cpu") {
    Write-Host "> NVIDIA GPU detected -> installing the CUDA ($cuda) build of torch + torchvision."
    $index = "https://download.pytorch.org/whl/$cuda"
    if ($useUv) { uv pip install -p $py --index-url $index torch torchvision } else { & $py -m pip install --index-url $index torch torchvision }
}

Write-Host "> installing requirements ..."
if ($useUv) { uv pip install -p $py -r requirements.txt } else { & $py -m pip install -r requirements.txt }

$env:PYTHONPATH = (Join-Path $PSScriptRoot "lib") + $(if ($env:PYTHONPATH) { ";$env:PYTHONPATH" } else { "" })

# 3) Download the model once (prefers a local 4-bit folder, else fetches it).
Write-Host "> downloading the model (first run only) ..."
@'
from ai_engine.download import MODELS_DIR, _has_weights, ensure_model
from ai_engine.model import MLX_LOCAL_DIR, MLX_REPO, TORCH_REPO, pick_backend

if pick_backend() == "mlx":
    local = MODELS_DIR / MLX_LOCAL_DIR
    if _has_weights(local):
        print(f"Model already present: {local}")
    else:
        ensure_model(MLX_REPO)
else:
    ensure_model(TORCH_REPO)
'@ | & $py -

# 4) Serve it with Tina4.
# A signing secret is needed to boot (even with noauth routes). Make one once, keep
# it in .env.local (gitignored), and reuse it every run after.
$secretLine = if (Test-Path .env.local) { Select-String -Path .env.local -Pattern '^TINA4_SECRET=' | Select-Object -First 1 } else { $null }
if ($secretLine) {
    $env:TINA4_SECRET = ($secretLine.Line -split '=', 2)[1]
} else {
    $bytes = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $env:TINA4_SECRET = -join ($bytes | ForEach-Object { $_.ToString('x2') })
    Add-Content -Path .env.local -Value "TINA4_SECRET=$($env:TINA4_SECRET)"
    Write-Host "> generated a per-machine signing secret into .env.local"
}

Write-Host "> starting the Tina4 AI server on http://127.0.0.1:$port ..."
# .env pins Tina4's own asyncio server on and keeps debug off: Tina4 serves this,
# no uvicorn, no dashboard.
tina4 serve --port $port --host 127.0.0.1 --no-browser --no-reload
