"""Exercise automation PR policy and CI dispatch without GitHub writes."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("open_automation_pr.sh")
FAKE_GH = '''#!/usr/bin/env python3
import json, os, sys
with open(os.environ["CALL_LOG"], "a") as f:
    f.write(json.dumps([sys.argv[1:], os.environ.get("GH_TOKEN")]) + "\\n")
command = sys.argv[1:3]
if command == ["pr", "list"]:
    if os.environ.get("MODE") == "list_failure":
        sys.exit(1)
    print("https://github.com/Luen/Paluma-Trails/pull/123" if os.environ.get("MODE") == "existing" else "")
elif command == ["pr", "create"]:
    mode = os.environ.get("MODE")
    if mode in ("policy", "auth"):
        print("GitHub Actions is not permitted to create or approve pull requests" if mode == "policy" else "Bad credentials", file=sys.stderr)
        sys.exit(1)
    print("https://github.com/Luen/Paluma-Trails/pull/124")
elif command == ["workflow", "run"]:
    sys.exit(1 if os.environ.get("MODE") == "dispatch_failure" else 0)
else:
    sys.exit(2)
'''


class AutomationPrTest(unittest.TestCase):
    def run_helper(self, mode, base="main", head="chore/nightly-minor-deps"):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            gh = root / "gh"
            gh.write_text(FAKE_GH)
            gh.chmod(0o755)
            env = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}",
                       GITHUB_REPOSITORY="Luen/Paluma-Trails", GH_REPO="Luen/Paluma-Trails",
                       GH_TOKEN="pr-token", GH_WORKFLOW_TOKEN="workflow-token",
                       GITHUB_STEP_SUMMARY=str(root / "summary"),
                       CALL_LOG=str(root / "calls"), MODE=mode)
            result = subprocess.run(["bash", str(SCRIPT), base, head, "fix(deps): update", "Review dependencies"],
                                    env=env, text=True, capture_output=True)
            calls = [json.loads(line) for line in (root / "calls").read_text().splitlines()]
            summary = (root / "summary").read_text() if (root / "summary").exists() else ""
            return result, calls, summary

    def test_creates_pr_and_dispatches_ci_with_workflow_token(self):
        result, calls, summary = self.run_helper("new")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls[1][0][:2], ["pr", "create"])
        self.assertIn("/pull/124", summary)
        self.assertEqual(calls[-1], [["workflow", "run", "ci.yml", "--repo", "Luen/Paluma-Trails", "--ref", "chore/nightly-minor-deps"], "workflow-token"])
        self.assertEqual(calls[1][1], "pr-token")

    def test_reuses_existing_sync_pr(self):
        result, calls, summary = self.run_helper("existing", "dev", "main")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[-1][0][-1], "main")
        self.assertIn("/pull/123", summary)

    def test_policy_denial_hands_off_and_still_starts_ci(self):
        result, calls, summary = self.run_helper("policy")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("compare/main...chore/nightly-minor-deps?expand=1", summary)
        self.assertEqual(calls[-1][0][:2], ["workflow", "run"])

    def test_auth_failure_is_not_hidden(self):
        result, calls, _ = self.run_helper("auth")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Bad credentials", result.stderr)
        self.assertEqual(len(calls), 2)

    def test_list_failure_does_not_create_a_duplicate(self):
        result, calls, _ = self.run_helper("list_failure")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)

    def test_dispatch_failure_is_not_hidden(self):
        result, _, _ = self.run_helper("dispatch_failure")
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
