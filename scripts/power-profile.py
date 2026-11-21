#!/usr/bin/env python3
"""Waybar status and supported power-profiles-daemon profile controls."""
import json
import os
import re
import shutil
import subprocess
import sys

LABELS = {
    "performance": ("󰓅", "Performance", "performance"),
    "balanced": ("󰾅", "Balanced", "balanced"),
    "power-saver": ("󰾆", "Power Saver", "power-saver"),
}
ORDER = ("power-saver", "balanced", "performance")


def run(*args):
    result = subprocess.run(
        ["powerprofilesctl", *args], capture_output=True, text=True,
        timeout=5, env={**os.environ, "LC_ALL": "C"}, check=False,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Power profile service unavailable")
    return result.stdout.strip()


def profiles(text):
    """Only accept actual profile headers, never driver/status field names."""
    found = set(re.findall(r"^\s*\*?\s*(power-saver|balanced|performance):\s*$", text, re.M))
    return [profile for profile in ORDER if profile in found]


def state():
    available = profiles(run("list"))
    current = run("get")
    if not available or current not in available:
        raise RuntimeError("Power profile service returned an unsupported profile")
    return current, available


def next_profile(current, available, cycle=False):
    if cycle:
        return available[(available.index(current) + 1) % len(available)]
    if "performance" not in available:
        raise RuntimeError("Performance mode is not supported by this hardware or driver")
    if current != "performance":
        return "performance"
    for normal in ("balanced", "power-saver"):
        if normal in available:
            return normal
    raise RuntimeError("No supported profile is available to turn performance mode off")


def status(current, available, error=""):
    icon, label, css = LABELS[current]
    hint = "Click to choose a power profile"
    return {"text": icon, "tooltip": label + "\n" + (error or hint), "class": css,
            "alt": current, "profiles": available, "error": error}


def notify(message):
    if shutil.which("notify-send"):
        try:
            subprocess.run(["notify-send", "-a", "Power Profiles", "Power profile", message],
                           timeout=3, capture_output=True, check=False)
        except (OSError, subprocess.TimeoutExpired):
            pass


def main(argv):
    action = argv[0] if argv else "status"
    explicit = action == "set" and len(argv) == 2 and argv[1] in ORDER
    if not explicit and action not in ("status", "--status", "toggle", "--toggle", "next", "cycle", "--cycle"):
        print("Usage: power-profile.sh [status|toggle|cycle|set PROFILE]", file=sys.stderr)
        return 2
    changing = action not in ("status", "--status")
    current, available = None, []
    try:
        current, available = state()
        if changing:
            target = argv[1] if explicit else next_profile(current, available, action in ("next", "cycle", "--cycle"))
            if target not in available:
                raise RuntimeError("The requested power profile is unavailable")
            if target != current:
                run("set", target)
                # Read the authoritative state: failed or inhibited transitions must
                # not render a successful-looking Performance indicator.
                current, available = state()
                if current != target:
                    raise RuntimeError("The service did not activate the requested power profile")
        print(json.dumps(status(current, available), ensure_ascii=False))
        return 0
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        error = str(exc)
        if changing:
            if not explicit:
                notify(error)
            print(error, file=sys.stderr)
        if current:
            print(json.dumps(status(current, available, error), ensure_ascii=False))
        else:
            print(json.dumps({"text": "󰓅", "tooltip": "Power profiles unavailable\n" + error,
                              "class": "unavailable", "alt": "unavailable", "error": error}, ensure_ascii=False))
        return 1 if changing else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
