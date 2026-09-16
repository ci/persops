#!/usr/bin/env python3
"""Off-host reachability observer; credentials and incident state stay off-repo."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.request

PRIMARY = "https://notify.reverse-justitia.ts.net"
TARGETS = {"Amalthea": "100.113.202.103", "Home router": "100.116.69.49"}
THRESHOLD = 3


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward credentials (or accept a login page) after a redirect.
        return None


def request_json(url, data=None, headers=None):
    request = urllib.request.Request(url, data=data, headers=headers or {})
    with urllib.request.build_opener(NoRedirect()).open(request, timeout=8) as response:
        return json.load(response)


def probes():
    results = {}
    for name, address in TARGETS.items():
        try:
            result = subprocess.run(
                ["/usr/bin/tailscale", "ping", "--tsmp", "--c", "1", "--timeout", "3s", address],
                capture_output=True, text=True, timeout=6, check=False,
            )
            results[name] = result.returncode == 0 and "via TSMP" in result.stdout
        except (OSError, subprocess.TimeoutExpired):
            results[name] = False
    try:
        results["Private notifications"] = request_json(PRIMARY + "/v1/health").get("healthy") is True
    except Exception:
        results["Private notifications"] = False
    return results


def credentials(path):
    value = json.loads(path.read_text())
    if not re.fullmatch(r"tk_[A-Za-z0-9]{29}", value["primary_token"]):
        raise ValueError("invalid token")
    if not re.fullmatch(r"[a-f0-9]{64}", value["fallback_topic"]):
        raise ValueError("invalid fallback topic")
    return value


def publish(secrets, route, message, recovered=False):
    headers = {"Title": "Pheme off-host monitor", "Priority": "3" if recovered else "5"}
    if route == "primary":
        url = PRIMARY + "/alerts"
        headers["Authorization"] = "Bearer " + secrets["primary_token"]
    else:
        url = "https://ntfy.sh/" + secrets["fallback_topic"]
    try:
        result = request_json(url, message.encode(), headers)
        return result.get("event") == "message" and bool(result.get("id"))
    except Exception:
        # Exception strings can contain the secret hosted topic URL.
        return False


def observe(state, results, send):
    """Persist routes that accepted DOWN so recovery reaches the same subscribers."""
    delivered = True
    for name, healthy in results.items():
        entry = state.setdefault(name, {"failures": 0, "routes": []})
        entry["failures"] = 0 if healthy else min(THRESHOLD, entry["failures"] + 1)
        if healthy:
            for route in entry["routes"][:]:
                if send(route, f"RECOVERED: {name} reachable from Pheme.", True):
                    entry["routes"].remove(route)
                else:
                    delivered = False
        elif entry["failures"] >= THRESHOLD and not entry["routes"]:
            for route in ("primary", "fallback"):
                if send(route, f"DOWN: {name} unreachable from Pheme.", False):
                    entry["routes"].append(route)
                    break
            else:
                delivered = False
    return delivered


def save(path, state):
    temporary = path.with_suffix(".tmp")
    with temporary.open("w") as output:
        json.dump(state, output)
        output.flush()
        os.fsync(output.fileno())
    temporary.replace(path)


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser()
    parser.add_argument("--test", choices=("primary", "fallback"))
    args = parser.parse_args()
    secret_path = Path(os.environ["CREDENTIALS_DIRECTORY"]) / "credentials.json"
    secrets = credentials(secret_path)
    send = lambda route, message, recovered: publish(secrets, route, message, recovered)
    if args.test:
        accepted = send(args.test, "TEST ONLY: Pheme notification delivery check; no outage.", True)
        print(f"{args.test} test accepted={accepted}")
        return 0 if accepted else 1
    path = Path(os.environ["STATE_DIRECTORY"]) / "state.json"
    state = json.loads(path.read_text()) if path.exists() else {}
    results = probes()
    delivered = observe(state, results, send)
    save(path, state)
    print(json.dumps({"healthy": results, "delivery_ok": delivered}))
    return 0 if delivered else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"watcher failed: {type(error).__name__}", file=sys.stderr)
        sys.exit(1)
