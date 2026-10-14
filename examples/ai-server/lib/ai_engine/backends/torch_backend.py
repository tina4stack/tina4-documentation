"""transformers backend — the cross-platform path (Windows, Linux, CPU or NVIDIA CUDA).

MLX is Apple-Silicon only, so on every other machine the harness falls back to plain
PyTorch + Hugging Face transformers reading the *same* distilled model. The agent loop,
tools and prompts do not change — only this file does.

Memory reporting adapts to the device:
    * **CUDA**  -> real GPU figures from ``torch.cuda`` (allocated / reserved / peak).
    * **CPU**   -> process RAM via ``psutil`` when present, else the weight size.

A word on the "cache" knob here: PyTorch has no single buffer-cache limit like MLX. The
memory that grows during a chat is the **KV cache**, and it is bounded by ``max_tokens``.
So on this backend ``set_cache_limit_gb`` is informational, and ``clear_cache()`` maps to
``torch.cuda.empty_cache()`` (a no-op on CPU). The notebook explains the difference.
"""
from __future__ import annotations

import os
import threading
import time
from pathlib import Path

from ..download import disk_size_gb, ensure_model
from ..model import GB, TORCH_REPO, GenStats, HarnessModel, Settings


class TorchModel(HarnessModel):
    backend = "torch"

    def __init__(self, models_dir=None, allow_download=True, settings: Settings | None = None):
        import threading

        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer

        self._torch = torch
        self.repo_id = TORCH_REPO
        self.settings = settings or Settings()
        self.last_stats = GenStats()
        self._stop = threading.Event()  # set by request_stop() to end a generation early

        self.path = (
            ensure_model(TORCH_REPO, models_dir, allow_download=allow_download)
            if models_dir
            else ensure_model(TORCH_REPO, allow_download=allow_download)
        )
        self.disk_gb = disk_size_gb(self.path)

        # Set the CPU thread count for BOTH devices. On CPU it is the whole compute; on CUDA
        # this model's reference kernels (gated-delta / causal-conv fallbacks) still dispatch
        # per-token CPU work, so the thread count matters there too. Default 4 (HARNESS_THREADS).
        try:
            torch.set_num_threads(int(os.environ.get("HARNESS_THREADS", "4")))
        except (ValueError, RuntimeError):
            pass

        if torch.cuda.is_available():
            self.device = "cuda"
            dtype = torch.float16
        else:
            self.device = "cpu"
            dtype = torch.float32

        t0 = time.time()
        self.tokenizer = AutoTokenizer.from_pretrained(str(self.path), trust_remote_code=True)
        try:
            self.model = AutoModelForCausalLM.from_pretrained(
                str(self.path), torch_dtype=dtype, trust_remote_code=True
            )
        except (ValueError, KeyError):
            # Qwen3.8-2B-Distill is vision-capable; load the image-text-to-text class and
            # drive its text channel. (Text generation only — we never pass an image.)
            from transformers import AutoModelForImageTextToText

            self.model = AutoModelForImageTextToText.from_pretrained(
                str(self.path), torch_dtype=dtype, trust_remote_code=True
            )
        self.model.to(self.device)
        self.model.eval()
        self.load_seconds = time.time() - t0
        self.weights_gb = sum(
            p.numel() * p.element_size() for p in self.model.parameters()
        ) / GB

    def _render(self, messages: list[dict], enable_thinking: bool = True) -> str:
        # This model's chat template honours enable_thinking (no_think = terse, no reasoning).
        # Fall back gracefully for any template that does not accept the kwarg.
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

    # --- generation ------------------------------------------------------------------
    def generate(self, messages, on_text=None, max_tokens=None, temperature=None,
                 enable_thinking=True, raw_prompt=None):
        import torch
        from transformers import StoppingCriteria, StoppingCriteriaList, TextIteratorStreamer

        self._stop.clear()  # fresh run; request_stop() will set this to interrupt

        class _StopOnFlag(StoppingCriteria):
            def __init__(self, ev):
                self._ev = ev

            def __call__(self, input_ids, scores, **kwargs):
                return self._ev.is_set()

        temp = self.settings.temperature if temperature is None else temperature
        limit = max_tokens or self.settings.max_tokens

        # raw_prompt (Tina4 addition): untemplated completion (FIM / exact prompts).
        prompt = raw_prompt if raw_prompt is not None else self._render(messages, enable_thinking)
        inputs = self.tokenizer(prompt, return_tensors="pt").to(self.device)
        prompt_tokens = int(inputs["input_ids"].shape[-1])

        streamer = TextIteratorStreamer(
            self.tokenizer, skip_prompt=True, skip_special_tokens=True
        )
        gen_kwargs = dict(
            **inputs,
            max_new_tokens=limit,
            do_sample=temp > 0,
            temperature=max(temp, 1e-5),
            streamer=streamer,
            pad_token_id=self.tokenizer.eos_token_id,
            stopping_criteria=StoppingCriteriaList([_StopOnFlag(self._stop)]),
        )
        if self.device == "cuda":
            torch.cuda.reset_peak_memory_stats()

        thread = threading.Thread(target=self.model.generate, kwargs=gen_kwargs)
        t0 = time.time()
        thread.start()

        chunks: list[str] = []
        for piece in streamer:
            chunks.append(piece)
            if on_text:
                on_text(piece)
        thread.join()
        elapsed = max(time.time() - t0, 1e-6)

        text = "".join(chunks)
        gen_tokens = int(len(self.tokenizer(text)["input_ids"]))
        peak = (
            self._torch.cuda.max_memory_allocated() / GB if self.device == "cuda" else 0.0
        )
        self.last_stats = GenStats(
            prompt_tokens=prompt_tokens,
            generation_tokens=gen_tokens,
            tokens_per_second=round(gen_tokens / elapsed, 1),
            peak_gb=round(peak, 3),
        )
        return text

    # --- telemetry -------------------------------------------------------------------
    def memory(self) -> dict:
        info = {
            "backend": self.backend,
            "device": self.device,
            "weights_gb": round(self.weights_gb, 3),
            "disk_gb": round(self.disk_gb, 3),
            "cache_limit_gb": self.settings.cache_limit_gb,
        }
        if self.device == "cuda":
            info["active_gb"] = round(self._torch.cuda.memory_allocated() / GB, 3)
            info["reserved_gb"] = round(self._torch.cuda.memory_reserved() / GB, 3)
            info["peak_gb"] = round(self._torch.cuda.max_memory_allocated() / GB, 3)
        else:
            info["active_gb"] = round(_process_ram_gb() or self.weights_gb, 3)
            info["peak_gb"] = self.last_stats.peak_gb
        return info

    def set_cache_limit_gb(self, gb):
        # transformers has no buffer-cache limit; record it for display and explanation.
        self.settings.cache_limit_gb = gb

    def clear_cache(self):
        if self.device == "cuda":
            self._torch.cuda.empty_cache()

    def reset_peak(self):
        if self.device == "cuda":
            self._torch.cuda.reset_peak_memory_stats()


def _process_ram_gb() -> float | None:
    try:
        import psutil

        return psutil.Process().memory_info().rss / GB
    except Exception:
        return None
