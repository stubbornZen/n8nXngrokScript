#!/bin/bash

# SET THE STATIC NGROK DOMAIN
export NGROK_DOMAIN="your-ngrok-static-domain-here"
export N8N_DEFAULT_PORT=5678
export WEBHOOK_URL="https://${NGROK_DOMAIN}"

echo "--- Using Static Ngrok URL: $WEBHOOK_URL ---"

# START NGROK IN BACKGROUND
echo "--- Starting Ngrok tunnel ---"
if pgrep -x "ngrok" > /dev/null; then
    echo "Ngrok is already running. Skipping start."
else
    nohup ngrok http --domain="$NGROK_DOMAIN" $N8N_DEFAULT_PORT > /dev/null 2>&1 &
    NGROK_PID=$!
    echo "Ngrok started with PID: $NGROK_PID"
    sleep 5
fi

# START N8N
echo "--- Starting n8n ---"
export N8N_HOST=localhost
export N8N_PROTOCOL=http
export N8N_PORT=${N8N_DEFAULT_PORT}
export NODE_ENV=production
export N8N_DATA_FOLDER="/root/.n8n"
export WEBHOOK_TUNNEL_URL="$WEBHOOK_URL"

if pgrep -f "n8n start" > /dev/null; then
    echo "n8n is already running. Skipping start."
else
    nohup n8n start > /dev/null 2>&1 &
    N8N_PID=$!
    echo "n8n started with PID: $N8N_PID"
fi

echo "Script finished. Webhook URL: $WEBHOOK_URL"