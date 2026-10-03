#!/bin/bash
# Instant waybar battery refresh — no root needed.
# Polls sysfs (cheap: 3 small reads/sec) and pokes waybar via SIGRTMIN+9
# the moment AC / status / capacity changes. Waybar's own 5s interval
# remains as fallback.
# Managed by: systemd user service waybar-battery-watch.service
set -u

BAT="/sys/class/power_supply/BAT0"
AC="/sys/class/power_supply/AC0"

read_state() {
    local st ac cap
    st=$(cat "$BAT/status" 2>/dev/null || echo "?")
    ac=$(cat "$AC/online" 2>/dev/null || echo "?")
    cap=$(cat "$BAT/capacity" 2>/dev/null || echo "?")
    printf '%s|%s|%s' "$st" "$ac" "$cap"
}

last=$(read_state)
while true; do
    sleep 1
    cur=$(read_state)
    if [[ "$cur" != "$last" ]]; then
        last="$cur"
        pkill -RTMIN+9 waybar 2>/dev/null || true
    fi
done
