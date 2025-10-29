# Act Runner with Rootless Podman-in-Podman

A containerized act_runner setup using Alpine Linux with rootless Podman-in-Podman (PinP) support for running Gitea Actions.

## Features

- ✅ **Rootless Podman-in-Podman**: Both outer and inner containers run without root privileges
- ✅ **Alpine-based**: Minimal image size using Alpine Linux
- ✅ **Ephemeral Mode**: Runner automatically uses `--ephemeral` flag for one-time job execution
- ✅ **Auto-restart**: Container configured with `--restart=always` policy
- ✅ **Automatic Registration**: Registers runner on first start using environment variables

## Prerequisites

- Podman installed on your host system
- Access to a Gitea instance with Actions enabled
- Runner registration token from your Gitea instance

## Quick Start

### 1. Get Your Runner Token

1. Log in to your Gitea instance
2. Navigate to: `Site Administration` → `Actions` → `Runners`
3. Click "Create new runner" and copy the registration token

### 2. Build the Image

```bash
podman build -t act_runner:latest .
```

### 3. Run with Podman

#### Option A: Using the run script

Edit `run.sh` to set your Gitea instance URL and token, then:

```bash
chmod +x run.sh
./run.sh
```

#### Option B: Manual run command

```bash
podman run -d \
  --name act_runner \
  --restart=always \
  --security-opt label=disable \
  --device /dev/fuse \
  -e GITEA_INSTANCE_URL="https://your-gitea-instance.com" \
  -e GITEA_RUNNER_REGISTRATION_TOKEN="your_token_here" \
  -e GITEA_RUNNER_NAME="my-podman-runner" \
  -e GITEA_RUNNER_LABELS="ubuntu-latest:docker://docker.gitea.com/runner-images:ubuntu-latest" \
  -v ./data:/home/runner/data:Z \
  -v ./containers:/home/runner/.local/share/containers:Z \
  act_runner:latest
```

#### Option C: Using Podman Compose

1. Copy the environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your Gitea details

3. Run with compose:
   ```bash
   podman compose up -d
   ```

## Environment Variables

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `GITEA_INSTANCE_URL` | Yes | Your Gitea instance URL | `https://gitea.example.com` |
| `GITEA_RUNNER_REGISTRATION_TOKEN` | Yes | Runner registration token from Gitea | `abc123...` |
| `GITEA_RUNNER_NAME` | No | Custom name for the runner | `my-runner` |
| `GITEA_RUNNER_LABELS` | No | Runner labels (comma-separated) | `ubuntu-latest:docker://...` |

## Configuration

### Container Configuration

The runner is configured via `config.yaml` with the following key settings:

- **Podman Socket**: Uses rootless Podman socket at `/run/user/1000/podman/podman.sock`
- **Storage**: Persistent data stored in `/home/runner/data`
- **Non-privileged**: Runs without privileged mode for security
- **Cache**: Enabled by default for faster job execution

### Rootless Podman Setup

The container includes:

- **User**: Non-root `runner` user (UID 1000)
- **Subuid/Subgid**: Configured for user namespace mapping (100000:65536)
- **Storage Driver**: Overlay with fuse-overlayfs for rootless operation
- **Cgroup Manager**: cgroupfs for rootless compatibility

## Architecture

```
┌─────────────────────────────────────────┐
│ Host System (Podman)                    │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ Outer Container (rootless)        │ │
│  │ - Alpine Linux                    │ │
│  │ - act_runner (--ephemeral)        │ │
│  │ - Podman (daemonless, rootless)   │ │
│  │                                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │ Inner Container (rootless)  │ │ │
│  │  │ - Job execution environment │ │ │
│  │  │ - Uses Podman-in-Podman     │ │ │
│  │  └─────────────────────────────┘ │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## Managing the Runner

### View Logs

```bash
podman logs -f act_runner
```

### Stop the Runner

```bash
podman stop act_runner
```

### Remove the Runner

```bash
podman rm -f act_runner
```

### Restart the Runner

```bash
podman restart act_runner
```

## Volumes

Two directories are mounted from the host:

1. **./data**: Stores runner registration and cache data
   - Mounted to: `/home/runner/data`
   - Contains: `.runner` file, cache directory

2. **./containers**: Stores Podman images and containers
   - Mounted to: `/home/runner/.local/share/containers`
   - Contains: Image layers, container storage

## Security Considerations

- ✅ **Rootless**: Both outer and inner containers run as non-root
- ✅ **Ephemeral**: Runner automatically deregisters after each job
- ✅ **Isolated**: Each container has its own user namespace
- ⚠️ **SELinux**: `--security-opt label=disable` is required for Podman-in-Podman
- ⚠️ **Device Access**: `/dev/fuse` is required for overlay filesystem

## Troubleshooting

### Container won't start

Check if `/dev/fuse` is available:
```bash
ls -l /dev/fuse
```

### Podman socket not available

Check logs for Podman service startup:
```bash
podman logs act_runner | grep -i podman
```

### Runner not registering

Verify environment variables are set correctly:
```bash
podman exec act_runner env | grep GITEA
```

### Jobs failing to run

Check inner Podman status:
```bash
podman exec act_runner podman info
```

## Advanced Configuration

### Custom Labels

To run jobs with specific labels, set them during registration:

```bash
-e GITEA_RUNNER_LABELS="ubuntu-latest:docker://docker.gitea.com/runner-images:ubuntu-latest"
```

### Understanding Runner Labels vs Images

**Important**: The image in `GITEA_RUNNER_LABELS` is a **default**, not a restriction.

```bash
# This registration:
-e GITEA_RUNNER_LABELS="ubuntu-latest:docker://docker.gitea.com/runner-images:ubuntu-latest"

# Means:
# - Label: "ubuntu-latest" (matches workflows with runs-on: ubuntu-latest)
# - Default image: docker.gitea.com/runner-images:ubuntu-latest (used if workflow doesn't specify container)
```

**About Gitea's Runner Images:**

- `docker.gitea.com/runner-images:ubuntu-latest` is **NOT** Docker Hub's official Ubuntu
- It's **Gitea's pre-built image** with CI/CD tools (similar to GitHub Actions runners)
- Includes: Git, Node.js, Python, Docker, common build tools
- Source: https://gitea.com/gitea/runner-images

**Registry Restriction - IMPORTANT:**

This runner is configured to **ONLY accept images from Gitea's official registry** (`docker.gitea.com`).

```yaml
# ✅ ALLOWED - Gitea registry images
jobs:
  build:
    runs-on: ubuntu-latest
    # No container specified - uses label default
    steps:
      - run: echo "Using Gitea's runner image"

  deploy:
    runs-on: ubuntu-latest
    container:
      image: docker.gitea.com/gitea/runner-images:ubuntu-22.04
    steps:
      - run: npm install

# ❌ BLOCKED - Docker Hub and other registries
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: ubuntu:22.04  # ❌ FAILS
    # Error: Image 'docker.io/library/ubuntu:22.04' is NOT from an allowed registry!

  lint:
    runs-on: ubuntu-latest
    container:
      image: node:20-alpine  # ❌ FAILS
    # Error: Image 'docker.io/library/node:20-alpine' is NOT from an allowed registry!

  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/owner/repo:latest  # ❌ FAILS
    # Error: Image 'ghcr.io/owner/repo:latest' is NOT from an allowed registry!
```

**Why?** 

- Docker Hub (docker.io) allows **anyone** to upload images without verification
- Malicious actors can create images with backdoors, cryptominers, or exploits
- By restricting to Gitea's official registry, only vetted images are used
- This prevents workflows from pulling and executing untrusted code

**Available Gitea Runner Images:**

- `docker.gitea.com/gitea/runner-images:ubuntu-latest`
- `docker.gitea.com/gitea/runner-images:ubuntu-22.04`
- `docker.gitea.com/gitea/runner-images:ubuntu-20.04`
- See full list: https://gitea.com/gitea/runner-images

**Security Note**: Registry restriction is enforced by [`policy.json`](policy.json) and [`podman-wrapper.sh`](podman-wrapper.sh) at the container runtime level. Even if a workflow requests a different image, it will be blocked before execution.

### Resource Limits

Add resource constraints to the container:

```bash
podman run -d \
  --name act_runner \
  --memory=4g \
  --cpus=2 \
  ... # other options
```

### Custom Config

To use a custom config file, mount it:

```bash
-v /path/to/custom-config.yaml:/home/runner/.config/act_runner/config.yaml:Z,ro
```

## Files Overview

- `Dockerfile` - Multi-stage build for act_runner with Podman
- `config.yaml` - Act runner configuration with Podman settings
- `entrypoint.sh` - Startup script that initializes Podman and runs act_runner
- `containers.conf` - Podman container runtime configuration
- `storage.conf` - Podman storage configuration for rootless mode
- `run.sh` - Helper script to run the container
- `compose.yaml` - Compose file for easy deployment

## References

- [Act Runner Repository](https://gitea.com/gitea/act_runner)
- [Gitea Actions Documentation](https://docs.gitea.com/usage/actions/overview)
- [Podman Rootless](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)

## License

This configuration is provided as-is for use with act_runner. Please refer to the [act_runner license](https://gitea.com/gitea/act_runner/src/branch/main/LICENSE) for the runner itself.
