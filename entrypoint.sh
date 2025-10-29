#!/bin/bash
set -e

echo "Starting act_runner with rootless Podman support..."

# Start Podman service in rootless mode
mkdir -p /run/user/1000
export XDG_RUNTIME_DIR=/run/user/1000

# Start podman system service in the background
echo "Starting Podman service..."
podman system service --time=0 unix:///run/user/1000/podman/podman.sock &
PODMAN_PID=$!

# Wait for Podman socket to be available
echo "Waiting for Podman socket..."
for i in {1..30}; do
    if [ -S /run/user/1000/podman/podman.sock ]; then
        echo "Podman socket is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: Podman socket did not become available"
        exit 1
    fi
    sleep 1
done

# Test Podman connection
echo "Testing Podman connection..."
podman info > /dev/null 2>&1 || {
    echo "ERROR: Podman is not responding"
    exit 1
}

echo "Podman is ready"

# Cleanup function
cleanup() {
    echo "Shutting down..."
    if [ ! -z "$PODMAN_PID" ]; then
        kill $PODMAN_PID 2>/dev/null || true
    fi
    exit 0
}

trap cleanup SIGTERM SIGINT

# Check if runner is already registered
if [ ! -f /home/runner/data/.runner ]; then
    echo "Runner not registered. Please register first."
    echo "You can register using environment variables:"
    echo "  GITEA_INSTANCE_URL - Your Gitea instance URL"
    echo "  GITEA_RUNNER_REGISTRATION_TOKEN - Your runner registration token"
    echo "  GITEA_RUNNER_NAME - Runner name (optional)"
    echo "  GITEA_RUNNER_LABELS - Runner labels (optional)"
    
    if [ ! -z "$GITEA_INSTANCE_URL" ] && [ ! -z "$GITEA_RUNNER_REGISTRATION_TOKEN" ]; then
        echo "Registering runner..."
        
        REGISTER_CMD="/usr/local/bin/act_runner register \
            --config /home/runner/.config/act_runner/config.yaml \
            --instance ${GITEA_INSTANCE_URL} \
            --token ${GITEA_RUNNER_REGISTRATION_TOKEN} \
            --no-interactive"
        
        if [ ! -z "$GITEA_RUNNER_NAME" ]; then
            REGISTER_CMD="${REGISTER_CMD} --name ${GITEA_RUNNER_NAME}"
        fi
        
        if [ ! -z "$GITEA_RUNNER_LABELS" ]; then
            REGISTER_CMD="${REGISTER_CMD} --labels ${GITEA_RUNNER_LABELS}"
        fi
        
        eval $REGISTER_CMD
        echo "Runner registered successfully"
    else
        echo "ERROR: GITEA_INSTANCE_URL and GITEA_RUNNER_REGISTRATION_TOKEN are required for registration"
        exit 1
    fi
fi

# Run act_runner with ephemeral flag
echo "Starting act_runner daemon in ephemeral mode..."
exec /usr/local/bin/act_runner daemon \
    --config /home/runner/.config/act_runner/config.yaml \
    --ephemeral
