#!/bin/bash

# Build the image
podman build -t act_runner:latest .

# Run the container with environment variables
# Replace these values with your actual Gitea instance details
podman run -d \
  --name act_runner \
  --restart=always \
  --security-opt label=disable \
  --device /dev/fuse \
  -e GITEA_INSTANCE_URL="https://your-gitea-instance.com" \
  -e GITEA_RUNNER_REGISTRATION_TOKEN="your_registration_token_here" \
  -e GITEA_RUNNER_NAME="my-podman-runner" \
  -e GITEA_RUNNER_LABELS="ubuntu-latest:docker://docker.gitea.com/runner-images:ubuntu-latest" \
  -v act_runner_data:/home/runner/data:Z \
  -v act_runner_containers:/home/runner/.local/share/containers:Z \
  act_runner:latest

echo "act_runner container started with --restart=always policy"
echo "Check logs with: podman logs -f act_runner"
