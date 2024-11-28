#!/bin/bash

# Twilio credentials
ACCOUNT_SID="xxxxx"
AUTH_TOKEN="xxxx"
TWILIO_PHONE="+xxxxx"  # Twilio phone number
RECIPIENT_PHONE="+61xxxxxx"  # Your phone number

# Status tracking file
STATUS_FILE="/tmp/ups_last_status.txt"
TIME_FILE="/tmp/ups_last_time.txt"

# Function to send SMS
send_sms() {
    MESSAGE=$1
    curl -X POST "https://api.twilio.com/2010-04-01/Accounts/$ACCOUNT_SID/Messages.json" \
    --data-urlencode "Body=$MESSAGE" \
    --data-urlencode "From=$TWILIO_PHONE" \
    --data-urlencode "To=$RECIPIENT_PHONE" \
    -u "$ACCOUNT_SID:$AUTH_TOKEN"
}

# Check UPS status
STATUS_OUTPUT=$(pwrstat -status)

# Extract relevant information
STATE=$(echo "$STATUS_OUTPUT" | grep -i "State" | sed -n 's/.*State[.]* //p' | xargs)
POWER_SUPPLY=$(echo "$STATUS_OUTPUT" | grep -i "Power Supply by" | sed -n 's/.*Power Supply by[.]* //p' | xargs)
BATTERY_CAPACITY=$(echo "$STATUS_OUTPUT" | grep -i "Battery Capacity" | sed -n 's/.*Battery Capacity[.]* //p' | xargs)
REMAINING_RUNTIME=$(echo "$STATUS_OUTPUT" | grep -i "Remaining Runtime" | sed -n 's/.*Remaining Runtime[.]* //p' | xargs)
LAST_POWER_EVENT=$(echo "$STATUS_OUTPUT" | grep -i "Last Power Event" | sed -n 's/.*Last Power Event[.]* //p' | xargs)
CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")

# Combine relevant status as a single string
CURRENT_STATUS="$STATE - $POWER_SUPPLY"

# Check previous status
PREVIOUS_STATUS=$(cat "$STATUS_FILE" 2>/dev/null || echo "None")

# Handle status changes
if [[ "$CURRENT_STATUS" != "$PREVIOUS_STATUS" ]]; then
    # Create the message
    if [[ "$POWER_SUPPLY" == "Battery Power" ]]; then
        MESSAGE="[$CURRENT_TIME] Alert: UPS is on battery power due to a power failure!
State: $STATE
Power Supply: $POWER_SUPPLY
Battery Capacity: $BATTERY_CAPACITY
Remaining Runtime: $REMAINING_RUNTIME
Last Power Event: $LAST_POWER_EVENT"
    elif [[ "$POWER_SUPPLY" == "Utility Power" ]]; then
        MESSAGE="[$CURRENT_TIME] Notification: UPS has returned to mains power (Utility Power).
State: $STATE
Power Supply: $POWER_SUPPLY
Battery Capacity: $BATTERY_CAPACITY"
    else
        MESSAGE="[$CURRENT_TIME] Notification: UPS status has changed.
State: $STATE
Power Supply: $POWER_SUPPLY"
    fi

    # Output the message in the terminal
    echo "$MESSAGE"

    # Send SMS
    send_sms "$MESSAGE"

    # Save the current status
    echo "$CURRENT_STATUS" > "$STATUS_FILE"
    echo "$CURRENT_TIME" > "$TIME_FILE"
else
    echo "No significant status change. No message sent."
    echo "Last Status: $PREVIOUS_STATUS"
    echo "Current Status: $CURRENT_STATUS"
fi
