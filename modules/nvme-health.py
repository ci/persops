"""Record NVMe SMART health and fail when it worsened since the previous run."""

import json
from pathlib import Path
import subprocess
import sys
import time

FIELDS = [
    "critical_warning",
    "available_spare",
    "available_spare_threshold",
    "percentage_used",
    "media_errors",
    "num_err_log_entries",
    "unsafe_shutdowns",
    "power_on_hours",
    "data_units_written",
    "temperature",
]


def read(device):
    # smartctl's exit status is a bitmask that also flags old, harmless log
    # entries; judge the parsed health log instead.
    result = subprocess.run(
        ["smartctl", "--json", "--all", device],
        capture_output=True, text=True, timeout=60,
    )
    data = json.loads(result.stdout)
    log = data["nvme_smart_health_information_log"]
    sample = {key: log[key] for key in FIELDS}
    sample["firmware"] = data.get("firmware_version")
    return sample


def regressions(previous, current):
    problems = []
    if current["critical_warning"]:
        problems.append(f"critical warning 0x{current['critical_warning']:02x}")
    if current["available_spare"] <= current["available_spare_threshold"]:
        problems.append(f"spare {current['available_spare']}% at or below threshold")
    if previous:
        if current["available_spare"] < previous["available_spare"]:
            problems.append(f"spare {previous['available_spare']}% -> {current['available_spare']}%")
        if current["media_errors"] > previous["media_errors"]:
            problems.append(f"media errors {previous['media_errors']} -> {current['media_errors']}")
    return problems


def main(device, state_dir):
    state_dir = Path(state_dir)
    last_path = state_dir / "last.json"
    previous = json.loads(last_path.read_text()) if last_path.exists() else None
    current = read(device)
    current["time"] = int(time.time())
    with open(state_dir / "history.jsonl", "a") as history:
        history.write(json.dumps(current, sort_keys=True) + "\n")
    last_path.write_text(json.dumps(current, sort_keys=True))
    problems = regressions(previous, current)
    print(f"{device}: spare {current['available_spare']}%, media errors {current['media_errors']}, "
          f"used {current['percentage_used']}%, firmware {current['firmware']}")
    if problems:
        print(f"{device} health worsened: " + "; ".join(problems), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
