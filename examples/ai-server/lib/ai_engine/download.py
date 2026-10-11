"""Fetch a model into the project's own ``models/`` folder — so it is portable, copyable,
and works the same on macOS, Linux and Windows.

Why a project-local ``models/`` folder instead of the Hugging Face cache?
    * It is easy to see, copy, zip, or move onto an offline Windows machine.
    * The files are *real files*, not symlinks into a shared cache — Windows has no
      reliable symlinks, and a symlinked cache cannot just be copied to a USB stick.
    * The whole demo is self-contained: everything it needs lives under the repo.

``ensure_model()`` is the only function you need: give it a Hugging Face repo id, it
returns a local path with the weights present, downloading them once if they are missing.
"""
from __future__ import annotations

import os
import shutil
from pathlib import Path

# The project root is two levels up from this file: src/harness/download.py -> <root>
PROJECT_ROOT = Path(__file__).resolve().parents[2]
MODELS_DIR = PROJECT_ROOT / "models"

# A file whose presence means "the weights finished downloading". Any of these counts.
_WEIGHT_MARKERS = ("*.safetensors", "*.gguf", "*.npz", "consolidated.safetensors")


def _folder_name(repo_id: str) -> str:
    """``mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit`` -> a flat, filesystem-safe folder name."""
    return repo_id.replace("/", "__")


def _has_weights(path: Path) -> bool:
    if not path.is_dir():
        return False
    for pattern in _WEIGHT_MARKERS:
        if any(path.glob(pattern)):
            return True
    return False


def local_path_for(repo_id: str, models_dir: Path | str = MODELS_DIR) -> Path:
    """Where this repo's files live (or will live) inside the project."""
    return Path(models_dir) / _folder_name(repo_id)


def ensure_model(
    repo_id: str,
    models_dir: Path | str = MODELS_DIR,
    *,
    allow_download: bool = True,
    progress: bool = True,
) -> Path:
    """Return a local folder that contains ``repo_id``'s weights, downloading once if needed.

    1. If ``models/<repo>/`` already has weights, use it (fully offline, instant).
    2. Otherwise, if ``allow_download``, fetch it with ``huggingface_hub`` straight into
       that folder as real files (no symlinks), then return it.
    3. If the weights are missing and downloading is off, raise with a clear message.
    """
    dst = local_path_for(repo_id, models_dir)
    if _has_weights(dst):
        return dst

    if not allow_download:
        raise FileNotFoundError(
            f"Model '{repo_id}' is not in {dst} and downloading is disabled. "
            f"Copy the model folder there, or call ensure_model(..., allow_download=True)."
        )

    try:
        from huggingface_hub import snapshot_download
    except ImportError as exc:  # pragma: no cover - environment guard
        raise RuntimeError(
            "huggingface_hub is required to download a model. It ships with mlx_lm and "
            "transformers; install one of those, or copy the model into models/ by hand."
        ) from exc

    dst.mkdir(parents=True, exist_ok=True)
    if progress:
        # Plain ASCII: a Unicode arrow/ellipsis crashes on Windows consoles (cp1252 stdout).
        print(f"Downloading {repo_id} into {dst} (first run only)...", flush=True)

    # local_dir writes real files into our folder. Older hub versions understand the
    # symlink toggle; newer ones copy by default — try the explicit form, fall back cleanly.
    kwargs = dict(repo_id=repo_id, local_dir=str(dst))
    try:
        snapshot_download(**kwargs, local_dir_use_symlinks=False)  # type: ignore[arg-type]
    except TypeError:
        snapshot_download(**kwargs)

    # A defensive sweep: if the hub left any symlinks (old versions), materialise them so the
    # folder is safe to copy to Windows / an offline box.
    _dereference_symlinks(dst)

    if not _has_weights(dst):
        raise RuntimeError(f"Download finished but no weight files were found in {dst}.")
    return dst


def _dereference_symlinks(root: Path) -> None:
    for path in root.rglob("*"):
        if path.is_symlink():
            target = path.resolve()
            path.unlink()
            if target.is_file():
                shutil.copy2(target, path)


def disk_size_gb(path: Path | str) -> float:
    """Total size of a model folder on disk, in GB — what you would copy to another machine."""
    total = 0
    for p in Path(path).rglob("*"):
        if p.is_file() and not p.is_symlink():
            total += p.stat().st_size
    return total / (1024 ** 3)
