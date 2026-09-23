import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class PublicConfigurationTests(unittest.TestCase):
    def test_examples_contain_placeholders_not_deployment_values(self):
        env_example = (ROOT / ".env.example").read_text(encoding="utf-8")
        config = json.loads((ROOT / "windows" / "config.example.json").read_text(encoding="utf-8"))
        self.assertIn("rendezvous.example.com", env_example)
        self.assertEqual(config["url"], "https://rendezvous.example.com")
        self.assertEqual(config["token"], "REPLACE_WITH_SERVER_TOKEN")
        self.assertEqual(config["ssh_user"], "WINDOWS_USERNAME")

    def test_private_paths_are_ignored_and_examples_are_trackable(self):
        private_paths = [
            ".env", ".env.production", "server/private.env", "windows/config.local.json",
            ".local/README.md", "secrets/token", "token", "config.json", "arch-config",
            "id_ed25519", "backup.pem", "dutflow-sunshine.xml", "peers.json",
        ]
        ignored = subprocess.run(
            ["git", "check-ignore", "--no-index", *private_paths],
            cwd=ROOT, capture_output=True, text=True, check=False,
        )
        self.assertEqual(ignored.returncode, 0, ignored.stderr)
        self.assertEqual(set(ignored.stdout.splitlines()), set(private_paths))
        visible = subprocess.run(
            ["git", "check-ignore", "--no-index", ".env.example", "windows/config.example.json", "LICENSE"],
            cwd=ROOT, capture_output=True, text=True, check=False,
        )
        self.assertEqual(visible.returncode, 1, visible.stderr)
        self.assertEqual(visible.stdout, "")

    def test_tracked_files_do_not_include_private_config_names(self):
        tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
        tracked = [path for path in tracked if path]
        self.assertFalse(any(
            Path(path).name in {".env", "config.local.json", "config.json", "token"}
            or (Path(path).name.startswith(".env.") and Path(path).name != ".env.example")
            for path in tracked
        ))
        self.assertFalse(any(path.startswith(".local/") or path.startswith("secrets/") for path in tracked))


if __name__ == "__main__":
    unittest.main()