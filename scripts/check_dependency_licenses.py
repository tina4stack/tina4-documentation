#!/usr/bin/env python3
# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Fail closed when the reviewed docs dependency inputs or evidence change."""
import hashlib
import json
import re
from pathlib import Path


def check(root):
    policy = json.loads((root / "scripts/dependency-licenses.json").read_text())
    if policy.get("schema") != 1 or set(policy["inputs"]) != {"package.json", "pnpm-lock.yaml"}:
        raise ValueError("Invalid licence review inputs")
    for name, digest in policy["inputs"].items():
        if hashlib.sha256((root / name).read_bytes()).hexdigest() != digest:
            raise ValueError("Dependency licence review required: " + name)
    components = policy["components"]
    keys = {(item["name"], item["version"]) for item in components}
    if len(keys) != len(components) or not keys:
        raise ValueError("Missing or duplicate reviewed components")
    lock = (root / "pnpm-lock.yaml").read_text()
    package_section = lock.split("\npackages:\n", 1)[1].split("\nsnapshots:\n", 1)[0]
    resolved = set(re.findall(r"^  ([^ @]+)@([^ :]+):$", package_section, re.MULTILINE))
    if resolved != keys:
        raise ValueError("Resolved lock components differ from reviewed inventory")
    for item in components:
        if f"  {item['name']}@{item['version']}:" not in lock:
            raise ValueError("Stale reviewed component: " + item["name"])
        if item.get("upstream_declaration", "") in ("", "UNKNOWN", "NOASSERTION", "NONE") or not item.get("evidence", "").startswith("https://registry.npmjs.org/"):
            raise ValueError("Missing upstream licence evidence: " + item["name"])
    print(f"Licence policy: {len(components)} reviewed docs build dependencies; source and lock hashes match")


if __name__ == "__main__":
    check(Path(__file__).resolve().parents[1])
