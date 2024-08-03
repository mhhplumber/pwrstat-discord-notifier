#!/bin/sh

SCRIPT_DIR="$(dirname "$0")"
WEBHOOK_URL=$(cat $SCRIPT_DIR/discord_hook.txt)

# Default values
CONTENT="\u200b"  # Empty Character
COLOR=3066993     # Green

VERBOSE=false     # flag for verbose output
TEST=false        # flag for test output

# Function to display usage
usage() {
    echo "Usage: $0 [-C content | --content content] [-c color | --color color]"
    echo "  -C, --content   Set the content for the Discord embed."
    echo "  -c, --color     Set the color for the Discord embed (in decimal)."
    exit 1
}

# Parse command-line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        -C|--content)
            shift
            if [ -n "$1" ]; then
                CONTENT="$1"
                shift
            else
                echo "Error: --content requires a non-empty argument."
                usage
            fi
            ;;
        -c|--color)
            shift
            if [ -n "$1" ] && [ "$1" -eq "$1" ] 2>/dev/null; then
                COLOR="$1"
                shift
            else
                echo "Error: --color requires a non-empty numeric argument."
                usage
            fi
            ;;
        -v|--verbose) 
            VERBOSE=true
            shift
            ;;
        -t|--test)
            TEST=true
            shift
            ;;
        *)
            echo "Error: Invalid argument '$1'."
            usage
            ;;
    esac
done

CURRENT_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
UPS_STATUS=$(pwrstat -status)
UPS_STATUS=$(echo "$UPS_STATUS" | sed 's/\.\{1,\}/|/g')

# Parse the output using the pipe character as the delimiter
MODEL_NAME=$(echo "$UPS_STATUS" | grep "Model Name" | awk -F'|' '{print $2}' | xargs)
FIRMWARE_NUMBER=$(echo "$UPS_STATUS" | grep "Firmware Number" | awk -F'|' '{print $2}' | xargs)
RATING_VOLTAGE=$(echo "$UPS_STATUS" | grep "Rating Voltage" | awk -F'|' '{print $2}' | xargs)
RATING_POWER=$(echo "$UPS_STATUS" | grep "Rating Power" | awk -F'|' '{print $2}' | xargs)
POWER_SUPPLY=$(echo "$UPS_STATUS" | grep "Power Supply by" | awk -F'|' '{print $2}' | xargs)
UTILITY_VOLTAGE=$(echo "$UPS_STATUS" | grep "Utility Voltage" | awk -F'|' '{print $2}' | xargs)
OUTPUT_VOLTAGE=$(echo "$UPS_STATUS" | grep "Output Voltage" | awk -F'|' '{print $2}' | xargs)
BATTERY_CAPACITY=$(echo "$UPS_STATUS" | grep "Battery Capacity" | awk -F'|' '{print $2}' | xargs)
REMAINING_RUNTIME=$(echo "$UPS_STATUS" | grep "Remaining Runtime" | awk -F'|' '{print $2}' | xargs)
LOAD=$(echo "$UPS_STATUS" | grep "Load" | awk -F'|' '{print $2}' | xargs)
LINE_INTERACTION=$(echo "$UPS_STATUS" | grep "Line Interaction" | awk -F'|' '{print $2}' | xargs)
TEST_RESULT=$(echo "$UPS_STATUS" | grep "Test Result" | awk -F'|' '{print $2}' | xargs)
LAST_POWER_EVENT=$(echo "$UPS_STATUS" | grep "Last Power Event" | awk -F'|' '{print $2}' | xargs)

# Determine the status thumbnail based on battery capacity
if [ "$POWER_SUPPLY" = "Utility Power" ]; then
    THUMBNAIL="https://github.com/mhhplumber/pwrstat-discord-notifier/blob/main/icons/batt_pwrd.png?raw=true&v=1"
    UV_STRING="\nUtility Voltage: $UTILITY_VOLTAGE"
elif [ "${BATTERY_CAPACITY% %}" -gt 90 ]; then
    THUMBNAIL="https://github.com/mhhplumber/pwrstat-discord-notifier/blob/main/icons/batt_100.png?raw=true&v=1"
elif [ "${BATTERY_CAPACITY% %}" -gt 65 ]; then
    THUMBNAIL="https://github.com/mhhplumber/pwrstat-discord-notifier/blob/main/icons/batt_75.png?raw=true&v=1"
elif [ "${BATTERY_CAPACITY% %}" -gt 40 ]; then
    THUMBNAIL="https://github.com/mhhplumber/pwrstat-discord-notifier/blob/main/icons/batt_50.png?raw=true&v=1"
else
    THUMBNAIL="https://github.com/mhhplumber/pwrstat-discord-notifier/blob/main/icons/batt_25.png?raw=true&v=1"
fi

if [ "$LINE_INTERACTION" != "None" ]; then
    LI_STRING="\nLine Interaction: $LINE_INTERACTION"
fi

DEVICE_INFO="Model Name: $MODEL_NAME"
STATUS="Power Supply: $POWER_SUPPLY\nBattery Capacity: $BATTERY_CAPACITY\nRemaining Runtime: $REMAINING_RUNTIME\nLoad: $LOAD\nLast Event: $LAST_POWER_EVENT"
if $VERBOSE; then
    DEVICE_INFO="$DEVICE_INFO\nFirmware Number: $FIRMWARE_NUMBER\nRating Voltage: $RATING_VOLTAGE\nRating Power: $RATING_POWER"
    STATUS="$STATUS$UV_STRING\nOutput Voltage: $OUTPUT_VOLTAGE$LI_STRING\nTest Result: $TEST_RESULT"
elif $TEST; then
    STATUS="$STATUS\nTest Result: $TEST_RESULT"
fi

# Create the JSON payload for the Discord embed
JSON_PAYLOAD=$(cat <<EOF
{
  "content": "$CONTENT",
  "embeds": [
    {
      "title": "UPS Status ⚡",
      "thumbnail": {
        "url": "$THUMBNAIL"
      },
      "color": $COLOR,
      "fields": [
        {
          "name": "Device Information",
          "value": "$DEVICE_INFO",
          "inline": false
        },
        {
          "name": "Status",
          "value": "$STATUS",
          "inline": false
        },
        {
          "name": "Timestamp",
          "value": "$CURRENT_TIMESTAMP",
          "inline": false
        }
      ]
    }
  ]
}
EOF
)

# Send the embed to Discord
curl -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$WEBHOOK_URL"
