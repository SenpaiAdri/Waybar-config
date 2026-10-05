#!/usr/bin/env bash
# Waybar bell: unread count + DND state from the quickshell notif server.
# Emits waybar JSON: {"text": ..., "tooltip": ..., "class": ...}
STATUS=$(quickshell ipc call notifs status 2>/dev/null)
if [ -n "$STATUS" ]; then
    # status is already waybar-shaped JSON; stamp the unread dot on the bell
    echo "$STATUS" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if d.get('class') == 'unread':
    d['text'] = d['text'] + '<span foreground=\"#f38ba8\"><sup></sup></span>'
print(json.dumps(d))
"
else
    echo '{"text": "", "tooltip": "Notification server unavailable", "class": ""}'
fi
