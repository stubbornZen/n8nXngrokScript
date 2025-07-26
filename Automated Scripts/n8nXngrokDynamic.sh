#!/bin/bash

N8N_DATA_FOLDER="/root/.n8n"
NGROK_OUTPUT_FILE="/tmp/ngrok_run_output.log"
NGROK_CONFIG_PATH="/root/.config/ngrok/ngrok.yml"
N8N_OUTPUT_FILE="/tmp/n8n_run_output.log"
N8N_DEFAULT_PORT=5678 

# Ensure jq is installed
# Ensure iproute2 (for 'ip' command) is installed

echo "--- Starting Ngrok tunnel in background ---"
if [ ! -f "$NGROK_CONFIG_PATH" ]; then
    echo "ERROR: Ngrok configuration file not found at $NGROK_CONFIG_PATH."
    echo "Please ensure ngrok is configured correctly and your authtoken is set."
    exit 1
fi

# Check if ngrok is already running
NGROK_PID=""
WEBHOOK_URL_RAW=""
if pgrep -x "ngrok" > /dev/null; then
    NGROK_PID=$(pgrep -x "ngrok" | head -n 1)
    echo "Ngrok is already running with PID: $NGROK_PID. Skipping start."
    # Try to get the URL from the existing log if ngrok was already running
    WEBHOOK_URL_RAW=$(jq -r 'select(.msg | startswith("started tunnel")) | .url' "$NGROK_OUTPUT_FILE" 2>/dev/null | grep -oP 'https://[^[:space:]]+' | head -n 1)
else
    nohup ngrok start n8n-tunnel --log-format json --log stdout > "$NGROK_OUTPUT_FILE" 2>&1 &
    NGROK_PID=$!
    echo "Ngrok started with PID: $NGROK_PID"

    echo "Waiting for Ngrok tunnel to establish (max 30 seconds)..."
    NGROK_WAIT_TIME=0
    MAX_WAIT_TIME=30

    while [ -z "$WEBHOOK_URL_RAW" ] && [ "$NGROK_WAIT_TIME" -lt "$MAX_WAIT_TIME" ]; do
        sleep 5
        WEBHOOK_URL_RAW=$(jq -r 'select(.msg | startswith("started tunnel")) | .url' "$NGROK_OUTPUT_FILE" 2>/dev/null | grep -oP 'https://[^[:space:]]+' | head -n 1)
        NGROK_WAIT_TIME=$((NGROK_WAIT_TIME + 5))
    done

    if [ -z "$WEBHOOK_URL_RAW" ]; then
        echo "ERROR: Could not get ngrok URL from $NGROK_OUTPUT_FILE within $MAX_WAIT_TIME seconds."
        echo "Dumping ngrok output for debugging:"
        cat "$NGROK_OUTPUT_FILE"
        echo "Terminating ngrok process (PID: $NGROK_PID)..."
        kill "$NGROK_PID" 2>/dev/null
        echo "Please check your ngrok configuration (ngrok.yml) and internet connection."
        exit 1
    fi
fi

WEBHOOK_URL="${WEBHOOK_URL_RAW}/"
echo "Ngrok URL obtained: $WEBHOOK_URL"

# Determine LXC IP Address
LXC_IP=""
# Get the main LAN IP of the container.
LXC_IP=$(ip -4 addr show scope global | grep -oP 'inet\s+\K[\d.]+' | head -n 1)

if [ -z "$LXC_IP" ]; then
    echo "WARNING: Could not automatically determine LXC IP address. Defaulting to 127.0.0.1 or please check manually."
    LXC_IP="127.0.0.1"
fi

# Check if n8n is already running
N8N_PID=""
N8N_LISTEN_ADDRESS="" 
N8N_ACCESSIBLE_IP="${LXC_IP}:${N8N_DEFAULT_PORT}" # This is the address accessible from outside the container

if pgrep -x "node" | xargs -r ps -f | grep -q "n8n start"; then
    N8N_PID=$(pgrep -x "node" | xargs -r ps -f | grep "n8n start" | awk '{print $2}' | head -n 1) # Get the PID
    echo "n8n is already running with PID: $N8N_PID. Skipping start."

    # Try to find the actual listening address from ss
    if ss -tuln | grep -q ":${N8N_DEFAULT_PORT}"; then
        N8N_LISTEN_ADDRESS=$(ss -tuln | grep ":${N8N_DEFAULT_PORT}" | awk '{print $4}' | head -n 1)
    fi
    if [ -z "$N8N_LISTEN_ADDRESS" ]; then
        N8N_LISTEN_ADDRESS="Unknown (likely 0.0.0.0:${N8N_DEFAULT_PORT})"
    fi

else
    export WEBHOOK_URL
    export N8N_DATA_FOLDER
    export N8N_RUNNERS_ENABLED=true
    export N8N_SECURE_COOKIE=false
    export N8N_BASIC_AUTH_ACTIVE=true
    export N8N_PORT=${N8N_DEFAULT_PORT}

    echo "--- Starting n8n ---"
    # Capture n8n's output to a file for potential debugging and for finding the address
    nohup n8n start > "$N8N_OUTPUT_FILE" 2>&1 &
    N8N_PID=$!

    echo "n8n started with PID: $N8N_PID in background."

    echo "Waiting for n8n to start (max 30 seconds)..."
    N8N_WAIT_TIME=0
    MAX_N8N_WAIT_TIME=30
    N8N_LISTEN_ADDRESS_FOUND=false

    while ! $N8N_LISTEN_ADDRESS_FOUND && [ "$N8N_WAIT_TIME" -lt "$MAX_N8N_WAIT_TIME" ]; do
        sleep 5
        # Look for the listening address in n8n's output file
        N8N_LISTEN_ADDRESS=$(grep -oP 'n8n listening on http[s]?://[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]{2,5}' "$N8N_OUTPUT_FILE" | head -n 1 | sed 's/n8n listening on //')
        if [ -n "$N8N_LISTEN_ADDRESS" ]; then
            N8N_LISTEN_ADDRESS_FOUND=true
        else
            # If specific log message not found, use ss to confirm port listening
            if ss -tuln | grep -q ":${N8N_DEFAULT_PORT}"; then
                N8N_LISTEN_ADDRESS=$(ss -tuln | grep ":${N8N_DEFAULT_PORT}" | awk '{print $4}' | head -n 1)
                N8N_LISTEN_ADDRESS_FOUND=true
            fi
        fi
        N8N_WAIT_TIME=$((N8N_WAIT_TIME + 5))
    done

    if ! $N8N_LISTEN_ADDRESS_FOUND; then
        echo "WARNING: Could not determine n8n's local listening address within $MAX_N8N_WAIT_TIME seconds."
        echo "Dumping n8n output for debugging:"
        cat "$N8N_OUTPUT_FILE"
        N8N_LISTEN_ADDRESS="Unknown (check $N8N_OUTPUT_FILE)"
    fi
fi

echo "n8n PID: $N8N_PID"
echo "n8n Listening Address (inside container): $N8N_LISTEN_ADDRESS"
echo "n8n Accessible IP (from host/network): http://${N8N_ACCESSIBLE_IP}" 

echo "Script finished."