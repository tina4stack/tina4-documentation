# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
"""The local AI model server - served by Tina4 itself.

No FastAPI, no Flask: Tina4 handles the HTTP, and the tokens come from the vendored
``ai_engine`` code (MLX on Apple Silicon, torch on CUDA or CPU) in ``lib/`` - the
server clones nothing. These routes mirror the harness model server exactly - same
``/generate``, ``/describe``, ``/health``, ``/memory`` paths and the same request
and reply shapes - so anything already pointed at the harness server keeps working
when it is pointed here instead.

The handlers are plain ``def`` on purpose. A generation blocks until the model
replies, so Tina4 runs it on a worker thread and the event loop stays free for the
next request. One model cannot run two generations at once, so a lock lets them
queue rather than collide.
"""
import asyncio
import base64
import datetime
import json
import os
import tempfile
import threading

from tina4_python.core.router import get, post, noauth

from ai_engine.model import Settings, load_model

# The standardized dev-admin <-> model protocol is Ollama-native /api/chat. This
# route is a STRAIGHT PASS-THROUGH: the messages (the prompt) and the options
# (temperature, num_predict, ...) go to the model exactly as sent. No prompting,
# no system-message injection, no opinionated defaults live here - dev-admin owns
# all of that and tweaks it freely. The only things this layer touches are the
# wire-format mechanics: `think` (thinking on/off), inline `images` (vision), and
# `stream` (NDJSON), plus mapping the model's output back to the Ollama shape.

_model = None
_load_lock = threading.Lock()   # load the weights once, however many requests race in
_gen_lock = threading.Lock()    # one generation at a time on the single model


def _model_instance():
    """The one shared model, loaded locally on first use (never via a remote proxy)."""
    global _model
    if _model is None:
        with _load_lock:
            if _model is None:
                _model = load_model(allow_remote=False, settings=Settings())
    return _model


@get("/health")
def health(request, response):
    return response("ok")


@get("/info")
def info(request, response):
    model = _model_instance()
    return response({"repo_id": model.repo_id, "backend": model.backend, "device": model.device})


@get("/memory")
def memory(request, response):
    return response(_model_instance().memory())


@noauth()
@post("/generate")
def generate(request, response):
    body = request.body or {}
    messages = body.get("messages")
    if not isinstance(messages, list) or not messages:
        return response({"error": "messages must be a non-empty list"}, 400)
    model = _model_instance()
    with _gen_lock:
        text = model.generate(
            messages,
            max_tokens=body.get("max_tokens"),
            temperature=body.get("temperature"),
            enable_thinking=bool(body.get("enable_thinking", True)),
        )
    return response({"text": text})


@noauth()
@post("/describe")
def describe(request, response):
    body = request.body or {}
    image = body.get("image")
    if not isinstance(image, str) or not image:
        return response({"error": "image (a local file path) is required"}, 400)
    model = _model_instance()
    with _gen_lock:
        text = model.describe(
            image,
            body.get("prompt", "Describe this image."),
            max_tokens=int(body.get("max_tokens", 512)),
        )
    return response({"text": text})


# ── /api/chat — the standardized protocol (Ollama-native) ──────────────────

def _now_iso():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _split_think(text):
    """Separate a reasoning model's <think> block from its final answer."""
    if "</think>" in text:
        pre, _, post = text.partition("</think>")
        return pre.replace("<think>", "").strip(), post.strip()
    return "", text.strip()


def _last_image(messages):
    """The last inline base64 image found on any message (Ollama shape), or None."""
    for msg in reversed(messages):
        imgs = msg.get("images") if isinstance(msg, dict) else None
        if isinstance(imgs, list) and imgs:
            return imgs[0]
    return None


def _last_user_text(messages):
    for msg in reversed(messages):
        if isinstance(msg, dict) and msg.get("role") == "user":
            content = msg.get("content")
            if isinstance(content, str) and content.strip():
                return content
    return ""


def _write_temp_image(image_b64):
    """Decode a base64 image (optionally a data: URI) to a temp file; return the path."""
    data = image_b64
    if isinstance(data, str) and data.startswith("data:") and "," in data:
        data = data.split(",", 1)[1]
    raw = base64.b64decode(data)
    fd, path = tempfile.mkstemp(suffix=".img")
    with os.fdopen(fd, "wb") as handle:
        handle.write(raw)
    return path


def _ollama_message(model_name, content, thinking, done):
    """One Ollama-shaped chat frame. `thinking` is added only when non-empty."""
    message = {"role": "assistant", "content": content}
    if thinking:
        message["thinking"] = thinking
    frame = {"model": model_name, "created_at": _now_iso(), "message": message, "done": done}
    if done:
        frame["done_reason"] = "stop"
    return frame


@noauth()
@post("/api/chat")
async def api_chat(request, response):
    """Ollama-native chat - the standardized protocol the gateway forwards.

    Knobs the harness needs: ``think`` (thinking on/off), ``mode``
    (chat|instructional|coding - a system prompt + temperature when the caller
    sends none), and vision via inline ``images`` on a message. Streams NDJSON
    when ``stream`` is true, splitting the model's <think> block into ``thinking``
    so the Tina4 model answers byte-compatibly with Ollama.
    """
    body = request.body or {}
    messages = body.get("messages")
    if not isinstance(messages, list) or not messages:
        return response({"error": "messages must be a non-empty list"}, 400)

    model = _model_instance()
    model_name = body.get("model") or model.repo_id
    opts = body.get("options") if isinstance(body.get("options"), dict) else {}
    think = bool(body.get("think", True))
    stream = bool(body.get("stream", False))
    # Options pass straight through; absent ones stay None so the model uses its own.
    max_tokens = opts.get("num_predict") or body.get("max_tokens")
    temperature = opts.get("temperature")
    if temperature is None:
        temperature = body.get("temperature")

    loop = asyncio.get_running_loop()

    # Vision: an inline image routes to the model's describe() (single-shot).
    image_b64 = _last_image(messages)
    if image_b64:
        prompt = _last_user_text(messages) or "Describe this image."

        def _describe():
            path = _write_temp_image(image_b64)
            try:
                with _gen_lock:
                    return model.describe(path, prompt, max_tokens=int(max_tokens or 512))
            finally:
                try:
                    os.remove(path)
                except OSError:
                    pass

        text = await loop.run_in_executor(None, _describe)
        thinking, content = _split_think(text)
        if stream:
            async def _one():
                if thinking:
                    yield json.dumps(_ollama_message(model_name, "", thinking, False)) + "\n"
                yield json.dumps(_ollama_message(model_name, content, "", False)) + "\n"
                yield json.dumps(_ollama_message(model_name, "", "", True)) + "\n"
            return response.stream(_one(), content_type="application/x-ndjson")
        return response(_ollama_message(model_name, content, thinking, True))

    # Text, single-shot: run the blocking generate off the event loop. Messages
    # pass straight through - no system prompt added here.
    if not stream:
        def _generate():
            with _gen_lock:
                return model.generate(messages, max_tokens=max_tokens,
                                      temperature=temperature, enable_thinking=think)
        text = await loop.run_in_executor(None, _generate)
        thinking, content = _split_think(text)
        return response(_ollama_message(model_name, content, thinking, True))

    # Text, streaming: a worker thread feeds chunks onto a queue; we emit NDJSON,
    # routing the <think> prefix into `thinking` and the rest into `content`.
    queue: asyncio.Queue = asyncio.Queue()

    def _on_text(chunk):
        loop.call_soon_threadsafe(queue.put_nowait, chunk)

    def _run():
        try:
            with _gen_lock:
                model.generate(messages, on_text=_on_text, max_tokens=max_tokens,
                               temperature=temperature, enable_thinking=think)
        finally:
            loop.call_soon_threadsafe(queue.put_nowait, None)

    threading.Thread(target=_run, daemon=True).start()

    async def _stream():
        in_think = think                      # thinking on => the model reasons first
        while True:
            chunk = await queue.get()
            if chunk is None:
                yield json.dumps(_ollama_message(model_name, "", "", True)) + "\n"
                return
            if in_think and "</think>" in chunk:
                pre, _, post = chunk.partition("</think>")
                pre = pre.replace("<think>", "")
                if pre:
                    yield json.dumps(_ollama_message(model_name, "", pre, False)) + "\n"
                in_think = False
                if post:
                    yield json.dumps(_ollama_message(model_name, post, "", False)) + "\n"
            elif in_think:
                yield json.dumps(_ollama_message(model_name, "", chunk.replace("<think>", ""), False)) + "\n"
            else:
                yield json.dumps(_ollama_message(model_name, chunk, "", False)) + "\n"

    return response.stream(_stream(), content_type="application/x-ndjson")


# ── /api/generate — completion, incl. RAW (untemplated) prompts ────────────

def _ollama_gen_frame(model_name, text, thinking, done):
    """One Ollama /api/generate frame - note it uses `response`, not `message`."""
    frame = {"model": model_name, "created_at": _now_iso(), "response": text, "done": done}
    if thinking:
        frame["thinking"] = thinking
    if done:
        frame["done_reason"] = "stop"
    return frame


@noauth()
@post("/api/generate")
async def api_generate(request, response):
    """Ollama-native completion. ``raw: true`` sends ``prompt`` to the model
    UNTEMPLATED - no chat template, no roles - for fill-in-the-middle and exact
    prompts. Otherwise the prompt is one user turn through the template (with an
    optional ``system``). Options + prompt pass straight through; nothing is added
    here. ``think``, inline ``images`` (vision) and ``stream`` behave as on /api/chat.
    """
    body = request.body or {}
    prompt = body.get("prompt")
    if not isinstance(prompt, str) or not prompt:
        return response({"error": "prompt must be a non-empty string"}, 400)

    model = _model_instance()
    model_name = body.get("model") or model.repo_id
    opts = body.get("options") if isinstance(body.get("options"), dict) else {}
    raw = bool(body.get("raw", False))
    think = bool(body.get("think", not raw))        # raw => no template => thinking N/A
    stream = bool(body.get("stream", False))
    max_tokens = opts.get("num_predict") or body.get("max_tokens")
    temperature = opts.get("temperature")
    if temperature is None:
        temperature = body.get("temperature")

    loop = asyncio.get_running_loop()

    # Vision: an inline image + the prompt route to describe().
    images = body.get("images")
    image_b64 = images[0] if isinstance(images, list) and images else None
    if image_b64:
        def _describe():
            path = _write_temp_image(image_b64)
            try:
                with _gen_lock:
                    return model.describe(path, prompt, max_tokens=int(max_tokens or 512))
            finally:
                try:
                    os.remove(path)
                except OSError:
                    pass
        text = await loop.run_in_executor(None, _describe)
        if stream:
            async def _one():
                yield json.dumps(_ollama_gen_frame(model_name, text, "", False)) + "\n"
                yield json.dumps(_ollama_gen_frame(model_name, "", "", True)) + "\n"
            return response.stream(_one(), content_type="application/x-ndjson")
        return response(_ollama_gen_frame(model_name, text, "", True))

    # The generate call: raw => untemplated; else a single user turn (+ optional system).
    def _call(on_text=None):
        if raw:
            return model.generate([], on_text=on_text, max_tokens=max_tokens,
                                  temperature=temperature, raw_prompt=prompt)
        msgs = []
        system = body.get("system")
        if isinstance(system, str) and system:
            msgs.append({"role": "system", "content": system})
        msgs.append({"role": "user", "content": prompt})
        return model.generate(msgs, on_text=on_text, max_tokens=max_tokens,
                              temperature=temperature, enable_thinking=think)

    if not stream:
        def _blocking():
            with _gen_lock:
                return _call()
        text = await loop.run_in_executor(None, _blocking)
        if raw:
            return response(_ollama_gen_frame(model_name, text, "", True))
        thinking, content = _split_think(text)
        return response(_ollama_gen_frame(model_name, content, thinking, True))

    # Streaming completion.
    queue: asyncio.Queue = asyncio.Queue()

    def _on_text(chunk):
        loop.call_soon_threadsafe(queue.put_nowait, chunk)

    def _run():
        try:
            with _gen_lock:
                _call(on_text=_on_text)
        finally:
            loop.call_soon_threadsafe(queue.put_nowait, None)

    threading.Thread(target=_run, daemon=True).start()

    async def _stream():
        in_think = think and not raw
        while True:
            chunk = await queue.get()
            if chunk is None:
                yield json.dumps(_ollama_gen_frame(model_name, "", "", True)) + "\n"
                return
            if in_think and "</think>" in chunk:
                pre, _, post = chunk.partition("</think>")
                pre = pre.replace("<think>", "")
                if pre:
                    yield json.dumps(_ollama_gen_frame(model_name, "", pre, False)) + "\n"
                in_think = False
                if post:
                    yield json.dumps(_ollama_gen_frame(model_name, post, "", False)) + "\n"
            elif in_think:
                yield json.dumps(_ollama_gen_frame(model_name, "", chunk.replace("<think>", ""), False)) + "\n"
            else:
                yield json.dumps(_ollama_gen_frame(model_name, chunk, "", False)) + "\n"

    return response.stream(_stream(), content_type="application/x-ndjson")
