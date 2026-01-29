#!/usr/bin/env bash

# Notify user that we are scanning
notify-send "Wi-Fi" "Scanning for networks..."

# Get list of networks
# We use a specific format for nmcli to make parsing easier while keeping it readable
# Fields: IN-USE, SSID, SECURITY, BARS
wifi_list=$(nmcli --fields "IN-USE,SSID,SECURITY,BARS" device wifi list | sed 1d | sed 's/^\* /  /g')

# Check current state
connected=$(nmcli -fields WIFI g)
if [[ "$connected" =~ "enabled" ]]; then
    toggle="Toggle Wi-Fi Off"
else
    toggle="Toggle Wi-Fi On"
fi

# Show menu
chosen_network=$(echo -e "$toggle\n$wifi_list" | uniq -u | rofi -dmenu -i -p "Wi-Fi: " -width 30)

# Exit if cancelled
if [ -z "$chosen_network" ]; then
    exit
fi

# Handle toggle action
if [ "$chosen_network" = "Toggle Wi-Fi Off" ]; then
    nmcli radio wifi off
    notify-send "Wi-Fi" "Wi-Fi disabled"
    exit
elif [ "$chosen_network" = "Toggle Wi-Fi On" ]; then
    nmcli radio wifi on
    notify-send "Wi-Fi" "Wi-Fi enabled"
    exit
fi

# Extract SSID from the chosen line
# The ssid is the second field (or after leading spaces)
# We need to be careful with parsing. 
# A simpler approach for the selection is just to take the whole line and extract the SSID.
# Assuming standard output format, SSID starts after some spaces.
# Let's clean the selection to get the SSID.
# Removing the potential "IN-USE" star/space and security/bars is tricky if we just grab text.

# Better approach: 
# Let's just ask for the SSID cleanly if we can't parse easily, but users want to click the list.
# Let's try to extract the SSID.
# Format: "  SSIDName  WPA2  ▂▄▆_"
# We can try to parse it. 
# However, for simplicity and robustness, passing the SSID back to nmcli is key.

# Let's retry the list generation to be cleaner for parsing, but readable.
# nmcli -f SSID device wifi list
# The problem is duplicate SSIDs.

# Let's try to parse the chosen line.
# Remove leading spaces/stars
chosen_id=$(echo "$chosen_network" | sed 's/^\s*//' | awk -F '  ' '{print $1}')

if [ -z "$chosen_id" ]; then
    exit
fi

# Check if we are already connected or have a saved connection
saved_connections=$(nmcli -g NAME connection)
if echo "$saved_connections" | grep -Fxq "$chosen_id"; then
    nmcli device wifi connect "$chosen_id" && notify-send "Wi-Fi" "Connected to $chosen_id"
else
    # It's a new connection. Check security.
    if [[ "$chosen_network" =~ "WPA" || "$chosen_network" =~ "WEP" ]]; then
        wifi_password=$(rofi -dmenu -p "Password for $chosen_id: " -password)
        if [ -n "$wifi_password" ]; then
            nmcli device wifi connect "$chosen_id" password "$wifi_password" && notify-send "Wi-Fi" "Connected to $chosen_id"
        fi
    else
        # Open network
        nmcli device wifi connect "$chosen_id" && notify-send "Wi-Fi" "Connected to $chosen_id"
    fi
fi
