#!/usr/bin/env bash
# Capture the click position before opening a popup and taking keyboard focus.
set -u
target="${1:-}"
case "$target" in
    controls|sound|wifi|notifs|profile) ;;
    *) exit 2 ;;
esac
fallback() { exec quickshell ipc call "$target" toggle; }
command -v jq >/dev/null 2>&1 || fallback
cursor=$(hyprctl -j cursorpos 2>/dev/null) || fallback
monitors=$(hyprctl -j monitors 2>/dev/null) || fallback
position=$(jq -nr --argjson cursor "$cursor" --argjson monitors "$monitors" \
    --arg output "${WAYBAR_OUTPUT_NAME:-}" '
    $monitors[] |
    select(.disabled != true) |
    . as $monitor |
    (if ((.transform // 0) % 2) == 1 then .height else .width end) / (.scale // 1) as $w |
    (if ((.transform // 0) % 2) == 1 then .width else .height end) / (.scale // 1) as $h |
    select(($output != "" and .name == $output) or
           ($output == "" and $cursor.x >= .x and $cursor.x < (.x + $w) and
            $cursor.y >= .y and $cursor.y < (.y + $h))) |
    [.name, (($cursor.x - .x) | round)] | @tsv
    ' 2>/dev/null) || fallback
IFS=$'\t' read -r monitor local_x <<< "$position"
[[ -n "$monitor" && "$local_x" =~ ^-?[0-9]+$ ]] || fallback
exec quickshell ipc call "$target" toggleAt "$monitor" "$local_x"
