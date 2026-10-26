"""Observe scheduled jobs; publish durable freshness metrics and Kuma heartbeats."""

import json
import os
from pathlib import Path
import subprocess
import sys
import time
from urllib.parse import urlencode, quote
from urllib.request import urlopen


def assess(service, timer, previous, now, max_age):
    record = dict(previous)
    if service.get("LoadState") != "loaded":
        return "down", "Job unit missing", record
    # Failed pre-start hooks have no main exit timestamp; auto-restart waits
    # are activating, not failed. Both must stay down through retry and reboot.
    exited = service.get("exit_epoch", 0)
    if (service.get("ActiveState") == "failed" or service.get("Result") != "success"
            or (exited and service.get("ExecMainStatus") != "0")):
        record["failed"] = True
    elif service.get("ActiveState") == "inactive" and exited:
        record["failed"] = False
        record["last_success"] = exited
    if timer.get("ActiveState") != "active" or timer.get("UnitFileState") != "enabled":
        return "down", "Job timer is not enabled and active", record
    if record.get("failed") or service.get("ActiveState") == "failed":
        return "down", "Latest job run failed", record
    success = record.get("last_success", 0)
    if not success:
        return "down", "No successful completion observed", record
    age = now - success
    if age < 0 or age > max_age:
        return "down", "Successful completion is overdue or clock is inconsistent", record
    return "up", f"Successful completion {age // 60} minutes ago", record


def properties(unit):
    result = subprocess.run(
        ["systemctl", "show", unit, "--property=LoadState,ActiveState,UnitFileState,Result,ExecMainStatus,ExecMainExitTimestamp"],
        check=True, capture_output=True, text=True, timeout=10,
    )
    values = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    stamp = values.get("ExecMainExitTimestamp")
    values["exit_epoch"] = int(subprocess.check_output(
        ["date", "--date", stamp, "+%s"], text=True, timeout=10,
    )) if stamp else 0
    return values


def publish(token, status, message):
    query = urlencode({"status": status, "msg": message})
    url = f"http://127.0.0.1:3001/api/push/{quote(token, safe='')}?{query}"
    with urlopen(url, timeout=10) as response:
        if json.load(response).get("ok") is not True:
            raise RuntimeError("Kuma rejected heartbeat")


def write_metrics(path, jobs, observations, now):
    lines = [f"persops_job_observer_timestamp_seconds {now}"]
    for key, job in jobs.items():
        status, record = observations[key]
        labels = f'scheduled_job={json.dumps(key)}'
        for metric, value in {
            "healthy": int(status == "up"),
            "last_success_timestamp_seconds": record.get("last_success", 0),
            "max_age_seconds": job["max_age"],
        }.items():
            lines.append(f"persops_job_{metric}{{{labels}}} {value}")
    path = Path(path)
    temporary = path.with_suffix(".tmp")
    temporary.write_text("\n".join(lines) + "\n")
    # The parent directory is private to the observer and node exporter group.
    temporary.chmod(0o640)
    temporary.replace(path)


def run(config_path, tokens_path, state_path, metrics_path):
    jobs = json.loads(Path(config_path).read_text())
    state_path = Path(state_path)
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    failed = False
    observations = {}
    heartbeats = {}
    for key, job in jobs.items():
        try:
            status, message, record = assess(
                properties(job["unit"] + ".service"),
                properties(job["unit"] + ".timer"),
                state.get(key, {}), int(time.time()), job["max_age"],
            )
            state[key] = record
            # Persist observations even when Kuma is temporarily down for backup.
            temporary = state_path.with_suffix(".tmp")
            temporary.write_text(json.dumps(state))
            temporary.replace(state_path)
            observations[key] = (status, record)
            if job["kuma"]:
                heartbeats[key] = (status, message)
            print(f"{key}: {status}: {message}", flush=True)
        except Exception as error:
            # URLs contain credentials. Never print exception text or tracebacks.
            print(f"{key}: probe failed ({type(error).__name__})", file=sys.stderr)
            failed = True
            observations[key] = ("down", state.get(key, {}))
    # Publish every job, including probe failures, before attempting delivery.
    write_metrics(metrics_path, jobs, observations, int(time.time()))
    try:
        tokens = json.loads(Path(tokens_path).read_text())
        for key, (status, message) in heartbeats.items():
            try:
                publish(tokens[key], status, message)
            except Exception as error:
                print(f"{key}: delivery failed ({type(error).__name__})", file=sys.stderr)
                failed = True
    except Exception as error:
        print(f"Token loading failed ({type(error).__name__})", file=sys.stderr)
        failed = True
    return int(failed)


if __name__ == "__main__":
    os.umask(0o077)
    sys.exit(run(*sys.argv[1:]))
