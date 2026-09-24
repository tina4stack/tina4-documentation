#!/usr/bin/env python3
"""Apply or verify the GitHub repository controls behind the ISO alignment plan.

    python3 scripts/governance/github_controls.py --check    # read-only report
    python3 scripts/governance/github_controls.py --apply    # needs repo admin

Reads scripts/governance/github-controls.json and, for each repository, manages:

  G1  ruleset "tina4-release-line"      - default branch: PR required, required
                                          CI checks, no force-push, no deletion
  G1  ruleset "tina4-maintenance-lines" - other long-lived branches: PR required,
                                          no force-push, no deletion
  G2  ruleset "tina4-release-tags"      - release tags cannot be moved or deleted
  G3  private vulnerability reporting   - on
  G4  secret scanning + push protection - on
  G5  Dependabot vulnerability alerts   - on

--apply is idempotent: a ruleset that already exists (matched by name) is
updated in place. Everything goes through the `gh` CLI, so run it while `gh`
is logged in as the repository admin (`gh auth switch` to that account).
Standard library only.
"""

import argparse
import json
import pathlib
import subprocess
import sys

CONFIG = pathlib.Path(__file__).with_name("github-controls.json")

# Repository role id 5 is "admin". Branch rules: the admin can only get past
# them through a pull request (bypass_mode "pull_request"), so even an
# emergency change leaves a PR behind. Tag rules: the admin may bypass, to
# repair a botched tag.
ADMIN = 5


def gh(*args, body=None, allow_fail=False):
    cmd = ["gh", "api", *args]
    if body is not None:
        cmd += ["--input", "-"]
    proc = subprocess.run(cmd, input=json.dumps(body) if body is not None else None,
                          capture_output=True, text=True)
    if proc.returncode != 0:
        if allow_fail:
            return None
        sys.exit(f"gh api {' '.join(args)} failed:\n{proc.stdout}{proc.stderr}")
    return json.loads(proc.stdout) if proc.stdout.strip() else {}


def pull_request_rule():
    return {"type": "pull_request", "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": True,
        "require_code_owner_review": False,
        "require_last_push_approval": False,
        "required_review_thread_resolution": True,
    }}


def rulesets_for(spec):
    release = {
        "name": "tina4-release-line",
        "target": "branch",
        "enforcement": "active",
        "bypass_actors": [{"actor_id": ADMIN, "actor_type": "RepositoryRole", "bypass_mode": "pull_request"}],
        "conditions": {"ref_name": {"include": [f"refs/heads/{spec['release_line']}"], "exclude": []}},
        "rules": [
            {"type": "deletion"},
            {"type": "non_fast_forward"},
            pull_request_rule(),
            {"type": "required_status_checks", "parameters": {
                "strict_required_status_checks_policy": False,
                "required_status_checks": [{"context": c} for c in spec["required_checks"]],
            }},
        ],
    }
    sets = [release]
    if spec.get("maintenance_lines"):
        sets.append({
            "name": "tina4-maintenance-lines",
            "target": "branch",
            "enforcement": "active",
            "bypass_actors": [{"actor_id": ADMIN, "actor_type": "RepositoryRole", "bypass_mode": "pull_request"}],
            "conditions": {"ref_name": {"include": [f"refs/heads/{b}" for b in spec["maintenance_lines"]], "exclude": []}},
            "rules": [{"type": "deletion"}, {"type": "non_fast_forward"}, pull_request_rule()],
        })
    sets.append({
        "name": "tina4-release-tags",
        "target": "tag",
        "enforcement": "active",
        "bypass_actors": [{"actor_id": ADMIN, "actor_type": "RepositoryRole", "bypass_mode": "always"}],
        "conditions": {"ref_name": {"include": ["~ALL"], "exclude": []}},
        "rules": [{"type": "deletion"}, {"type": "update"}],
    })
    return sets


def check(owner, repo, spec):
    base = f"repos/{owner}/{repo}"
    existing = {r["name"]: r for r in gh(f"{base}/rulesets") or []}
    rows = []
    for rs in rulesets_for(spec):
        have = existing.get(rs["name"])
        ok = bool(have) and have.get("enforcement") == "active"
        rows.append((f"ruleset {rs['name']}", ok))
    pvr = gh(f"{base}/private-vulnerability-reporting", allow_fail=True) or {}
    rows.append(("private vulnerability reporting", bool(pvr.get("enabled"))))
    sa = (gh(base) or {}).get("security_and_analysis") or {}
    rows.append(("secret scanning", (sa.get("secret_scanning") or {}).get("status") == "enabled"))
    rows.append(("secret scanning push protection",
                 (sa.get("secret_scanning_push_protection") or {}).get("status") == "enabled"))
    # 204 = enabled, 404 = disabled; needs admin to read, so unknown otherwise.
    alerts = subprocess.run(["gh", "api", f"{base}/vulnerability-alerts", "--silent"],
                            capture_output=True, text=True)
    rows.append(("Dependabot alerts", alerts.returncode == 0))
    return rows


def apply(owner, repo, spec):
    base = f"repos/{owner}/{repo}"
    existing = {r["name"]: r for r in gh(f"{base}/rulesets") or []}
    for rs in rulesets_for(spec):
        if rs["name"] in existing:
            gh("-X", "PUT", f"{base}/rulesets/{existing[rs['name']]['id']}", body=rs)
            print(f"  updated ruleset {rs['name']}")
        else:
            gh("-X", "POST", f"{base}/rulesets", body=rs)
            print(f"  created ruleset {rs['name']}")
    gh("-X", "PUT", f"{base}/private-vulnerability-reporting")
    print("  private vulnerability reporting on")
    gh("-X", "PATCH", base, body={"security_and_analysis": {
        "secret_scanning": {"status": "enabled"},
        "secret_scanning_push_protection": {"status": "enabled"},
    }})
    print("  secret scanning + push protection on")
    gh("-X", "PUT", f"{base}/vulnerability-alerts")
    print("  Dependabot alerts on")
    if spec.get("actions_can_open_prs"):
        current = gh(f"{base}/actions/permissions/workflow")
        gh("-X", "PUT", f"{base}/actions/permissions/workflow", body={
            "default_workflow_permissions": current.get("default_workflow_permissions", "read"),
            "can_approve_pull_request_reviews": True,
        })
        print("  GitHub Actions may open pull requests")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="report the current state (read-only)")
    mode.add_argument("--apply", action="store_true", help="create or update every control (admin)")
    ap.add_argument("--repo", action="append", help="limit to these repositories")
    args = ap.parse_args()

    cfg = json.loads(CONFIG.read_text())
    owner = cfg["owner"]
    repos = {k: v for k, v in cfg["repos"].items() if not args.repo or k in args.repo}

    if args.apply:
        me = gh("user")["login"]
        for repo, spec in repos.items():
            perms = gh(f"repos/{owner}/{repo}").get("permissions", {})
            if not perms.get("admin"):
                sys.exit(f"{me} is not an admin of {owner}/{repo}; run `gh auth switch` to the admin account first.")
        for repo, spec in repos.items():
            print(f"{owner}/{repo}")
            apply(owner, repo, spec)
        print()

    failed = 0
    for repo, spec in repos.items():
        print(f"{owner}/{repo}")
        for label, ok in check(owner, repo, spec):
            failed += not ok
            print(f"  [{'x' if ok else ' '}] {label}")
    print(f"\n{'all controls in place' if not failed else f'{failed} control(s) missing'}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
