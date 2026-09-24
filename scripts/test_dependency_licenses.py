#!/usr/bin/env python3
# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

import json
from pathlib import Path
import shutil
import tempfile
import unittest
from check_dependency_licenses import check


class LicenceReviewTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        source = Path(__file__).resolve().parents[1]
        for name in ("package.json", "pnpm-lock.yaml", "scripts/dependency-licenses.json"):
            shutil.copyfile(source / name, self.root / name)

    def test_reviewed_files_pass_and_changed_lock_fails(self):
        check(self.root)
        with (self.root / "pnpm-lock.yaml").open("a") as stream:
            stream.write("\n# unreviewed change\n")
        with self.assertRaisesRegex(ValueError, "review required"):
            check(self.root)

    def test_omitted_component_fails(self):
        path = self.root / "scripts/dependency-licenses.json"
        data = json.loads(path.read_text())
        data["components"].pop()
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "differ from reviewed"):
            check(self.root)

    def test_missing_evidence_fails(self):
        path = self.root / "scripts/dependency-licenses.json"
        data = json.loads(path.read_text())
        data["components"][0]["evidence"] = ""
        path.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "Missing upstream"):
            check(self.root)


if __name__ == "__main__":
    unittest.main()
