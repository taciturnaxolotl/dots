#!/usr/bin/env bash

# Function to set color temperature
set_temperature() {
    # Only set temperature if it's different from the current one
    if [ "$1" != "$CURRENT_TEMP" ]; then
        # Kill any existing hyprsunset process
        if [ -n "$HYPRSUNSET_PID" ]; then
            kill $HYPRSUNSET_PID 2>/dev/null || true
        fi

        # Set color temperature (in Kelvin) and save the PID
        hyprsunset --temperature $1 &
        HYPRSUNSET_PID=$!
        CURRENT_TEMP=$1
    fi
}

# Function to calculate temperature based on battery percentage
calculate_temperature() {
    local bat_percent=$1
    local temp

    if [ "$bat_percent" -le 1 ]; then
        temp=1000
    elif [ "$bat_percent" -le 10 ]; then
        # Linear interpolation between 1% (1000K) and 10% (4000K)
        local range=$((4000 - 1000))
        local factor=$(( (bat_percent - 1) * 100 / 9 ))
        temp=$(( 1000 + (range * factor) / 100 ))
    else
        temp=6500  # Default temperature
    fi

    echo $temp
}

# Initialize variables
HYPRSUNSET_PID=""
CURRENT_TEMP=""
PREV_STATUS=""

# Main loop
while true; do
    # Get battery percentage
    battery_info=$(cat /sys/class/power_supply/BAT1/capacity)
    percent=$(echo $battery_info | tr -d '\n')

    # Check if the battery is charging
    is_plugged=$(cat /sys/class/power_supply/BAT1/status)

    # Create a status string to track changes
    CURRENT_STATUS="${percent}_${is_plugged}"

    # Only update if status has changed or first run
    if [ "$CURRENT_STATUS" != "$PREV_STATUS" ] || [ -z "$PREV_STATUS" ]; then
        if [ "$percent" -le 10 ] && [ "$is_plugged" != "Charging" ]; then
            temp=$(calculate_temperature $percent)
            set_temperature $temp
        else
            # Reset to default temperature
            set_temperature 6500
        fi

        PREV_STATUS="$CURRENT_STATUS"
    fi

    sleep 60  # Check battery status less frequently to reduce flashing
done
