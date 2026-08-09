#!/usr/bin/env bash
##
## Requirements:
##  - `slurp`: to select an area
##  - `notify-send`: to show notifications (provided by libnotify)
##  - `wl-screenrec`: for screen recording
##  - `ffmpeg`: for thumbnail generation
# If wl-screenrec is already running, stop recording.
if pgrep -x "wl-screenrec" > /dev/null; then
    killall -s 2 wl-screenrec
    exit 0
fi

# Set up file path for recording
FILE="$HOME/Downloads/screencast_$(date +%Y%m%d_%H%M%S).mp4"

# Get audio device information using wireplumber
MONITOR_DEVICE=""
DEFAULT_DEVICE=$(wpctl status | grep "Default Configured Devices" -A 2 | grep "Audio/Sink" | awk '{print $NF}')

if [ -n "$DEFAULT_DEVICE" ]; then
    # Try to construct the monitor device name
    MONITOR_DEVICE="${DEFAULT_DEVICE}.monitor"

    # Check if the device exists by attempting to get its properties
    DEVICE_ID=$(wpctl status | grep -A 1 "Built-in Audio Analog Stereo" | grep -o '[0-9]\+\.' | head -1 | tr -d '.')
    if [ -n "$DEVICE_ID" ] && wpctl inspect "$DEVICE_ID" > /dev/null 2>&1; then
        echo "Found audio device, will use monitor: $MONITOR_DEVICE"
        AUDIO_ARGS=(--audio --audio-device "$MONITOR_DEVICE")
    else
        echo "Couldn't confirm monitor device, falling back to default audio"
        AUDIO_ARGS=(--audio)
    fi
else
    echo "No default audio device found, falling back to default audio capture"
    AUDIO_ARGS=(--audio)
fi

# Process arguments to determine if full screen or area selection
if [ "$1" = "fullscreen" ]; then
    # Full screen recording
    notify-send -t 1000 -a "wl-screenrec" "Starting full screen recording"
    ARGS=()
else
    # Area selection
    notify-send -t 1000 -a "wl-screenrec" "Select area or window to record"
    # Get list of visible windows for slurp to highlight
    WINDOWS="$(hyprctl clients -j | jq -r '.[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
    # Use slurp with window detection
    GEOMETRY=$(echo "$WINDOWS" | slurp)
    # Check if user canceled selection
    if [ -z "$GEOMETRY" ]; then
        notify-send -t 3000 -a "wl-screenrec" "Recording canceled"
        exit 1
    fi
    notify-send -t 1000 -a "wl-screenrec" "Starting area recording"
    ARGS=(-g "$GEOMETRY")
fi

# Start recording. Arrays rather than eval: a path or a geometry carrying a
# space should be one argument, not a new command.
NOTIFY_RESULT=$(mktemp -t hyprrec.XXXXXX)
trap 'rm -f "$NOTIFY_RESULT"' EXIT
wl-screenrec "${ARGS[@]}" "${AUDIO_ARGS[@]}" -f "$FILE" && \
# Create a thumbnail from the recording
ffmpeg -i "$FILE" -ss 00:00:00 -vframes 1 -update 1 -frames:v 1 /tmp/screenrec_thumbnail.png -y && \
# Notify that recording is saved with clickable action
notify-send -a "wl-screenrec" "Recording saved to $FILE" \
    -i "/tmp/screenrec_thumbnail.png" \
    -A "default=Open" > "$NOTIFY_RESULT"

# Check if notification was clicked
if grep -q "default" "$NOTIFY_RESULT"; then
    if command -v xdg-open > /dev/null; then
        xdg-open "$FILE"
    elif command -v gdbus > /dev/null; then
        gdbus call --session \
            --dest org.freedesktop.FileManager1 \
            --object-path /org/freedesktop/FileManager1 \
            --method org.freedesktop.FileManager1.ShowItems "['file://$FILE']" ""
    fi
fi
