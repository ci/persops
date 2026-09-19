"""Exercise the report's shell functions with deterministic command responses."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / 'modules/ops-status.nix').read_text()
# Extract complete top-level functions without executing live host probes.
FUNCTIONS = '\n'.join(re.findall(r'^    \w+\(\) \{\n.*?^    \}', SOURCE, re.M | re.S))
FUNCTIONS = FUNCTIONS.replace('${pkgs.coreutils}/bin/timeout', 'timeout').replace("''${", '${')


class HealthReportTests(unittest.TestCase):
    def run_report(self, body):
        return subprocess.run(['bash', '-c', 'set -u\nstatus=0\n' + FUNCTIONS + '\n' + body + '\nexit "$status"'], text=True, capture_output=True)

    def test_aerospace_failure_and_protocol_mismatch_warn(self):
        for reply, code in [('client and server versions are incompatible', 0), ('connection refused', 1), ('server version: Unknown', 0)]:
            with self.subTest(reply=reply):
                result = self.run_report(f'aerospace() {{ echo "{reply}"; return {code}; }}\nshow_desktop')
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn('[warn]', result.stdout)

    def test_matching_aerospace_is_healthy(self):
        result = self.run_report('aerospace() { echo "AeroSpace.app server version: 0.21.3-Beta"; }\nshow_desktop')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('[ok]', result.stdout)

    def test_historical_stderr_does_not_override_success(self):
        with tempfile.NamedTemporaryFile(mode='w') as log:
            log.write('old network failure\n')
            log.flush()
            for code, expected in [(0, 0), (11, 2)]:
                result = self.run_report(f'''launchctl() {{ printf 'state = not running\\nlast exit code = {code}\\n'; }}
check_launch_agent backup org.nixos.restic-backup
show_stderr_tail stderr '{log.name}' ''')
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertIn('old network failure', result.stdout)

    def test_required_services_fail_and_never_run_job_warns(self):
        for body, expected in [
            ('launchctl() { return 1; }; check_launch_agent backup missing', 2),
            ('launchctl() { echo "state = running"; }; check_launch_agent backup new', 1),
            ('launchctl() { printf "state = not running\\nlast terminating signal = Killed: 9\\n"; }; check_launch_agent backup killed', 2),
            ('nix() { [ "$1" = --version ]; }; show_nix', 2),
            ('tailscale() { echo failed; return 1; }; show_network', 2),
            ('tailscale() { return 0; }; show_network', 2),
        ]:
            with self.subTest(body=body):
                result = self.run_report(body)
                self.assertEqual(result.returncode, expected, result.stderr)

    def test_time_machine_timeout_and_snapshot_header(self):
        result = self.run_report('''tmutil() { :; }
timed() {
  case "$3" in
    status) echo 'Running = 0';;
    latestbackup) [ "$1" = 30s ] || return 9; echo /Backups/latest;;
    listlocalsnapshots) printf 'Snapshots for disk /:\\ncom.apple.TimeMachine.2026-09-20-000000.local\\n';;
  esac
}
show_time_machine''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(result.stdout, r'local snapshots\s+1\n')


if __name__ == '__main__':
    unittest.main()
