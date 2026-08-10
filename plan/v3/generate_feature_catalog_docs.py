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
        (3, 15, "Database and providers"),
        (16, 27, "ORM and data layer"),
        (28, 32, "HTTP core"),
        (33, 36, "HTTP policies"),
        (37, 46, "HTTP runtime"),
        (47, 59, "Frond template engine"),
        (60, 62, "Frontend assets"),
        (63, 63, "Authentication"),
        (64, 70, "Sessions and providers"),
        (71, 79, "Cache and providers"),
        (80, 102, "Integrations and storage"),
        (103, 108, "Application runtime"),
        (109, 124, "CLI"),
        (125, 129, "Developer runtime"),
        (130, 132, "Testing and verification tools"),
    ]
    for start, end, label in ranges:
        if start <= number <= end:
            return label
    raise ValueError(f"feature {number} has no display phase")


def module_owner(relative: str) -> tuple[str, str]:
    if relative.startswith("gallery/"):
        return "—", "example application; not a framework capability"
    if relative.startswith("realtime/models/"):
        return "97", "realtime persistence models"
    exact = {
        "__init__.py": ("30, 63, 82, 88, 108, 129", "exports, lazy loading and version"),
        "HtmlElement.py": ("106", "HTML builder"),
        "Testing.py": ("131", "inline testing"),
        "docs.py": ("102", "live API index"),
        "env.py": ("1, 116", "typed environment and CLI environment support"),
        "core/cache.py": ("24, 71", "ORM/general cache bridge"),
        "core/constants.py": ("29", "HTTP response constants"),
        "core/events.py": ("103", "event system"),
        "core/middleware.py": ("32-36", "middleware and HTTP policies"),
        "core/rate_limiter.py": ("34", "rate-limit engine"),
        "core/request.py": ("28, 42, 43", "request, IDs and uploads"),
        "core/response.py": ("29, 39", "response, compression and ETag"),
        "core/router.py": ("30, 31", "routing and groups"),
        "core/server.py": ("30, 37-46, 110, 127-128", "front controller and runtime"),
        "database/adapter.py": ("3", "adapter interface"),
        "database/connection.py": ("3", "connection lifecycle"),
        "database/database_url.py": ("4", "database URL"),
        "database/sql_translator.py": ("6, 13", "query and MongoDB SQL translation"),
        "database/sqlite.py": ("7", "SQLite provider"),
        "database/postgres.py": ("8", "PostgreSQL provider"),
        "database/mysql.py": ("9", "MySQL provider"),
        "database/mssql.py": ("10", "MSSQL provider"),
        "database/firebird.py": ("11", "Firebird provider"),
        "database/odbc.py": ("12", "ODBC provider"),
        "database/mongodb.py": ("13", "MongoDB SQL provider"),
        "query_builder/__init__.py": ("6", "query builder"),
        "queue/lite_backend.py": ("89", "lite queue provider"),
        "queue/rabbitmq_backend.py": ("90", "RabbitMQ queue provider"),
        "queue/kafka_backend.py": ("91", "Kafka queue provider"),
        "queue/mongo_backend.py": ("92", "MongoDB queue provider"),
        "queue_backends/rabbitmq_backend.py": ("90", "RabbitMQ wire connector"),
        "queue_backends/kafka_backend.py": ("91", "Kafka wire connector"),
        "queue_backends/mongo_backend.py": ("92", "MongoDB wire connector"),
        "session_handlers/redis_handler.py": ("66", "Redis session provider"),
        "session_handlers/valkey_handler.py": ("67", "Valkey session provider"),
        "session_handlers/mongodb_handler.py": ("68", "MongoDB session provider"),
        "session_handlers/memcached_handler.py": ("70", "memcached session provider"),
        "websocket/backplane.py": ("83, 84", "WebSocket backplanes"),
    }
    if relative in exact:
        return exact[relative]
    prefixes = [
        ("ai/", "107", "AI coding-tool setup"),
        ("api/", "80", "HTTP API client"),
        ("auth/", "63", "authentication"),
        ("cache/", "71-79", "cache providers and response cache"),
        ("cli/", "109-124", "CLI"),
        ("container/", "104", "dependency injection"),
        ("context/", "101", "local context index"),
        ("core/", "28-46, 103", "HTTP/application core"),
        ("crud/", "26", "automatic CRUD"),
        ("database/", "3-15", "database package"),
        ("debug/", "2, 125", "logging and overlay"),
        ("dev_admin/", "120, 126", "metrics and dev admin"),
        ("docstore/", "94-96", "document store"),
        ("dotenv/", "1", "DotEnv"),
        ("frond/", "47-59", "Frond"),
        ("graphql/", "81", "GraphQL"),
        ("i18n/", "86", "localization"),
        ("mcp/", "100", "MCP"),
        ("messenger/", "87", "messenger"),
        ("migration/", "14, 111", "migrations"),
        ("mqtt/", "93", "MQTT"),
        ("orm/", "16-25", "ORM"),
        ("queue/", "88-92, 117", "queue"),
        ("queue_backends/", "90-92", "queue connectors"),
        ("realtime/", "97-99", "realtime collaboration"),
        ("seeder/", "27, 112", "seeding"),
        ("service/", "105", "service runner"),
        ("session/", "64-70", "sessions"),
        ("session_handlers/", "66-70", "session providers"),
        ("swagger/", "44", "Swagger/OpenAPI"),
        ("test/", "113, 131", "testing API"),
        ("test_client/", "130", "test client"),
        ("validator/", "18", "validation"),
        ("websocket/", "82-84", "WebSocket"),
        ("wsdl/", "85", "WSDL/SOAP"),
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
