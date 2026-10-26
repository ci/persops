import json
import os
from pathlib import Path
import pty
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MOCK = r'''#!@PYTHON@
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys

root = Path(os.environ["AWDL_TEST_ROOT"])
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with (root / "calls").open("a") as log:
    log.write(json.dumps([name, *args]) + "\n")

if name == "ifconfig":
    assert args[0] == "awdl0"
    if len(args) == 1:
        if os.environ.get("AWDL_MISSING"):
            sys.exit(1)
        up = "UP," if (root / "state").read_text() == "on" else ""
        print(f"awdl0: flags=8863<{up}BROADCAST,RUNNING,MULTICAST> mtu 1500")
    else:
        assert args[1] in ("up", "down")
        counter = root / "attempts"
        count = int(counter.read_text()) + 1 if counter.exists() else 1
        counter.write_text(str(count))
        if count <= int(os.environ.get("AWDL_FAIL_ATTEMPTS", "0")):
            sys.exit(1)
        if not os.environ.get("AWDL_IGNORE_CHANGE"):
            (root / "state").write_text("on" if args[1] == "up" else "off")
elif name == "id":
    assert args == ["-u"]
    print(os.environ.get("AWDL_UID", "501"))
elif name == "sudo":
    sys.exit(subprocess.run(args).returncode)
elif name == "osascript":
    assert args[0] == "-e"
    match = re.fullmatch(r'do shell script "([^"]+)" with administrator privileges', args[1])
    assert match, args
    command = shlex.split(match[1])
    assert command[0] == str(root / "bin" / "ifconfig")
    assert command[1:] in (["awdl0", "up"], ["awdl0", "down"])
    sys.exit(subprocess.run(command).returncode)
elif name == "sleep":
    pass
else:
    raise AssertionError(name)
'''


class AwdlTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.state = self.root / "state"
        self.state.write_text("on")
        self.env = {**os.environ, "AWDL_TEST_ROOT": str(self.root)}
        self.scripts = {}
        commands = ["/sbin/ifconfig", "/usr/bin/id", "/usr/bin/sudo", "/usr/bin/osascript", "/bin/sleep"]
        for command in commands:
            mock = self.bin / Path(command).name
            mock.write_text(MOCK.replace("@PYTHON@", sys.executable))
            mock.chmod(0o755)
        for name in ("toggle", "default-off"):
            source = (ROOT / "modules" / "awdl" / f"{name}.sh").read_text()
            if name == "default-off":
                source = source.replace("/sbin/ifconfig", "boot_ifconfig").replace("/bin/sleep", ":")
                source = r'''
boot_attempt=0
boot_ifconfig() {
    boot_attempt=$((boot_attempt + 1))
    printf '%s' "$boot_attempt" > "$AWDL_TEST_ROOT/attempts"
    printf '["ifconfig","awdl0","down"]\n' >> "$AWDL_TEST_ROOT/calls"
    if [ "$boot_attempt" -le "${AWDL_FAIL_ATTEMPTS:-0}" ]; then return 1; fi
    printf off > "$AWDL_TEST_ROOT/state"
}
''' + source
            else:
                for command in commands:
                    source = source.replace(command, shlex.quote(str(self.bin / Path(command).name)))
                awk = shutil.which("awk")
                self.assertIsNotNone(awk, "AWDL tests require awk on PATH")
                source = source.replace("/usr/bin/awk", shlex.quote(awk))
            script = self.root / f"{name}.sh"
            script.write_text(source)
            self.scripts[name] = script

    def run_script(self, *args, script="toggle", tty=False, **env):
        master, slave = pty.openpty() if tty else (None, None)
        try:
            return subprocess.run(
                ["bash", str(self.scripts[script]), *args],
                stdin=slave if tty else subprocess.DEVNULL,
                capture_output=True,
                text=True,
                env={**self.env, **env},
                timeout=15,
            )
        finally:
            if tty:
                os.close(master)
                os.close(slave)

    def calls(self, name):
        path = self.root / "calls"
        return [call for line in path.read_text().splitlines() if (call := json.loads(line))[0] == name]

    def test_status_default_and_off_flags(self):
        self.assertEqual(self.run_script().stdout.strip(), "AWDL is on")
        self.state.write_text("off")
        self.assertEqual(self.run_script("status").stdout.strip(), "AWDL is off")
        self.assertEqual(self.calls("id"), [])

    def test_invalid_arguments_do_not_touch_interface(self):
        for args in (("bad",), ("off", "extra"), ("status", "extra")):
            self.assertEqual(self.run_script(*args).returncode, 2)
        self.assertFalse((self.root / "calls").exists())

    def test_already_on_is_unprivileged(self):
        self.assertEqual(self.run_script("on").returncode, 0)
        self.assertEqual(self.calls("id"), [])

    def test_root_changes_and_toggle(self):
        for expected in ("off", "on"):
            result = self.run_script("toggle", AWDL_UID="0")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.state.read_text(), expected)
        self.assertEqual(self.calls("sudo"), [])
        self.assertEqual(self.calls("osascript"), [])

    def test_nonterminal_uses_native_authorization(self):
        result = self.run_script("off")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state.read_text(), "off")
        self.assertEqual(len(self.calls("osascript")), 1)
        self.assertEqual(self.calls("sudo"), [])

    def test_terminal_uses_sudo(self):
        result = self.run_script("off", tty=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state.read_text(), "off")
        self.assertEqual(len(self.calls("sudo")), 1)

    def test_failed_change_is_reported(self):
        result = self.run_script("off", AWDL_UID="0", AWDL_FAIL_ATTEMPTS="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.state.read_text(), "on")

    def test_reactivated_interface_is_reported(self):
        result = self.run_script("off", AWDL_UID="0", AWDL_IGNORE_CHANGE="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("did not leave AWDL off", result.stderr)

    def test_missing_interface_fails_instead_of_empty_status(self):
        result = self.run_script("status", AWDL_MISSING="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_boot_default_is_one_shot_when_ready(self):
        self.assertEqual(self.run_script(script="default-off").returncode, 0)
        self.assertEqual(self.state.read_text(), "off")
        self.assertEqual((self.root / "attempts").read_text(), "1")
        self.assertEqual(self.calls("sleep"), [])

    def test_boot_waits_for_interface_then_stops(self):
        result = self.run_script(script="default-off", AWDL_FAIL_ATTEMPTS="2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state.read_text(), "off")
        self.assertEqual((self.root / "attempts").read_text(), "3")

    def test_boot_failure_is_bounded(self):
        result = self.run_script(script="default-off", AWDL_FAIL_ATTEMPTS="120")
        self.assertEqual(result.returncode, 1)
        self.assertEqual((self.root / "attempts").read_text(), "120")


if __name__ == "__main__":
    unittest.main()
