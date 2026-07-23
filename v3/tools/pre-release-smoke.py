#!/usr/bin/env python3
"""
Pre-release smoke test for a Tina4 framework instance.

Boots a known framework (PHP/Python/Ruby/Node) on its conventional
port and drives a canonical user flow against it. Asserts a baseline
of behaviour we don't want to ship without. Run BEFORE tagging any
framework release; CI runs this on every commit to v3.

Usage:
    python3 pre-release-smoke.py --port 7145 --framework php

Exit code 0 = ship-ready. Non-zero = stop.

The harness is intentionally small — every check must be cheap,
deterministic, and explain its failure in one line. No flaky LLM
calls in this script. Chat / supervisor flows live in a separate
e2e harness because they need a model and are non-deterministic.
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request
import urllib.error

# Tools every framework MUST register. Missing one == release blocker.
SPEC_V1_TOOLS = {
    # File ops
    "file_read", "file_write", "file_patch", "file_list",
    # DB
    "database_query", "database_execute", "database_tables", "database_columns",
    # Routes
    "route_list", "route_test",
    # Migrations
    "migration_status", "migration_create", "migration_run",
    # Plan + index + docs
    "plan_current", "plan_list", "plan_create", "plan_switch_to",
    "plan_complete_step", "plan_add_step", "plan_note", "plan_archive",
    "plan_read", "plan_flesh",
    "index_rebuild", "index_search", "index_file", "index_overview",
    "docs_list", "docs_search", "docs_section",
    # Misc
    "git_status", "deps_list", "project_overview",
    "log_tail", "error_log", "env_list", "system_info",
    "queue_status", "session_list", "cache_stats", "orm_describe",
    "seed_table", "asset_upload",
    # Custom-tool
    "swagger_spec", "template_render",
}

# Tools we WANT in v2 but don't block release on yet (warning only).
SPEC_V2_WANTED = {
    "file_rename", "file_delete",
    "route_create", "model_create", "template_create",
    "image_generate", "git_commit",
    # Live API RAG tools (per plan/v3/22-LIVE-API-RAG.md). Block release
    # once shipped — currently warning-only while we roll across all 4
    # frameworks. Promote to SPEC_V1_TOOLS once Ruby + Node land.
    "api_search", "api_class", "api_method",
}

CHECKS = []


def check(name):
    """Decorator to register a check function."""
    def deco(fn):
        CHECKS.append((name, fn))
        return fn
    return deco


def http_get(url, timeout=5):
    """GET a URL, return (status, body_bytes). Raises on connection error."""
    req = urllib.request.Request(url)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def http_post(url, body, timeout=10):
    data = json.dumps(body).encode("utf-8") if not isinstance(body, bytes) else body
    req = urllib.request.Request(url, data=data, method="POST",
                                  headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


@check("dev-admin SPA reachable")
def check_dev_admin_loads(ctx):
    status, body = http_get(f"http://localhost:{ctx['port']}/__dev")
    assert status == 200, f"GET /__dev returned {status}"
    assert b"<div id=\"app\"" in body or b"id=\"app\"" in body, \
        "SPA shell missing #app element"


@check("status endpoint reports framework")
def check_status(ctx):
    status, body = http_get(f"http://localhost:{ctx['port']}/__dev/api/status")
    assert status == 200, f"status returned {status}"
    data = json.loads(body)
    fw = data.get("framework", "")
    ver = data.get("framework_version", "")
    assert fw, "framework field missing"
    assert ver, "framework_version field missing"
    ctx["fw"] = fw
    ctx["fw_version"] = ver
    print(f"      → {fw} {ver}")


@check("MCP tool list returns ≥45 tools")
def check_mcp_tool_count(ctx):
    status, body = http_get(f"http://localhost:{ctx['port']}/__dev/api/mcp/tools")
    assert status == 200, f"/mcp/tools returned {status}"
    data = json.loads(body)
    tools = data.get("tools", data) if isinstance(data, dict) else data
    names = {t["name"] for t in tools}
    ctx["tools"] = names
    assert len(names) >= 45, f"only {len(names)} tools registered (expected ≥45)"
    print(f"      → {len(names)} tools registered")


@check("MCP spec v1 — every required tool present")
def check_mcp_spec_v1(ctx):
    missing = SPEC_V1_TOOLS - ctx["tools"]
    assert not missing, f"missing v1 tools: {sorted(missing)}"


@check("MCP spec v2 — wanted tools (warning only)")
def check_mcp_spec_v2(ctx):
    missing = SPEC_V2_WANTED - ctx["tools"]
    if missing:
        # Warning, not failure — v2 spec is in flight.
        print(f"      ⚠ v2 wanted but missing: {sorted(missing)}")
    else:
        print("      → v2 spec satisfied")


@check("MCP /mcp/call dispatches a known tool")
def check_mcp_call(ctx):
    status, body = http_post(
        f"http://localhost:{ctx['port']}/__dev/api/mcp/call",
        {"name": "system_info", "arguments": {}},
    )
    assert status == 200, f"/mcp/call returned {status}: {body[:200]}"
    data = json.loads(body)
    assert data.get("ok") in (True, None) and "result" in data, \
        f"unexpected envelope: {body[:200]}"


@check("file_patch on a fresh file works (regression: realpath false)")
def check_file_patch_new_file(ctx):
    """The realpath() bug rejected file_patch when the parent dir
    didn't exist. Verify a write-then-patch on a nested-new-dir path
    succeeds."""
    rel_path = f"plan/_smoke_{int(time.time())}.txt"
    s, b = http_post(
        f"http://localhost:{ctx['port']}/__dev/api/mcp/call",
        {"name": "file_write",
         "arguments": {"path": rel_path, "content": "alpha\n"}},
    )
    assert s == 200, f"file_write {s}: {b[:200]}"
    s, b = http_post(
        f"http://localhost:{ctx['port']}/__dev/api/mcp/call",
        {"name": "file_patch",
         "arguments": {"path": rel_path,
                       "old_string": "alpha", "new_string": "beta"}},
    )
    assert s == 200, f"file_patch {s}: {b[:200]}"
    data = json.loads(b)
    assert data.get("ok") and data.get("result", {}).get("patched"), \
        f"file_patch did not report a patched path: {data}"
    # Cleanup attempt — non-fatal.
    http_post(f"http://localhost:{ctx['port']}/__dev/api/file/delete",
              {"path": rel_path})


@check("/ai/api/chat returns compact JSON (regression: chat dies mid-stream)")
def check_chat_compact_json(ctx):
    if not os.environ.get("TINA4_AI_URL", "").strip() and \
       "andrevanzuydam.com" not in os.environ.get("TINA4_AI_URL_DEFAULT", "andrevanzuydam.com"):
        # We allow either explicit env or the default fallback host.
        pass
    s, b = http_post(
        f"http://localhost:{ctx['port']}/ai/api/chat",
        {"model": "qwen2.5-coder:14b",
         "messages": [{"role": "user", "content": "say hi in two words"}],
         "stream": False},
        timeout=20,
    )
    assert s == 200, f"/ai/api/chat {s}: {b[:200]}"
    body_str = b.decode("utf-8", errors="replace")
    # Compact: no leading whitespace and only one newline at most.
    assert "\n  " not in body_str[:200], \
        "response is pretty-printed (multi-line) — SPA chat reader will fail"


@check("dev toolbar injects on 404 (regression: blank 404)")
def check_toolbar_on_404(ctx):
    s, b = http_get(f"http://localhost:{ctx['port']}/this-route-does-not-exist")
    assert s == 404, f"missing-route status was {s}, expected 404"
    body = b.decode("utf-8", errors="replace")
    # The toolbar mark is the dev-admin-toolbar div id or class.
    has_toolbar = ("tina4-dev-toolbar" in body
                   or "data-tina4-toolbar" in body
                   or "/__dev" in body)
    assert has_toolbar, "404 page has no dev-toolbar injection"


# ── Live API RAG (per plan/v3/22-LIVE-API-RAG.md) ──────────────


@check("Live Docs — .well-known.json describes the surface")
def check_live_docs_well_known(ctx):
    s, b = http_get(f"http://localhost:{ctx['port']}/__dev/api/docs/.well-known.json")
    assert s == 200, f"/docs/.well-known.json returned {s}"
    data = json.loads(b)
    assert data.get("service") == "tina4-live-docs", \
        f"service field wrong: {data.get('service')!r}"
    assert "endpoints" in data and "search" in data["endpoints"], \
        "endpoints.search missing from well-known"


@check("Live Docs — search returns ≥1 framework hit for 'render'")
def check_live_docs_search(ctx):
    s, b = http_get(f"http://localhost:{ctx['port']}/__dev/api/docs/search?q=render&k=5")
    assert s == 200, f"/docs/search returned {s}"
    data = json.loads(b)
    assert data.get("ok") is True, f"unexpected envelope: {data}"
    results = data.get("results", [])
    assert len(results) >= 1, "expected ≥1 hit for 'render'"
    fw_hits = [r for r in results if r.get("source") == "framework"]
    assert fw_hits, f"no framework-source hits in {[r.get('fqn') for r in results]}"


@check("Live Docs — class endpoint returns ≥5 methods")
def check_live_docs_class(ctx):
    # Pick a framework class that exists in every framework: Response.
    # FQN shape differs (Tina4\Response vs tina4_python.core.response.Response)
    # so we try a couple. urllib doesn't quote backslash by default; fine.
    candidates = [
        "Tina4%5CResponse",                                 # PHP
        "tina4_python.core.response.Response",              # Python
        "Tina4::Response",                                  # Ruby
        "Response",                                         # Node (or short)
    ]
    last_status = None
    for name in candidates:
        s, b = http_get(f"http://localhost:{ctx['port']}/__dev/api/docs/class?name={name}")
        last_status = s
        if s == 200:
            data = json.loads(b)
            assert data.get("ok") is True
            cls = data.get("class", {})
            methods = cls.get("methods", [])
            assert len(methods) >= 5, \
                f"{name} has only {len(methods)} methods (expected ≥5)"
            return
    raise AssertionError(
        f"no Response-like class found (tried {len(candidates)} FQN forms; last status {last_status})",
    )


@check("Live Docs — method endpoint returns non-empty signature")
def check_live_docs_method(ctx):
    candidates = [
        ("Tina4%5CResponse", "render"),
        ("tina4_python.core.response.Response", "render"),
        ("Tina4::Response", "render"),
    ]
    last_status = None
    for cls_name, method_name in candidates:
        s, b = http_get(
            f"http://localhost:{ctx['port']}/__dev/api/docs/method"
            f"?class={cls_name}&name={method_name}"
        )
        last_status = s
        if s == 200:
            data = json.loads(b)
            assert data.get("ok") is True
            m = data.get("method", {})
            assert m.get("name") == method_name
            assert m.get("signature"), "signature must be non-empty"
            return
    raise AssertionError(
        f"no Response.render method found (tried {len(candidates)} FQN forms; last status {last_status})",
    )


@check(".tina4/mcp.json auto-discovery file exists and is well-formed")
def check_mcp_discovery_file(ctx):
    project_root = ctx.get("project_root")
    if not project_root:
        # Best-effort discovery: cwd of the running server is what
        # writes the file. We don't always know it from outside, so
        # this check is a soft pass when the path can't be resolved.
        print("      → project_root not provided; skipping disk check")
        return
    mcp_path = os.path.join(project_root, ".tina4", "mcp.json")
    assert os.path.isfile(mcp_path), f"mcp.json not at {mcp_path}"
    with open(mcp_path) as f:
        data = json.load(f)
    servers = data.get("mcpServers", {})
    assert "tina4-live-docs" in servers, "tina4-live-docs entry missing"
    url = servers["tina4-live-docs"].get("url", "")
    assert url.startswith("http://"), f"url malformed: {url!r}"
    assert ":" in url.split("://", 1)[1], f"url has no port: {url!r}"
    assert url.endswith("/__dev/api/mcp"), f"url path wrong: {url!r}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, required=True,
                    help="framework port (php=7145, python=7146, ruby=7147, node=7148)")
    ap.add_argument("--framework", default="auto",
                    help="expected framework name (php/python/ruby/nodejs/auto)")
    ap.add_argument("--project-root", default=None,
                    help="project root on disk (so checks like the .tina4/mcp.json "
                         "discovery file can verify on-disk state). Optional — "
                         "the on-disk check is skipped when omitted.")
    args = ap.parse_args()

    ctx = {"port": args.port, "framework": args.framework,
           "project_root": args.project_root}

    print(f"\nSmoke test against http://localhost:{args.port} "
          f"(expecting framework={args.framework})\n")

    failures = []
    for name, fn in CHECKS:
        print(f"  [...] {name}")
        try:
            fn(ctx)
            print(f"  [OK ] {name}")
        except AssertionError as e:
            print(f"  [FAIL] {name}: {e}")
            failures.append((name, str(e)))
        except Exception as e:
            print(f"  [ERR ] {name}: {type(e).__name__}: {e}")
            failures.append((name, f"{type(e).__name__}: {e}"))
        print()

    print("=" * 60)
    if failures:
        print(f"\n{len(failures)} failure(s) — DO NOT RELEASE\n")
        for name, err in failures:
            print(f"  ✗ {name}")
            print(f"    {err}")
        sys.exit(1)
    print(f"\nAll {len(CHECKS)} checks passed. Ship-ready.\n")
    sys.exit(0)


if __name__ == "__main__":
    main()
