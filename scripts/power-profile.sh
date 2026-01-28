#!/bin/bash

# Get current profile
current=$(powerprofilesctl get)

if [ "$1" == "next" ]; then
    case "$current" in
        "power-saver")
            powerprofilesctl set balanced
            ;;
        "balanced")
            powerprofilesctl set performance
            ;;
        "performance")
            powerprofilesctl set power-saver
            ;;
    esac
    # Wait a tiny bit for the change to register
    sleep 0.1
    current=$(powerprofilesctl get)
fi

# Define icons/text for each profile
case "$current" in
    "performance")
        text="Perf"
        icon="󰓅"
        tooltip="Performance Mode"
        class="performance"
        ;;
    "balanced")
        text="Bal"
        icon="󰾅"
        tooltip="Balanced Mode"
        class="balanced"
        ;;
    "power-saver")
        text="Save"
        icon="󰾆"
        tooltip="Power Saver Mode"
        class="power-saver"
        ;;
    *)
        text="$current"
        icon="?"
        tooltip="Unknown profile"
        class="unknown"
        ;;
esac

# Output JSON for Waybar
echo "{\"text\": \"$icon\", \"tooltip\": \"$tooltip\", \"class\": \"$class\", \"alt\": \"$current\"}"
