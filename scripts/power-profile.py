#!/usr/bin/env python3
"""Waybar status and supported power-profiles-daemon profile controls."""
import json
import os
import re
import shutil
import subprocess
import sys

LABELS = {
    "performance": ("󰓅", "Performance on", "performance"),
    "balanced": ("󰾅", "Performance off · Balanced", "balanced"),
    "power-saver": ("󰾆", "Performance off · Power Saver", "power-saver"),
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
    if "performance" in available:
        hint = "Click: toggle Performance\nRight-click: cycle available profiles"
    else:
        hint = "Performance mode unsupported\nRight-click: cycle available profiles"
    return {"text": icon, "tooltip": label + "\n" + (error or hint), "class": css,
            "alt": current, "profiles": available}


def notify(message):
    if shutil.which("notify-send"):
        try:
            subprocess.run(["notify-send", "-a", "Power Profiles", "Power profile", message],
                           timeout=3, capture_output=True, check=False)
        except (OSError, subprocess.TimeoutExpired):
            pass


def main(argv):
    action = argv[0] if argv else "status"
    if action not in ("status", "--status", "toggle", "--toggle", "next", "cycle", "--cycle"):
        print("Usage: power-profile.sh [status|toggle|cycle]", file=sys.stderr)
        return 2
    changing = action not in ("status", "--status")
    current, available = None, []
    try:
        current, available = state()
        if changing:
            target = next_profile(current, available, action in ("next", "cycle", "--cycle"))
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
            notify(error)
            print(error, file=sys.stderr)
        if current:
            print(json.dumps(status(current, available, error), ensure_ascii=False))
        else:
            print(json.dumps({"text": "󰓅", "tooltip": "Power profiles unavailable\n" + error,
                              "class": "unavailable", "alt": "unavailable"}, ensure_ascii=False))
        return 1 if changing else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
