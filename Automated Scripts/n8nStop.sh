#!/bin/bash

echo "--- Stopping Ngrok tunnel and n8n ---"

NGROK_PID_TO_KILL=""
N8N_PID_TO_KILL=""

# Find Ngrok PID first
if pgrep -x "ngrok" > /dev/null; then
    NGROK_PID_TO_KILL=$(pgrep -x "ngrok" | head -n 1)
    echo "Attempting to stop Ngrok (PID: $NGROK_PID_TO_KILL)..."
    pkill -TERM -x "ngrok"
else
    echo "Ngrok is not running."
fi

# Find n8n PID
if pgrep -x "node" | xargs -r ps -f | grep -q "n8n start"; then
    N8N_PID_TO_KILL=$(pgrep -x "node" | xargs -r ps -f | grep "n8n start" | awk '{print $2}' | head -n 1)
    echo "Attempting to stop n8n (PID: $N8N_PID_TO_KILL)..."
    pkill -TERM -f "n8n start"
else
    echo "n8n is not running."
fi

sleep 2

# Verify and Force Kill Ngrok if necessary
if [ -n "$NGROK_PID_TO_KILL" ]; then
    if pgrep -x "ngrok" > /dev/null; then
        echo "Ngrok (PID: $NGROK_PID_TO_KILL) is still running. Forcing termination..."
        pkill -KILL -x "ngrok"
        sleep 1
        if pgrep -x "ngrok" > /dev/null; then
            echo "ERROR: Ngrok (PID: $NGROK_PID_TO_KILL) failed to terminate."
        else
            echo "Ngrok stopped successfully."
        fi
    else
        echo "Ngrok stopped successfully."
    fi
fi

# Verify and Force Kill n8n if necessary
if [ -n "$N8N_PID_TO_KILL" ]; then
    if pgrep -x "node" | xargs -r ps -f | grep -q "n8n start"; then
        echo "n8n (PID: $N8N_PID_TO_KILL) is still running. Forcing termination..."
        pkill -KILL -f "n8n start"
        sleep 1
        if pgrep -x "node" | xargs -r ps -f | grep -q "n8n start"; then
            echo "ERROR: n8n (PID: $N8N_PID_TO_KILL) failed to terminate."
        else
            echo "n8n stopped successfully."
        fi
    else
        echo "n8n stopped successfully."
    fi
fi

echo "--- Cleanup Temporary Files (Optional) ---"
# Uncomment the lines below if you want to clean up the /tmp logs
# rm -f /tmp/ngrok_run_output.log
# rm -f /tmp/n8n_run_output.log

echo "Stop script finished."