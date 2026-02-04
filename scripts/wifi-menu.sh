#!/usr/bin/env bash

# Constants
NOTIFY_TITLE="Wi-Fi"
WIDTH=30

# Helper function for notifications
notify() {
    notify-send "$NOTIFY_TITLE" "$1"
}

# Function to get current status
get_status() {
    wifi_status=$(nmcli -fields WIFI g)
    if [[ "$wifi_status" =~ "enabled" ]]; then
        state="ON"
    else
        state="OFF"
    fi

    # Get current connection info
    current_connection=$(nmcli -t -f active,ssid,signal dev wifi | grep '^yes')
    if [ -n "$current_connection" ]; then
        ssid=$(echo "$current_connection" | cut -d: -f2)
        signal=$(echo "$current_connection" | cut -d: -f3)
        echo "  $ssid ($signal%)"
    else
        if [ "$state" = "ON" ]; then
            echo "󰖪  Disconnected"
        else
            echo "󰖪  Wi-Fi is Off"
        fi
    fi
}

# Function to list saved connections
saved_menu() {
    # Get list of saved connections (name only)
    # We use -t (terse) mode to handle spaces in names correctly
    # Filter for lines ending in :802-11-wireless or :wifi
    saved_list=$(nmcli -t -f NAME,TYPE connection show | grep -E ":802-11-wireless|:wifi" | cut -d: -f1 | sort | uniq)

    if [ -z "$saved_list" ]; then
        notify "No saved networks found."
        return
    fi

    # Show menu to delete
    chosen_saved=$(echo -e "⬅ Back\n$saved_list" | rofi -dmenu -i -p "Manage Saved: " -width $WIDTH)

    if [ "$chosen_saved" = "⬅ Back" ] || [ -z "$chosen_saved" ]; then
        main_menu
        return
    fi

    # Confirm deletion
    action=$(echo -e "❌ Forget Network\n⬅ Cancel" | rofi -dmenu -i -p "$chosen_saved options: " -width $WIDTH)

    if [ "$action" = "❌ Forget Network" ]; then
        nmcli connection delete "$chosen_saved"
        notify "Forgot network: $chosen_saved"
        saved_menu # Return to saved menu
    else
        saved_menu
    fi
}

# Main Menu Logic
main_menu() {
    # 1. Get Status
    status_line=$(get_status)
    
    # 2. Determine Toggle State
    wifi_enabled=$(nmcli -fields WIFI g)
    if [[ "$wifi_enabled" =~ "enabled" ]]; then
        toggle_opt="  Disable Wi-Fi"
        scanning=true
    else
        toggle_opt="  Enable Wi-Fi"
        scanning=false
    fi

    # 3. Build Menu Options
    # Note: Using spaces (not tabs) for consistency with case matching
    options="$toggle_opt\n🔄  Rescan Networks\n🛠  Manage Saved Networks"

    if [ "$scanning" = true ]; then
        # Get list of networks: SSID, SECURITY, BARS
        # We use a custom format to make it look nice in rofi
        # Using awk to format: "BARS  SSID  (SECURITY)"
        wifi_list=$(nmcli --fields BARS,SSID,SECURITY device wifi list | sed 1d | \
            awk -F'  +' '{printf "%s  %-20s  (%s)\n", $1, $2, $3}')
        
        if [ -n "$wifi_list" ]; then
            options="$options\n$wifi_list"
        else
            options="$options\n(No networks found)"
        fi
    fi

    # 4. Show Rofi
    # -mesg shows the status line at the top
    # We add a custom keybinding (Alt+r) for refresh as well
    chosen=$(echo -e "$options" | rofi -dmenu -i -p "Wi-Fi" -width $WIDTH -mesg "$status_line" -kb-custom-1 "Alt+r")
    
    # 5. Handle Selection or Custom Key
    exit_code=$?

    if [ $exit_code -eq 10 ]; then
        # 10 is the exit code for kb-custom-1
        notify "Scanning for networks..."
        nmcli device wifi rescan
        main_menu
        exit
    fi
    if [ -z "$chosen" ]; then
        exit
    fi

    case "$chosen" in
        "  Disable Wi-Fi")
            nmcli radio wifi off
            notify "Wi-Fi disabled"
            ;;
        "  Enable Wi-Fi")
            nmcli radio wifi on
            notify "Wi-Fi enabled"
            sleep 1 # Wait a bit for it to wake up
            main_menu
            ;;
        "🔄  Rescan Networks")
            notify "Scanning for networks..."
            nmcli device wifi rescan
            main_menu
            ;;
        "🛠  Manage Saved Networks")
            saved_menu
            ;;
        "(No networks found)")
            main_menu
            ;;
        *)
            # It's a network selection
            # Extract SSID (Column 2 based on our formatting above)
            # The format was: "BARS  SSID  (SECURITY)"
            # Example: "▂▄▆_  My Wifi  (WPA2)"
            
            # Robust Strategy:
            # 1. Strip the bars (first field)
            ssid_candidate=$(echo "$chosen" | sed -E 's/^[^ ]+[ ]+//')
            # 2. Strip the security info at the end: "  (WPA2...)"
            ssid_candidate=$(echo "$ssid_candidate" | sed -E 's/[ ]+\(.*\)$//')
            # 3. Trim trailing spaces
            ssid_candidate=$(echo "$ssid_candidate" | sed -E 's/[ \t]*$//')
            
            if [ -z "$ssid_candidate" ]; then exit; fi

            # Connect Logic
            saved_connections=$(nmcli -g NAME connection)
            if echo "$saved_connections" | grep -Fxq "$ssid_candidate"; then
                nmcli device wifi connect "$ssid_candidate" && notify "Connected to $ssid_candidate"
            else
                # New connection
                # Check if security is needed
                if [[ "$chosen" =~ "WPA" || "$chosen" =~ "WEP" ]]; then
                    password=$(rofi -dmenu -p "Password for $ssid_candidate: " -password -width $WIDTH)
                    if [ -n "$password" ]; then
                        nmcli device wifi connect "$ssid_candidate" password "$password" && notify "Connected to $ssid_candidate"
                    fi
                else
                    # Open network
                    nmcli device wifi connect "$ssid_candidate" && notify "Connected to $ssid_candidate"
                fi
            fi
            ;;
    esac
}

# Start
main_menu
