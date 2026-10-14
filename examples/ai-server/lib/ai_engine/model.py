"""The model adapter — the *only* part of the harness that knows which engine runs the model.

A harness does not care how tokens are produced. It needs three things from a model:

    1. ``generate(messages)``        turn a chat transcript into the next assistant message
    2. ``memory()``                  how much GPU/CPU memory it is using right now
    3. a couple of knobs            temperature and a cache limit

So we hide the engine behind one small interface, ``HarnessModel``, and pick a backend
automatically:

    * **Apple Silicon**  -> the ``mlx`` backend (fast, Metal GPU, tiny 4-bit weights).
    * **everything else** (Windows, Linux, CPU or NVIDIA) -> the ``transformers`` backend.

The agent loop, the tools and the prompts never import a backend. Swap the model and the
rest of the notebook is unchanged — that separation is the whole point of a harness.
"""
from __future__ import annotations

import os
import platform
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

GB = 1024 ** 3

# Qwen3.8-2B-Distill — a small *distill* whose chat template natively supports tool calling.
# The 4-bit MLX port is a local conversion (there is no HF repo for it), copied into the
# project's models/ folder (~1.6 GB). If that folder is absent (e.g. a fresh clone), the MLX
# backend falls back to fetching the unquantised HF weights. transformers reads the same HF repo.
# The model is swappable via env, so a reader can A/B a different model without editing code:
#   HARNESS_MLX_REPO=mlx-community/gemma-4-e4b-it-4bit ./scripts/start.sh
# When a non-default repo is chosen, its local folder defaults to the repo's flat name under
# models/ (so it never collides with the Qwen 4-bit folder and downloads cleanly on first use).
_DEFAULT_MLX_REPO = "empero-ai/Qwen3.8-2B-Distill"
MLX_REPO = os.environ.get("HARNESS_MLX_REPO", _DEFAULT_MLX_REPO)  # fallback if the 4-bit folder is missing
MLX_LOCAL_DIR = os.environ.get(
    "HARNESS_MLX_LOCAL_DIR",
    "qwen38-2b-distill-4bit" if MLX_REPO == _DEFAULT_MLX_REPO else MLX_REPO.replace("/", "__"),
)  # preferred: a folder under models/ (the Qwen default is ~1.6 GB, 4-bit)
TORCH_REPO = os.environ.get("HARNESS_TORCH_REPO", MLX_REPO)  # Windows / Linux / CPU / CUDA (transformers)


@dataclass
class Settings:
    """The live knobs a reader can change from a notebook cell."""

    temperature: float = 0.2          # 0 = deterministic; higher = more varied, less reliable tool use
    max_tokens: int = 1024            # cap on a single reply (a reasoning distill needs room to think)
    cache_limit_gb: float | None = None  # engine buffer-cache ceiling; None = engine default


@dataclass
class GenStats:
    """What the last generation cost — shown in the trace so the mechanism is visible."""

    prompt_tokens: int = 0
    generation_tokens: int = 0
    tokens_per_second: float = 0.0
    peak_gb: float = 0.0


class HarnessModel:
    """Interface every backend implements. Not abstract on purpose — the backends fill it in."""

    repo_id: str = ""
    backend: str = ""
    device: str = ""
    settings: Settings
    last_stats: GenStats

    # --- generation -------------------------------------------------------------------
    def generate(
        self,
        messages: list[dict],
        on_text: Callable[[str], None] | None = None,
        max_tokens: int | None = None,
        temperature: float | None = None,
        enable_thinking: bool = True,
        raw_prompt: str | None = None,
    ) -> str:
        """Return the next assistant message for ``messages`` (a list of {role, content}).

        If ``on_text`` is given, it is called with each streamed chunk so a notebook can
        print the model thinking in real time. ``enable_thinking`` toggles the model's
        reasoning phase via its chat template (False = terse, no ``<think>`` block).

        ``raw_prompt`` (Tina4 addition) sends a string to the model UNTEMPLATED - no
        chat template, no roles - for fill-in-the-middle and exact-prompt completion.
        When set, ``messages`` and ``enable_thinking`` are ignored.
        """
        raise NotImplementedError

    def request_stop(self) -> None:
        """Ask an in-flight ``generate`` to stop early and return what it has so far.

        Safe to call from another thread (e.g. on a kernel interrupt). Backends that cannot
        interrupt mid-generation may treat this as a no-op.
        """

    # --- telemetry --------------------------------------------------------------------
    def memory(self) -> dict:
        """A dict of memory figures in GB: weights, active, peak, cache (keys vary by backend)."""
        raise NotImplementedError

    def set_cache_limit_gb(self, gb: float | None) -> None:
        raise NotImplementedError

    def clear_cache(self) -> None:
        raise NotImplementedError

    def reset_peak(self) -> None:
        raise NotImplementedError


def pick_backend() -> str:
    """Choose a backend for this machine. Override with the HARNESS_BACKEND env var."""
    import os

    forced = os.environ.get("HARNESS_BACKEND")
    if forced:
        return forced.lower()
    if platform.system() == "Darwin" and platform.machine() == "arm64":
        return "mlx"
    return "torch"


def load_model(
    backend: str | None = None,
    models_dir: Path | str | None = None,
    allow_download: bool = True,
    settings: Settings | None = None,
    allow_remote: bool = True,
) -> HarnessModel:
    """Load the distilled model with the right backend for this machine.

    If ``HARNESS_MODEL_SERVER`` points at a running shared model server (see ``harness.server``)
    and ``allow_remote`` is set, this returns a thin proxy to it instead of loading weights — so
    every notebook kernel shares ONE model in memory. Set ``allow_remote=False`` inside the server
    itself (to actually load the weights) and to force a local, in-kernel model.

    Otherwise the weights are fetched into the project's ``models/`` folder on first use (see
    ``download.ensure_model``), so a second run — and an offline run — is instant.
    """
    import os

    settings = settings or Settings()

    server_url = os.environ.get("HARNESS_MODEL_SERVER")
    if allow_remote and server_url:
        from .backends.remote_backend import RemoteModel, reachable

        if reachable(server_url):
            return RemoteModel(server_url, settings=settings)
        # Server configured but not up yet → fall through to a local load so nothing breaks.

    backend = (backend or pick_backend()).lower()

    if backend == "mlx":
        from .backends.mlx_backend import MLXModel

        return MLXModel(models_dir=models_dir, allow_download=allow_download, settings=settings)
    if backend in ("torch", "transformers"):
        from .backends.torch_backend import TorchModel

        return TorchModel(models_dir=models_dir, allow_download=allow_download, settings=settings)
    raise ValueError(f"Unknown backend '{backend}'. Use 'mlx' or 'torch'.")


def format_memory(mem: dict) -> str:
    """A one-line, human-readable summary of ``model.memory()`` for the telemetry cell."""
    parts = [f"backend={mem.get('backend')}", f"device={mem.get('device')}"]
    for key in ("weights_gb", "active_gb", "peak_gb", "cache_gb", "reserved_gb", "disk_gb"):
        if mem.get(key) is not None:
            parts.append(f"{key}={mem[key]}")
    if mem.get("cache_limit_gb") is not None:
        parts.append(f"cache_limit_gb={mem['cache_limit_gb']}")
    return " · ".join(parts)
