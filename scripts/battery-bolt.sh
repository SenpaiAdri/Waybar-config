#!/bin/bash
# Battery charging bolt for waybar — shows ⚡︎/plug icon OUTSIDE the battery box.
# Waybar custom module with "return-type": "json". Empty text when on battery.
# Safe on desktops: missing sysfs paths yield empty output.
STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
AC=$(cat /sys/class/power_supply/AC0/online 2>/dev/null || echo "0")

if [[ "$STATUS" == "Charging" ]]; then
    echo '{"text": "⚡︎", "class": "charging", "tooltip": "Charging"}'
# elif [[ "$AC" == "1" && "$STATUS" != "Discharging" ]]; then
#     echo '{"text": "󰚥", "class": "plugged", "tooltip": "Plugged in"}'
else
    echo '{"text": ""}'
fi
