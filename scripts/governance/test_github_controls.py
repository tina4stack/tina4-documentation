#!/usr/bin/env python3
# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Pure interpretation checks based on observed GitHub permission responses."""
import unittest
from github_controls import setting_state, alerts_state


class ControlVisibilityTest(unittest.TestCase):
    def test_observed_nonadmin_metadata_is_unknown(self):
        # Observed repo response omits security_and_analysis for the maintainer.
        metadata = {"permissions": {"admin": False, "push": True}}
        self.assertIsNone(setting_state(metadata.get("security_and_analysis"),
                                       "secret_scanning", "status", enabled="enabled"))
        # The observed default-setup 403 is represented by gh(allow_fail=True).
        self.assertIsNone(setting_state(None, "state", enabled="configured"))

    def test_explicit_enabled_and_disabled_are_distinguished(self):
        for value, expected in (("enabled", True), ("disabled", False)):
            self.assertIs(setting_state({"secret_scanning": {"status": value}},
                                        "secret_scanning", "status", enabled="enabled"), expected)
        self.assertIs(setting_state({"enabled": False}, "enabled", enabled=True), False)
        self.assertIs(setting_state({"state": "configured"}, "state", enabled="configured"), True)
        self.assertIs(setting_state({"state": "not-configured"}, "state", enabled="configured"), False)

    def test_alerts_204_success_and_ambiguous_http_failure(self):
        self.assertIs(alerts_state(0), True)
        # A 404 can hide enabled alerts; even admin role alone cannot prove token scope.
        self.assertIsNone(alerts_state(1))


if __name__ == "__main__":
    unittest.main()
