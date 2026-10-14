"""MLX backend — the fast path on Apple Silicon (M-series) using the Metal GPU.

Qwen3.8-2B-Distill is a *vision* model, so this one backend serves BOTH text and images through
**mlx-vlm** — a single set of weights in memory for the whole harness (text generation, the
right-click menus, the chat, and reading images). Loading it twice (once for text, once for
vision) is exactly the memory waste this avoids.

Text generation keeps the reasoning visible (`enable_thinking=True`, so the model still emits
`<think> … </think>`), which is what the teaching notebook shows. Images go through the same
model's vision path via :meth:`describe`.

Two caches to keep straight:
    * **Buffer cache** (``set_cache_limit``): freed GPU buffers MLX keeps to reuse. Capped by
      default to keep held memory down; raise it for speed. ``clear_cache()`` frees it.
    * **KV cache**: attention keys/values that grow with the conversation length — not a setting.
"""
from __future__ import annotations

import time
from pathlib import Path

import os
import tempfile

from ..download import MODELS_DIR, _has_weights, disk_size_gb, ensure_model
from ..model import GB, MLX_LOCAL_DIR, MLX_REPO, GenStats, HarnessModel, Settings


def _prep_image(path: str, target: int | None = None) -> str:
    """Normalise an image to the vision model's pixel sweet spot so fine text stays legible.

    Resizes (up OR down) with a sharp LANCZOS filter so the total pixel count is ~target pixels
    (``target``, else HARNESS_VISION_PIXELS, else 1,200,000 — empirically where the 2B reads small
    text best; bigger regresses. A different VLM has a different sweet spot, so it is overridable per
    request). Keeps the aspect ratio, writes a lossless WebP temp (smaller than PNG, identical
    pixels), and returns its path — or the original path unchanged when already in band or on any
    error (PIL/WebP missing)."""
    try:
        from PIL import Image
    except Exception:
        return path
    try:
        target = int(target if target else os.environ.get("HARNESS_VISION_PIXELS", "1200000"))
        im = Image.open(path).convert("RGB")
        w, h = im.size
        px = w * h
        if px <= 0 or target <= 0:
            return path
        scale = (target / px) ** 0.5
        if 0.92 <= scale <= 1.08:          # already close enough — don't touch it
            return path
        nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
        im = im.resize((nw, nh), Image.LANCZOS)
        fd, out = tempfile.mkstemp(suffix=".webp", prefix="harness-vision-")
        os.close(fd)
        im.save(out, "WEBP", lossless=True)
        return out
    except Exception:
        return path


class MLXModel(HarnessModel):
    backend = "mlx"

    def __init__(self, models_dir=None, allow_download=True, settings: Settings | None = None):
        import mlx.core as mx
        from mlx_vlm import load

        import threading

        self._mx = mx
        self.device = "metal-gpu"
        self.settings = settings or Settings()
        self.last_stats = GenStats()
        self._stop = threading.Event()  # set by request_stop() to end a generation early

        base = Path(models_dir) if models_dir else MODELS_DIR
        local = base / MLX_LOCAL_DIR
        if _has_weights(local):
            self.path = local
            self.repo_id = MLX_LOCAL_DIR
        else:
            self.path = ensure_model(MLX_REPO, base, allow_download=allow_download)
            self.repo_id = MLX_REPO
        self.disk_gb = disk_size_gb(self.path)

        mx.reset_peak_memory()
        before = mx.get_active_memory()
        t0 = time.time()
        # One vision-language model for text AND images (mlx-vlm).
        self.model, self.processor = load(str(self.path))
        self.tokenizer = getattr(self.processor, "tokenizer", self.processor)
        self.config = getattr(self.model, "config", None)
        self._warmup()
        self.weights_gb = max(0.0, (mx.get_active_memory() - before) / GB)
        self.load_seconds = time.time() - t0
        mx.reset_peak_memory()

        self.set_cache_limit_gb(self.settings.cache_limit_gb if self.settings.cache_limit_gb is not None else 1.0)

    # --- helpers ---------------------------------------------------------------------
    def _warmup(self) -> None:
        from mlx_vlm import generate

        prompt = self._render([{"role": "user", "content": "hi"}])
        generate(self.model, self.processor, prompt, image=None, max_tokens=1, verbose=False)

    def _render(self, messages: list[dict], enable_thinking: bool = True) -> str:
        # enable_thinking=True keeps the <think> reasoning the teaching notebook shows;
        # False renders a terse no-reasoning prompt.
        try:
            return self.tokenizer.apply_chat_template(
                messages, tokenize=False, add_generation_prompt=True,
                enable_thinking=enable_thinking,
            )
        except TypeError:
            return self.tokenizer.apply_chat_template(
                messages, tokenize=False, add_generation_prompt=True
            )

    def request_stop(self) -> None:
        """End the current generation at the next token (see model.py)."""
        self._stop.set()

    # --- text generation -------------------------------------------------------------
    def generate(self, messages, on_text=None, max_tokens=None, temperature=None,
                 enable_thinking=True, raw_prompt=None):
        from mlx_vlm import stream_generate

        self._stop.clear()  # fresh run; request_stop() will set this to interrupt
        temp = self.settings.temperature if temperature is None else temperature
        limit = max_tokens or self.settings.max_tokens
        # raw_prompt (Tina4 addition): send the string to the model UNTEMPLATED, for
        # fill-in-the-middle / exact-prompt completion. Otherwise apply the chat template.
        prompt = raw_prompt if raw_prompt is not None else self._render(messages, enable_thinking)

        # A repetition penalty stops the small model degenerating into a loop (e.g. "No ORM, No
        # routing, …" forever). 1.3 over the last ~48 tokens is a sane default; tune via env.
        rep = float(os.environ.get("HARNESS_REPETITION_PENALTY", "1.18"))
        rep_ctx = int(os.environ.get("HARNESS_REPETITION_CONTEXT", "64"))
        chunks: list[str] = []
        last = None
        for resp in stream_generate(
            self.model, self.processor, prompt, image=None, max_tokens=limit, temperature=temp,
            repetition_penalty=rep, repetition_context_size=rep_ctx,
        ):
            chunks.append(resp.text)
            if on_text:
                on_text(resp.text)
            last = resp
            if self._stop.is_set():  # Stop button / kernel interrupt → end early
                break

        if last is not None:
            self.last_stats = GenStats(
                prompt_tokens=getattr(last, "prompt_tokens", 0),
                generation_tokens=getattr(last, "generation_tokens", 0),
                tokens_per_second=round(getattr(last, "generation_tps", 0.0) or 0.0, 1),
                peak_gb=round(self._mx.get_peak_memory() / GB, 3),
            )
        return "".join(chunks)

    # --- vision (same model) ---------------------------------------------------------
    def describe(self, image, prompt: str = "Describe this image.", max_tokens: int = 512, temperature=None, pixels=None) -> str:
        """Answer a question about an image — using the same weights as text generation.

        The image is first normalised to the model's pixel sweet spot (see :func:`_prep_image`):
        the Qwen2-VL processor only downscales very large images and never upscales small ones, so a
        native screenshot or a small PNG arrives too small to read fine text. A sharp LANCZOS resize
        to ~1.2M px makes small text legible (empirically, 'import antigravity' goes from garbled to
        correct). The source FORMAT is irrelevant — PNG and lossless WebP are pixel-identical — so
        this is the real quality lever, not PNG-vs-JPEG-vs-WebP."""
        from mlx_vlm import generate
        from mlx_vlm.prompt_utils import apply_chat_template

        img_path = _prep_image(str(image), pixels)
        temp = self.settings.temperature if temperature is None else temperature
        vprompt = apply_chat_template(self.processor, self.config, prompt, num_images=1)
        try:
            result = generate(
                self.model, self.processor, vprompt, image=[img_path],
                max_tokens=max_tokens, temperature=temp, verbose=False,
            )
        finally:
            if img_path != str(image):
                try:
                    Path(img_path).unlink()
                except Exception:
                    pass
        return result.text if hasattr(result, "text") else str(result)

    # --- telemetry -------------------------------------------------------------------
    def memory(self) -> dict:
        mx = self._mx
        return {
            "backend": self.backend,
            "device": self.device,
            "weights_gb": round(self.weights_gb, 3),
            "disk_gb": round(self.disk_gb, 3),
            "active_gb": round(mx.get_active_memory() / GB, 3),
            "peak_gb": round(mx.get_peak_memory() / GB, 3),
            "cache_gb": round(mx.get_cache_memory() / GB, 3),
            "cache_limit_gb": self.settings.cache_limit_gb,
        }

    def set_cache_limit_gb(self, gb):
        self.settings.cache_limit_gb = gb
        limit_bytes = (2 ** 62) if gb is None else int(gb * GB)
        self._mx.set_cache_limit(limit_bytes)

    def clear_cache(self):
        self._mx.clear_cache()

    def reset_peak(self):
        self._mx.reset_peak_memory()
