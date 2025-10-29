# Security Hardening Applied

This act_runner setup now includes the following security measures:

## Implemented Security Features

### ✅ Registry Restriction - Gitea Only (policy.json + podman-wrapper.sh)

**Most Important Security Feature**

**Files**: `policy.json`, `podman-wrapper.sh`

**What it does**: Restricts container image pulls to Gitea's official registry ONLY

**Allowed registries**:
  - ✅ docker.gitea.com (Gitea official registry)

**Blocked registries (ALL others)**:
  - ❌ docker.io (Docker Hub - public, anyone can upload)
  - ❌ ghcr.io (GitHub Container Registry)
  - ❌ quay.io (Red Hat Quay)
  - ❌ gcr.io (Google Container Registry)
  - ❌ Any other registry

**Why this matters**: Docker Hub allows anyone to upload images. Malicious actors could create images with backdoors, cryptominers, or exploits. By restricting to Gitea's registry, only vetted official images can be used.

**Example allowed images**:
  - ✅ `docker.gitea.com/gitea/runner-images:ubuntu-latest`
  - ✅ `docker.gitea.com/gitea/runner-images:ubuntu-22.04`
  - ✅ `docker.gitea.com/gitea/runner-images:ubuntu-20.04`
  - ✅ `docker.gitea.com/your-org/your-custom-image:v1.0`

**Example blocked images**:
  - ❌ `ubuntu:22.04` (defaults to docker.io/library/ubuntu:22.04)
  - ❌ `node:20-alpine` (defaults to docker.io/library/node:20-alpine)
  - ❌ `ghcr.io/owner/repo:latest`
  - ❌ `malicious-user/cryptominer:latest`

### ✅ Point 4: Podman Image Trust Policy
- **File**: `policy.json` (copied to `/home/runner/.config/containers/policy.json`)
- **What it does**: Enforces registry restrictions at the Podman level
- **Configuration**: Only `docker.gitea.com` is whitelisted, all others rejected
- **Effect**: Any attempt to pull from unlisted registries will fail

### ✅ Point 5: Network Access (Unrestricted)

### ✅ Point 8: Disable Privileged Operations
- **File**: `config.yaml`
- **Security options applied**:
  - `--security-opt=no-new-privileges`: Prevents privilege escalation
  - `--cap-drop=ALL`: Removes all Linux capabilities
  - `--security-opt seccomp=/home/runner/.config/seccomp-profile.json`: Syscall filtering

### ✅ Point 10: Registry Configuration
- **File**: `containers.conf`
- **What it does**: Configures Podman registry settings
- **Current setting**: Search list includes only `docker.gitea.com`
- **Status**: Configured for Gitea-only access

### ✅ Additional Security: Seccomp Profile
- **File**: `seccomp-profile.json`
- **What it does**: Blocks dangerous system calls that could be used for container escape
- **Blocked syscalls**: mount, umount, ptrace, reboot, kexec_load, init_module, delete_module, and more
- **Applied to**: Inner job containers through config.yaml

## Security Configuration Summary

1. ✅ `policy.json` - NEW: Registry allowlist policy
2. ✅ `Dockerfile` - UPDATED: Includes policy.json
3. ✅ `entrypoint.sh` - UPDATED: Creates restricted network
4. ✅ `config.yaml` - UPDATED: Security hardening applied
5. ✅ `config.secure.yaml` - NEW: Fully documented secure config
6. ✅ `containers.conf` - UPDATED: Registry configuration template

## Security Posture

### Before:
- ❌ Any registry allowed
- ❌ Full internet access
- ❌ No syscall filtering
- ❌ All capabilities enabled

### After:
- ✅ **Only Gitea registry allowed** (docker.gitea.com)
- ✅ Full internet access (per user requirement)
- ✅ Seccomp syscall filtering active
- ✅ All capabilities dropped
- ✅ No privilege escalation possible
- ✅ No volume mounts allowed
- ✅ Rootless double-isolation (outer + inner namespaces)

## Usage Notes

### Using Gitea Runner Images

To use workflows with this runner, specify Gitea registry images:

```yaml
# ✅ CORRECT - Uses Gitea's official runner image
jobs:
  build:
    runs-on: ubuntu-latest
    # No container specified - uses label default
    steps:
      - run: echo "Using docker.gitea.com/gitea/runner-images:ubuntu-latest"

# ✅ CORRECT - Explicitly uses Gitea registry
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: docker.gitea.com/gitea/runner-images:ubuntu-22.04
    steps:
      - run: npm install

# ❌ WRONG - Docker Hub blocked
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ubuntu:22.04  # FAILS - not from docker.gitea.com
```

### If Jobs Need Volumes

You can allow specific volumes in `config.yaml`:
```yaml
valid_volumes:
  - "/path/to/allowed/volume"
```

**Warning**: Allowing volumes reduces security. Only allow if absolutely necessary.

## Rebuild Required

To apply these changes, rebuild the container:
```bash
podman build -t act_runner:latest .
podman rm -f act_runner
./run.sh
```
