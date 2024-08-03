#!/bin/bash

SCRIPT_DIR="$(dirname "$0")"

pwrstat -test

start_time=$(date +%s)
max_wait_time=300
test_in_progress=false

# Wait for the test to start
while [ $(($(date +%s) - start_time)) -lt $max_wait_time ]; do
    status_output=$(pwrstat -status)

    if echo "$status_output" | grep -q "Test Result.*In progress"; then
        "$SCRIPT_DIR/send_status.sh" \
            --content "🔄 Test in progress 🔄" \
            --color 4886754 \
            --test
        test_in_progress=true
        break
    fi

    sleep 1
done

if [ "$test_in_progress" = false ]; then
    "$SCRIPT_DIR/send_status.sh" \
        --content "🚫 Test failed to start. 🚫" \
        --color 13632027 \
        --test
    exit 1
fi

# Continue checking the status after confirming the test has started
while [ $(($(date +%s) - start_time)) -lt $max_wait_time ]; do
    status_output=$(pwrstat -status)

    if echo "$status_output" | grep -q "Test Result.*Passed at"; then
        test_time=$(echo "$status_output" | grep "Test Result" | sed -E 's/.*Passed at ([0-9]{4}\/[0-9]{2}\/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}).*/\1/')
        test_timestamp=$(date -d "$test_time" +%s)

        if [ "$test_timestamp" -gt "$start_time" ]; then
            "$SCRIPT_DIR/send_status.sh" \
                --content "✅ Test passed! ✅" \
                --test
            exit 0
        else
            "$SCRIPT_DIR/send_status.sh" \
                --content "❓ Could not determine the outcome of the test. ❓" \
                --color 16766720 \
                --test
            exit 1
        fi
    fi

    if echo "$status_output" | grep -qi "Test Result.*failed\|error"; then
        "$SCRIPT_DIR/send_status.sh" \
            --content "❌ Test failed! ❌" \
            --color 13632027 \
            --test
        exit 1
    fi

    sleep 1
done

"$SCRIPT_DIR/send_status.sh" \
    --content "❓ Could not determine the outcome of the test. ❓" \
    --color 16766720 \
    --test
