"""A thin proxy to the shared model server (see ``harness.server``).

A kernel that gets a :class:`RemoteModel` from ``load_model()`` never loads weights itself — it
forwards generate()/describe()/memory() to the one server process over HTTP. So opening ten
notebooks costs one model's worth of memory, not ten. The interface matches the local backends,
including streaming via the ``on_text`` callback, so the harness, the chat and the menus don't
know (or care) that the model lives in another process.
"""
from __future__ import annotations

import base64
import json
import urllib.request

from ..model import GenStats, HarnessModel, Settings


class RemoteModel(HarnessModel):
    backend = "remote"

    def __init__(self, url: str, settings: Settings | None = None):
        self.url = url.rstrip("/")
        self.settings = settings or Settings()
        self.last_stats = GenStats()
        info = self._get("/info")
        self.repo_id = info.get("repo_id", "")
        self.device = info.get("device", "")
        self.server_backend = info.get("backend", "")

    # --- http helpers ----------------------------------------------------------------
    def _get(self, path: str) -> dict:
        with urllib.request.urlopen(self.url + path, timeout=30) as r:
            return json.loads(r.read().decode("utf-8"))

    def _post(self, path: str, payload: dict, timeout: int = 600) -> dict:
        req = urllib.request.Request(
            self.url + path, data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}, method="POST",
        )
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))

    # --- generation ------------------------------------------------------------------
    def generate(self, messages, on_text=None, max_tokens=None, temperature=None,
                 enable_thinking: bool = True) -> str:
        payload = {
            "messages": messages,
            "max_tokens": max_tokens if max_tokens is not None else self.settings.max_tokens,
            "temperature": temperature if temperature is not None else self.settings.temperature,
            "enable_thinking": enable_thinking,
            "stream": on_text is not None,
        }
        if on_text is None:
            out = self._post("/generate", payload)
            if "error" in out:
                raise RuntimeError(out["error"])
            return out.get("text", "")
        # Streaming: read ndjson base64 deltas until "__END__".
        req = urllib.request.Request(
            self.url + "/generate", data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}, method="POST",
        )
        parts: list[str] = []
        with urllib.request.urlopen(req, timeout=600) as r:
            for raw in r:
                line = raw.strip()
                if not line or line == b"__END__":
                    if line == b"__END__":
                        break
                    continue
                try:
                    chunk = base64.b64decode(line).decode("utf-8")
                except Exception:
                    continue
                parts.append(chunk)
                try:
                    on_text(chunk)
                except Exception:
                    pass
        return "".join(parts)

    # --- vision (same shared model) --------------------------------------------------
    def describe(self, image, prompt: str = "Describe this image.", max_tokens: int = 512, temperature=None, pixels=None) -> str:
        payload = {"image": str(image), "prompt": prompt, "max_tokens": max_tokens}
        if pixels:
            payload["pixels"] = int(pixels)
        out = self._post("/describe", payload)
        if "error" in out:
            raise RuntimeError(out["error"])
        return out.get("text", "")

    # --- telemetry (forwarded) -------------------------------------------------------
    def memory(self) -> dict:
        try:
            mem = self._get("/memory")
            mem["shared"] = True
            mem["server"] = self.url
            return mem
        except Exception as exc:
            return {"backend": "remote", "server": self.url, "error": str(exc)}

    def set_cache_limit_gb(self, gb):  # cache lives on the server; a no-op from the proxy
        return None

    def clear_cache(self):
        return None

    def reset_peak(self):
        return None


def reachable(url: str, timeout: float = 1.5) -> bool:
    """Is a model server answering at ``url``?"""
    try:
        with urllib.request.urlopen(url.rstrip("/") + "/health", timeout=timeout) as r:
            return r.status == 200
    except Exception:
        return False
