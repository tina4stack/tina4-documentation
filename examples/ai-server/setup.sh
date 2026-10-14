#!/usr/bin/env bash
# Tina4 local AI server - one command: install the deps, download the model, serve it.
#
#   ./setup.sh
#
# Tina4 is the server (no FastAPI, no Flask). The model engine is vendored under
# lib/ (nothing is cloned), and the engine picks itself for the machine:
#   * Apple Silicon          -> MLX (Metal GPU), tiny 4-bit weights.
#   * Linux/Windows + NVIDIA -> the CUDA build of torch (float16 on the GPU).
#   * everything else        -> CPU torch (works everywhere, slower).
#
# Override before running:
#   AI_SERVER_PORT=7788 ./setup.sh
#   HARNESS_CUDA=cu126 ./setup.sh          # pin a CUDA build to your driver
#   HARNESS_CUDA=cpu   ./setup.sh          # force CPU even with a GPU present
set -euo pipefail
cd "$(dirname "$0")"

VENV=".venv"
PORT="${AI_SERVER_PORT:-11437}"

# 0) The tina4 Rust CLI runs Tina4 apps - it must be on PATH.
command -v tina4 >/dev/null 2>&1 || { echo "tina4 CLI not found. Install it: https://tina4.com/cli"; exit 1; }

# The model engine is vendored under lib/ - the server clones nothing.

# 2) A virtual environment and the dependencies.
if command -v uv >/dev/null 2>&1; then
  if [ ! -d "$VENV" ]; then
    echo "> creating $VENV with uv (Python 3.12) ..."
    uv venv --python 3.12 "$VENV" >/dev/null
  fi
  PY="$VENV/bin/python"
  PIP_INSTALL=(uv pip install -p "$PY")
else
  if [ ! -x "$VENV/bin/python" ]; then
    echo "> creating $VENV with python venv ..."
    python3 -m venv "$VENV"
    "$VENV/bin/python" -m pip install --upgrade pip >/dev/null
  fi
  PY="$VENV/bin/python"
  PIP_INSTALL=("$PY" -m pip install)
fi

CUDA="${HARNESS_CUDA:-}"
if [ -z "$CUDA" ]; then
  if command -v nvidia-smi >/dev/null 2>&1; then CUDA="cu128"; else CUDA="cpu"; fi
fi
if [ "$CUDA" != "cpu" ]; then
  echo "> NVIDIA GPU detected -> installing the CUDA ($CUDA) build of torch + torchvision."
  "${PIP_INSTALL[@]}" --index-url "https://download.pytorch.org/whl/$CUDA" torch torchvision
fi

echo "> installing requirements ..."
"${PIP_INSTALL[@]}" -r requirements.txt

export PYTHONPATH="$PWD/lib${PYTHONPATH:+:$PYTHONPATH}"

# 3) Download the model once. It prefers a local 4-bit folder and only falls back to
#    the Hugging Face weights when that folder is absent, so it never pulls the wrong
#    copy over one already on disk. Run again and it is instant.
echo "> downloading the model (first run only) ..."
"$PY" - <<'PY'
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
PY

# 4) Serve it with Tina4.
# A signing secret is needed to boot (Tina4 refuses without one). The routes are
# noauth and never mint a token, but the boot gate still wants a secret - so make
# one once, keep it in .env.local (gitignored), and reuse it every run after.
if [ -f .env.local ] && grep -q '^TINA4_SECRET=' .env.local; then
  TINA4_SECRET="$(grep '^TINA4_SECRET=' .env.local | head -1 | cut -d= -f2-)"
else
  TINA4_SECRET="$(openssl rand -hex 32 2>/dev/null || "$PY" -c 'import secrets; print(secrets.token_hex(32))')"
  echo "TINA4_SECRET=$TINA4_SECRET" >> .env.local
  echo "> generated a per-machine signing secret into .env.local"
fi
export TINA4_SECRET

echo "> starting the Tina4 AI server on http://127.0.0.1:${PORT} ..."
# .env pins Tina4's own asyncio server on (TINA4_DEFAULT_WEBSERVER) and keeps debug
# off, so this serves through Tina4 - no uvicorn, no dashboard.
exec tina4 serve --port "$PORT" --host 127.0.0.1 --no-browser --no-reload
