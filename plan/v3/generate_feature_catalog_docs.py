#!/usr/bin/env python3
"""Generate the human catalog and Python module coverage map."""

from __future__ import annotations

import json
import re
from itertools import groupby
from pathlib import Path


ROOT = Path(__file__).resolve().parent
CATALOG = ROOT / "FEATURE-CATALOG.json"
FEATURES = ROOT / "features"
PYTHON_PACKAGE = ROOT.parents[2] / "tina4-python" / "tina4_python"

NON_FEATURE = [
    ("tina4_python/gallery/", "shipped examples; each example exercises catalog features"),
    ("tina4_python/realtime/models/", "data models owned by Feature 97"),
    ("tina4_python/queue_backends/ connector files", "private provider layers owned by Features 90-92"),
    ("compiled assets and translations", "artifacts owned by their source feature; not separate capabilities"),
    ("__pycache__, metadata and CLAUDE.md", "runtime/build residue or project guidance"),
]


def display_phase(number: int) -> str:
    ranges = [
        (1, 2, "Foundation"),
        (3, 16, "Database and providers"),
        (17, 28, "ORM and data layer"),
        (29, 33, "HTTP core"),
        (34, 37, "HTTP policies"),
        (38, 47, "HTTP runtime"),
        (48, 60, "Frond template engine"),
        (61, 63, "Frontend assets"),
        (64, 64, "Authentication"),
        (65, 71, "Sessions and providers"),
        (72, 80, "Cache and providers"),
        (81, 103, "Integrations and storage"),
        (104, 109, "Application runtime"),
        (110, 125, "CLI"),
        (126, 130, "Developer runtime"),
        (131, 133, "Testing and verification tools"),
    ]
    for start, end, label in ranges:
        if start <= number <= end:
            return label
    raise ValueError(f"feature {number} has no display phase")


def module_owner(relative: str) -> tuple[str, str]:
    if relative.startswith("gallery/"):
        return "—", "example application; not a framework capability"
    if relative.startswith("realtime/models/"):
        return "98", "realtime persistence models"
    exact = {
        "__init__.py": ("31, 64, 83, 89, 109, 130", "exports, lazy loading and version"),
        "HtmlElement.py": ("107", "HTML builder"),
        "Testing.py": ("132", "inline testing"),
        "docs.py": ("103", "live API index"),
        "env.py": ("1, 117", "typed environment and CLI environment support"),
        "core/cache.py": ("25, 72", "ORM/general cache bridge"),
        "core/constants.py": ("30", "HTTP response constants"),
        "core/events.py": ("104", "event system"),
        "core/middleware.py": ("33-37", "middleware and HTTP policies"),
        "core/rate_limiter.py": ("35", "rate-limit engine"),
        "core/request.py": ("29, 43, 44", "request, IDs and uploads"),
        "core/response.py": ("30, 40", "response, compression and ETag"),
        "core/router.py": ("31, 32", "routing and groups"),
        "core/server.py": ("31, 38-47, 111, 128-129", "front controller and runtime"),
        "database/adapter.py": ("3", "adapter interface"),
        "database/connection.py": ("3", "connection lifecycle"),
        "database/database_url.py": ("4", "database URL"),
        "database/sql_translator.py": ("7", "SQL dialect translation"),
        "database/sqlite.py": ("8", "SQLite provider"),
        "database/postgres.py": ("9", "PostgreSQL provider"),
        "database/mysql.py": ("10", "MySQL provider"),
        "database/mssql.py": ("11", "MSSQL provider"),
        "database/firebird.py": ("12", "Firebird provider"),
        "database/odbc.py": ("13", "ODBC provider"),
        "database/mongodb.py": ("14", "MongoDB SQL provider"),
        "query_builder/__init__.py": ("6", "query builder"),
        "queue/lite_backend.py": ("90", "lite queue provider"),
        "queue/rabbitmq_backend.py": ("91", "RabbitMQ queue provider"),
        "queue/kafka_backend.py": ("92", "Kafka queue provider"),
        "queue/mongo_backend.py": ("93", "MongoDB queue provider"),
        "queue_backends/rabbitmq_backend.py": ("91", "RabbitMQ wire connector"),
        "queue_backends/kafka_backend.py": ("92", "Kafka wire connector"),
        "queue_backends/mongo_backend.py": ("93", "MongoDB wire connector"),
        "session_handlers/redis_handler.py": ("67", "Redis session provider"),
        "session_handlers/valkey_handler.py": ("68", "Valkey session provider"),
        "session_handlers/mongodb_handler.py": ("69", "MongoDB session provider"),
        "session_handlers/memcached_handler.py": ("71", "memcached session provider"),
        "websocket/backplane.py": ("84, 85", "WebSocket backplanes"),
    }
    if relative in exact:
        return exact[relative]
    prefixes = [
        ("ai/", "108", "AI coding-tool setup"),
        ("api/", "81", "HTTP API client"),
        ("auth/", "64", "authentication"),
        ("cache/", "72-80", "cache providers and response cache"),
        ("cli/", "110-125", "CLI"),
        ("container/", "105", "dependency injection"),
        ("context/", "102", "local context index"),
        ("core/", "29-47, 104", "HTTP/application core"),
        ("crud/", "27", "automatic CRUD"),
        ("database/", "3-16", "database package"),
        ("debug/", "2, 126", "logging and overlay"),
        ("dev_admin/", "121, 127", "metrics and dev admin"),
        ("docstore/", "95-97", "document store"),
        ("dotenv/", "1", "DotEnv"),
        ("frond/", "48-60", "Frond"),
        ("graphql/", "82", "GraphQL"),
        ("i18n/", "87", "localization"),
        ("mcp/", "101", "MCP"),
        ("messenger/", "88", "messenger"),
        ("migration/", "15, 112", "migrations"),
        ("mqtt/", "94", "MQTT"),
        ("orm/", "17-26", "ORM"),
        ("queue/", "89-93, 118", "queue"),
        ("queue_backends/", "91-93", "queue connectors"),
        ("realtime/", "98-100", "realtime collaboration"),
        ("seeder/", "28, 113", "seeding"),
        ("service/", "106", "service runner"),
        ("session/", "65-71", "sessions"),
        ("session_handlers/", "67-71", "session providers"),
        ("swagger/", "45", "Swagger/OpenAPI"),
        ("test/", "114, 132", "testing API"),
        ("test_client/", "131", "test client"),
        ("validator/", "19", "validation"),
        ("websocket/", "83-85", "WebSocket"),
        ("wsdl/", "86", "WSDL/SOAP"),
    ]
    for prefix, ids, role in prefixes:
        if relative.startswith(prefix):
            return ids, role
    raise ValueError(f"unmapped Python module: {relative}")


def audit_state(packet: Path) -> str:
    text = packet.read_text(encoding="utf-8")
    match = re.search(r"^- Audit state:\s*(.+)$", text, flags=re.M)
    return match.group(1).strip() if match else "missing"


def main() -> None:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    features = data["features"]
    for feature in features:
        feature["phase"] = display_phase(feature["id"])
    CATALOG.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    matrix = [
        "# Tina4 3.14 flat feature matrix",
        "",
        "This catalog follows the code. Every public capability and every selectable",
        "provider has one whole-number identifier. Private helpers stay inside their",
        "owner. Verification suites prove features; they are not counted as product",
        "features.",
        "",
        "Numbers are contiguous and append-only from this baseline. The 3.14 reset",
        "retires the old grouped identifiers such as `4.2`, `42.6` and `48.4`.",
        "Historical documents remain in `archive/`; active packets use this table.",
        "",
        f"**Current catalog: {len(features)} flat features.**",
        "",
    ]
    for phase, rows_iter in groupby(features, key=lambda row: display_phase(row["id"])):
        rows = list(rows_iter)
        matrix.extend(
            [
                f"## {phase}",
                "",
                "| # | Feature | Python evidence | PHP | Ruby | Node | Audit state |",
                "| ---: | --- | --- | --- | --- | --- | --- |",
            ]
        )
        for row in rows:
            packet = ROOT / row["packet"]
            rel = packet.relative_to(ROOT).as_posix()
            matrix.append(
                f'| {row["id"]} | [{row["name"]}]({rel}) | '
                f'`{row["python_evidence"]}` | inventory pending | inventory pending | '
                f'inventory pending | {audit_state(packet)} |'
            )
        matrix.append("")
    (ROOT / "01-FEATURE-MATRIX.md").write_text("\n".join(matrix).rstrip() + "\n", encoding="utf-8")

    module_map = [
        "# Python module-to-feature map",
        "",
        "This table comes from the shipped `tina4_python` package. It proves that",
        "every Python module has an owning feature packet. A module may support more",
        "than one public capability; that does not turn each private source file into",
        "a feature.",
        "",
        "| Python module | Feature IDs | Ownership |",
        "| --- | --- | --- |",
    ]
    if not PYTHON_PACKAGE.is_dir():
        raise SystemExit(f"Python package not found: {PYTHON_PACKAGE}")
    modules = sorted(
        path.relative_to(PYTHON_PACKAGE).as_posix()
        for path in PYTHON_PACKAGE.rglob("*.py")
        if "__pycache__" not in path.parts
    )
    for relative in modules:
        ids, role = module_owner(relative)
        module_map.append(f"| `tina4_python/{relative}` | {ids} | {role} |")
    module_map.extend(
        [
            "",
            "## Deliberate non-features",
            "",
            "| Path or artifact | Reason |",
            "| --- | --- |",
        ]
    )
    module_map.extend(f"| `{path}` | {reason} |" for path, reason in NON_FEATURE)
    module_map.extend(
        [
            "",
            "## Numbering rule",
            "",
            "A capability gets its own number when an engineer can call it, configure",
            "it, select it, replace it or observe it independently. A provider therefore",
            "gets a whole number. A helper gets no number when removing it leaves the",
            "public contract unchanged.",
            "",
            "New capabilities append to the catalog. They never reuse a number and never",
            "insert a decimal child below an existing number.",
        ]
    )
    (ROOT / "PYTHON-MODULE-MAP.md").write_text(
        "\n".join(module_map).rstrip() + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
