"""Runs inside a throwaway Tina4 project. Not called directly.

tina4grade.py copies the student's route file into a scratch project, then
executes this with that project as the working directory. Requests go through
``tina4_python.test_client.TestClient``, which dispatches into the REAL front
controller: global middleware, the secure-by-default auth gate, error handling,
everything a live request meets. No mocks, no stubs, no socket.

Results come back on stdout as one JSON object.
"""
import importlib.util
import json
import os
import sys


def main() -> int:
    checks = json.loads(sys.argv[1])
    route_file = sys.argv[2]

    sys.path.insert(0, os.getcwd())
    results = []

    try:
        from tina4_python.test_client import TestClient
    except ImportError as e:
        print(json.dumps({
            "fatal": f"tina4-python is not importable: {e}. Run: pip install tina4-python"
        }))
        return 1

    # Importing the module runs its decorators, which is what registers routes.
    try:
        spec = importlib.util.spec_from_file_location("student_routes", route_file)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    except Exception as e:
        print(json.dumps({
            "fatal": f"Your route file could not be loaded: {type(e).__name__}: {e}"
        }))
        return 1

    client = TestClient()

    for check in checks:
        row = {"name": check["name"], "marks": check["marks"], "awarded": 0}
        try:
            method = check.get("method", "GET").lower()
            response = getattr(client, method)(check["path"])

            row["got_status"] = response.status
            failures = []

            if response.status != check["expect_status"]:
                failures.append(
                    f"expected status {check['expect_status']}, got {response.status}"
                )

            if "expect_json" in check:
                try:
                    body = response.json()
                except Exception:
                    body = None
                    failures.append(
                        f"expected JSON, got {response.content_type or 'no content type'}"
                    )

                if body is not None:
                    for key, want in check["expect_json"].items():
                        if key not in body:
                            failures.append(f"missing key '{key}'")
                        elif body[key] != want:
                            failures.append(
                                f"'{key}' should be {want!r}, got {body[key]!r}"
                            )

            if not failures:
                row["awarded"] = check["marks"]
            else:
                row["failures"] = failures

        except Exception as e:
            row["failures"] = [f"{type(e).__name__}: {e}"]

        results.append(row)

    print(json.dumps({"checks": results}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
