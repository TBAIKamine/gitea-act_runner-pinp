# Security Hardening Applied

This act_runner setup now includes the following security measures:

## Implemented Security Features

### ✅ Point 3: Image Allowlisting
- **File**: `policy.json`
- **What it does**: Restricts container image pulls to trusted registries only
- **Allowed registries**:
  - docker.io (Docker Hub)
  - quay.io
  - ghcr.io (GitHub Container Registry)
  - gcr.io (Google Container Registry)
  - docker.gitea.com (Gitea official images)
- **All other registries**: REJECTED by default

### ✅ Point 4: Podman Image Trust Policy
- **File**: `policy.json` (copied to `/home/runner/.config/containers/policy.json`)
- **What it does**: Enforces registry restrictions at the Podman level
- **Effect**: Any attempt to pull from unlisted registries will fail

### ✅ Point 5: Network Isolation
- **File**: `entrypoint.sh`
- **What it does**: Creates an internal-only network named `restricted-net`
- **Effect**: Job containers CANNOT access the internet (prevents data exfiltration)
- **Configuration**: `config.yaml` sets `network: "restricted-net"`

### ✅ Point 8: Disable Privileged Operations
- **File**: `config.yaml`
- **Security options applied**:
  - `--security-opt=no-new-privileges`: Prevents privilege escalation
  - `--cap-drop=ALL`: Removes all Linux capabilities
  - `--read-only`: Root filesystem is immutable
  - `--tmpfs /tmp:rw,noexec,nosuid`: Writable /tmp but cannot execute binaries

### ✅ Point 10: Registry Mirror Configuration
- **File**: `containers.conf`
- **What it does**: Provides infrastructure for using a private registry mirror
- **Status**: Template provided (commented out by default)
- **To enable**: Uncomment and configure your mirror URL

### ✅ Recommended Security Setup
- **Files**: `config.yaml` and `config.secure.yaml`
- **Comprehensive hardening**:
  - Memory limit: 2GB (`-m 2g`)
  - CPU limit: 2 cores (`--cpus 2`)
  - Process limit: 100 processes (`--pids-limit 100`)
  - No volume mounts allowed (`valid_volumes: []`)
  - Read-only root filesystem
  - No new privileges allowed
  - All capabilities dropped

## Files Modified/Created

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
- ❌ No resource limits
- ❌ All capabilities enabled
- ❌ Writable filesystem

### After:
- ✅ Only trusted registries allowed
- ✅ No internet access (internal network only)
- ✅ Strict resource limits (2GB RAM, 2 CPUs, 100 processes)
- ✅ All capabilities dropped
- ✅ Read-only filesystem (except /tmp)
- ✅ No privilege escalation possible
- ✅ No volume mounts allowed

## Usage Notes

### If jobs need internet access:
You can disable network isolation by changing in `config.yaml`:
```yaml
network: ""  # Instead of "restricted-net"
```

### If jobs need volumes:
You can allow specific volumes in `config.yaml`:
```yaml
valid_volumes:
  - "/path/to/allowed/volume"
```

### If jobs need custom registries:
Edit `policy.json` to add your registry:
```json
"your-registry.com": [
  {
    "type": "insecureAcceptAnything"
  }
]
```

## Rebuild Required

To apply these changes, rebuild the container:
```bash
podman build -t act_runner:latest .
podman rm -f act_runner
./run.sh
```
