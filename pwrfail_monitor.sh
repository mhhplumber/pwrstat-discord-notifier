#!/bin/bash

SCRIPT_DIR="$(dirname "$0")"

# Duration to monitor in seconds
DURATION=300
# Interval to check the status in seconds
INTERVAL=1
# Start time
START_TIME=$(date +%s)

# Function to check the UPS status
check_ups_status() {
    # Get the output of the command
    OUTPUT=$(sudo pwrstat -status)
    # Extract the line with "Power Supply by"
    POWER_SUPPLY_LINE=$(echo "$OUTPUT" | grep "Power Supply by")
    # Return the status
    echo "$POWER_SUPPLY_LINE"
}

sudo $SCRIPT_DIR/send_status.sh \
    --content "⚠️A Power Failure Has Occurred!⚠️ \n**Shutdown will occur in $DURATION seconds if recovery is not observed.**" \
    --color 16766720

# Initial status
INITIAL_STATUS=$(check_ups_status)

# Monitor for changes
while true; do
    CURRENT_STATUS=$(check_ups_status)

    # Check if the power supply has changed to "Battery Power"
    if [[ "$CURRENT_STATUS" != *"Battery Power"* && "$CURRENT_STATUS" == *"Utility Power"* ]]; then
        sudo $SCRIPT_DIR/send_status.sh \
            --content "🔌Utility Power Restored!🔌 \n**Aborting Shutdown.**"
        exit 0
    fi

    # Check if the duration has elapsed
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    if [ $ELAPSED_TIME -ge $DURATION ]; then
        sudo $SCRIPT_DIR/send_status.sh \
            --content "⏰Recovery Period Elapsed!⏰ \n**Shutting down...**" \
            --color 13632027
        sudo shutdown now
        exit 0
    fi

    # Wait for the specified interval before checking again
    sleep $INTERVAL
done
