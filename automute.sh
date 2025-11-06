#!/bin/bash

################################################################################
# AutoMute on Bluetooth Disconnect
# 
# Automatically mutes macOS volume when Bluetooth audio devices disconnect
# to prevent embarrassing audio leaks in the office.
#
# Author: Mohammad Sadiq
# GitHub: https://github.com/yourusername/AutoMute-on-Bluetooth-Disconnect
################################################################################

# ============================================================================
# CONFIGURATION - Customize these settings
# ============================================================================

# Optional: Set log file path (leave empty to disable logging)
LOG_FILE=""

# Whitelist: Apps that can play audio even without Bluetooth
# Add app names exactly as they appear in Activity Monitor
WHITELIST=(
    "Zoom.us"
    "Slack"
    "FaceTime"
    "Microsoft Teams"
)

# Check interval in seconds (how often to check for changes)
CHECK_INTERVAL=0.5

# Show macOS notifications (true/false)
SHOW_NOTIFICATIONS=true

log_msg() {
    if [ -n "$LOG_FILE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    fi
}

get_output_transport() {
    system_profiler SPAudioDataType 2>/dev/null | \
    awk '/Default Output Device: Yes/,/Transport:/ {
        if ($0 ~ /Transport:/) {
            print $2
            exit
        }
    }'
}

is_bluetooth() {
    local transport="$1"
    [[ "$transport" == "Bluetooth" ]]
}

is_whitelisted_app_active() {
    [ ${#WHITELIST[@]} -eq 0 ] && return 1
    local frontmost_app=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
    for app in "${WHITELIST[@]}"; do
        if [[ "$frontmost_app" == "$app" ]]; then
            log_msg "Whitelisted app active: $app"
            return 0
        fi
    done
    return 1
}

mute() {
    local current_status=$(osascript -e "output muted of (get volume settings)" 2>/dev/null)
    if [[ "$current_status" != "true" ]]; then
        osascript -e "set volume output muted true" 2>/dev/null
        log_msg "Muted - Bluetooth disconnected"
        if [ "$SHOW_NOTIFICATIONS" = true ]; then
            osascript -e 'display notification "Volume muted for privacy" with title "🔇 Bluetooth Disconnected"' 2>/dev/null
        fi
    fi
}

unmute() {
    local current_status=$(osascript -e "output muted of (get volume settings)" 2>/dev/null)
    if [[ "$current_status" == "true" ]]; then
        osascript -e "set volume output muted false" 2>/dev/null
        log_msg "Unmuted - Bluetooth connected"
    fi
}

log_msg "Started (PID: $$)"
PREV_STATE=""

while true; do
    TRANSPORT=$(get_output_transport)
    
    if is_bluetooth "$TRANSPORT"; then
        CURR_STATE="BT"
        if [ "$PREV_STATE" != "BT" ]; then
            log_msg "Bluetooth connected"
            unmute
        fi
    else
        CURR_STATE="INTERNAL"
        if [ "$PREV_STATE" == "BT" ]; then
            if is_whitelisted_app_active; then
                log_msg "Whitelisted app - keeping audio on"
            else
                mute
            fi
        fi
    fi
    
    PREV_STATE="$CURR_STATE"
    sleep "$CHECK_INTERVAL"
done
