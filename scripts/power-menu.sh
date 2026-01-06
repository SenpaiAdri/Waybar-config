#!/usr/bin/env bash
set -euo pipefail

choose_menu() {
  if command -v rofi >/dev/null 2>&1; then
    # rofi-wayland or rofi under Xwayland
    echo "rofi -dmenu -theme ${HOME}/.config/rofi/powermenu.rasi -p Power"
    return 0
  fi

  if command -v wofi >/dev/null 2>&1; then
    # Wayland-first
    echo "wofi --dmenu --prompt Power --width 260 --lines 4"
    return 0
  fi

  if command -v bemenu >/dev/null 2>&1; then
    echo "bemenu -p Power"
    return 0
  fi

  return 1
}

MENU_CMD="$(choose_menu || true)"
if [[ -z "${MENU_CMD}" ]]; then
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Waybar power menu" "Install wofi (recommended), rofi, or bemenu."
  fi
  exit 1
fi

selection="$(
  printf '%s\n' \
    "  Sleep" \
    "  Restart" \
    "  Shutdown" \
  | eval "${MENU_CMD}"
)"

case "${selection}" in
  *"Sleep")
    if command -v hyprlock >/dev/null 2>&1; then
      hyprlock &
      sleep 0.2
    elif command -v loginctl >/dev/null 2>&1; then
      loginctl lock-session || true
      sleep 0.2
    fi
    systemctl suspend
    ;;
  *"Restart")
    systemctl reboot
    ;;
  *"Shutdown")
    systemctl poweroff
    ;;
  *)
    # cancelled / closed
    exit 0
    ;;
esac



