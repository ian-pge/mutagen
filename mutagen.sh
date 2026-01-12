#!/usr/bin/env bash

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if mutagen is installed
if ! command_exists mutagen; then
  echo "Error: mutagen is not installed. Please install it first."
  exit 1
fi

# Prompt for RunPod IP and Port
read -p "Enter RunPod IP address: " RUNPOD_IP
read -p "Enter RunPod Port: " RUNPOD_PORT
read -p "Enter Web Port to forward (e.g., 7007): " WEB_PORT

# Define paths
LOCAL_PATH="/home/ian/Perso/startup/datasets/mutagen/"
REMOTE_PATH="/workspace/mutagen"
SYNC_SESSION_NAME="runpod-mutagen-sync"
FORWARD_SESSION_NAME="runpod-mutagen-forward"

# SSH Connection Target (root@IP:PORT)
SSH_TARGET="root@${RUNPOD_IP}:${RUNPOD_PORT}"

# Remote Path for Sync (SSH_TARGET:PATH)
REMOTE_SYNC_URL="${SSH_TARGET}:${REMOTE_PATH}"

echo "Configuring Mutagen..."
echo "Local Path: $LOCAL_PATH"
echo "Remote Sync: $REMOTE_SYNC_URL"
echo "Forwarding: localhost:$WEB_PORT -> remote:localhost:$WEB_PORT"

# Verify SSH connectivity
echo "Verifying SSH connection..."
if ! ssh -q -p "$RUNPOD_PORT" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$RUNPOD_IP" exit; then
  echo "Error: Cannot connect to RunPod via SSH."
  exit 1
fi

# Ensure Clean State
# We stop/start the daemon to avoid "device busy" errors from stale sockets
mutagen daemon stop >/dev/null 2>&1
sleep 1
mutagen daemon start
sleep 1

# --- Sync Session ---
if mutagen sync list "$SYNC_SESSION_NAME" >/dev/null 2>&1; then
  echo "Terminating existing sync session '$SYNC_SESSION_NAME'..."
  mutagen sync terminate "$SYNC_SESSION_NAME"
  sleep 1
fi

echo "Creating sync session..."
if ! mutagen sync create --name "$SYNC_SESSION_NAME" "$LOCAL_PATH" "$REMOTE_SYNC_URL"; then
    echo "Error: Failed to create mutagen sync session."
    exit 1
fi

# --- Forwarding Session ---
if mutagen forward list "$FORWARD_SESSION_NAME" >/dev/null 2>&1; then
  echo "Terminating existing forward session '$FORWARD_SESSION_NAME'..."
  mutagen forward terminate "$FORWARD_SESSION_NAME"
  sleep 1
fi

echo "Creating forward session..."
if ! mutagen forward create --name "$FORWARD_SESSION_NAME" "tcp:localhost:$WEB_PORT" "${SSH_TARGET}:tcp:localhost:$WEB_PORT"; then
    echo "Error: Failed to create mutagen forward session."
    echo "Note: Ensure the SSH connection string is correct and Mutagen supports it."
    exit 1
fi

echo "Forwarding established: http://localhost:$WEB_PORT"

# Monitor the session
echo "Monitoring sync session (Forwarding is active in background)."
mutagen sync monitor "$SYNC_SESSION_NAME"
