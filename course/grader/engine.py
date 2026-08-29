"""Talks to the Tina4 engine over MCP.

Zero dependencies: urllib from the standard library, the same rule the
framework holds itself to.

The engine is the tina4-coder MCP server. `tina4_chat` grounds the request
against the live Tina4 corpus and answers with the large-context reader, which
is what lets the examiner reason about framework behaviour rather than guess.
"""
import json
import os
import urllib.error
import urllib.request

DEFAULT_URL = "https://mcp.tina4.com/mcp"


class EngineError(RuntimeError):
    pass


class Engine:
    """Minimal MCP Streamable HTTP client, scoped to what grading needs."""

    def __init__(self, url: str = None, token: str = None, timeout: int = 180):
        self.url = url or os.environ.get("TINA4_MCP_URL", DEFAULT_URL)
        self.token = token or os.environ.get("TINA4_MCP_TOKEN", "")
        self.timeout = timeout
        self.session_id = None

        if not self.token:
            raise EngineError(
                "No engine token. Set TINA4_MCP_TOKEN to your Tina4 team token.\n"
                "  export TINA4_MCP_TOKEN=t4_..."
            )

    # ── transport ──────────────────────────────────────────────────

    def _post(self, payload: dict) -> dict:
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        }
        if self.session_id:
            headers["Mcp-Session-Id"] = self.session_id

        req = urllib.request.Request(
            self.url, data=json.dumps(payload).encode(), headers=headers, method="POST"
        )
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                sid = resp.headers.get("mcp-session-id")
                if sid:
                    self.session_id = sid
                raw = resp.read().decode()
        except urllib.error.HTTPError as e:
            raise EngineError(f"Engine HTTP {e.code}: {e.read().decode()[:400]}") from e
        except urllib.error.URLError as e:
            raise EngineError(f"Cannot reach the engine at {self.url}: {e.reason}") from e

        # The server answers plain JSON. Tolerate an SSE-framed reply too, since
        # the transport permits either and a proxy may switch it.
        if raw.lstrip().startswith("event:") or raw.lstrip().startswith("data:"):
            for line in raw.splitlines():
                if line.startswith("data:"):
                    raw = line[5:].strip()
                    break

        try:
            return json.loads(raw)
        except json.JSONDecodeError as e:
            raise EngineError(f"Engine sent non-JSON: {raw[:400]}") from e

    def connect(self) -> None:
        reply = self._post({
            "jsonrpc": "2.0", "id": 1, "method": "initialize",
            "params": {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "tina4grade", "version": "1.0"},
            },
        })
        if "error" in reply:
            raise EngineError(f"Engine refused the handshake: {reply['error']}")

    # ── grading call ───────────────────────────────────────────────

    def ask_json(self, prompt: str, language: str = "python") -> dict:
        """Send a prompt, insist on strict JSON back, return it parsed."""
        if not self.session_id:
            self.connect()

        reply = self._post({
            "jsonrpc": "2.0", "id": 2, "method": "tools/call",
            "params": {
                "name": "tina4_chat",
                "arguments": {
                    "language": language,
                    "messages": [{"role": "user", "content": prompt}],
                },
            },
        })

        if "error" in reply:
            raise EngineError(f"Engine error: {reply['error']}")

        try:
            text = reply["result"]["content"][0]["text"]
        except (KeyError, IndexError) as e:
            raise EngineError(f"Unexpected engine reply shape: {str(reply)[:400]}") from e

        return _extract_json(text)


def _extract_json(text: str) -> dict:
    """Pull a JSON object out of a reply, tolerating a code fence around it."""
    text = text.strip()

    if text.startswith("```"):
        lines = text.split("\n")
        text = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])
        text = text.strip()

    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    start, depth = text.find("{"), 0
    if start >= 0:
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    try:
                        return json.loads(text[start:i + 1])
                    except json.JSONDecodeError:
                        break

    raise EngineError(f"Examiner did not return JSON. Got: {text[:400]}")
