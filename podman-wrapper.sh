#!/bin/sh
# Podman wrapper script to enforce Gitea registry-only image policy
# Only allows images from docker.gitea.com

# Define allowed image pattern - Gitea registry only
ALLOWED_PATTERN="^docker\.gitea\.com/"

# Function to check if image is allowed
check_image_allowed() {
    local image="$1"
    
    # Skip check for non-image commands
    if [ -z "$image" ]; then
        return 0
    fi
    
    # Check if image is from Gitea registry
    if echo "$image" | grep -qE "$ALLOWED_PATTERN"; then
        return 0
    fi
    
    # Image not allowed
    echo "" >&2
    echo "❌ ERROR: Image '$image' is NOT from an allowed registry!" >&2
    echo "" >&2
    echo "Only Gitea official registry images are permitted:" >&2
    echo "  ✅ docker.gitea.com/gitea/runner-images:ubuntu-latest" >&2
    echo "  ✅ docker.gitea.com/gitea/runner-images:ubuntu-22.04" >&2
    echo "  ✅ docker.gitea.com/gitea/runner-images:ubuntu-20.04" >&2
    echo "  ✅ docker.gitea.com/your-org/your-custom-image:tag" >&2
    echo "" >&2
    echo "Blocked registries:" >&2
    echo "  ❌ docker.io (Docker Hub)" >&2
    echo "  ❌ ghcr.io (GitHub Container Registry)" >&2
    echo "  ❌ quay.io (Red Hat Quay)" >&2
    echo "  ❌ gcr.io (Google Container Registry)" >&2
    echo "  ❌ ubuntu:22.04 (defaults to Docker Hub)" >&2
    echo "  ❌ node:20-alpine (defaults to Docker Hub)" >&2
    echo "" >&2
    echo "Attempted image: $image" >&2
    echo "" >&2
    return 1
}

# Extract image name from command arguments
IMAGE=""
COMMAND=""

# Parse arguments to find the image
i=1
for arg in "$@"; do
    case "$arg" in
        run|pull|create)
            COMMAND="$arg"
            # Next non-flag argument after run/pull/create is the image
            j=$((i + 1))
            for next_arg in "$@"; do
                if [ $j -eq 1 ]; then
                    j=$((j - 1))
                    continue
                fi
                j=$((j - 1))
                if [ $j -eq 0 ]; then
                    # Skip flags
                    case "$next_arg" in
                        -*) continue ;;
                        *) IMAGE="$next_arg"; break ;;
                    esac
                fi
            done
            break
            ;;
    esac
    i=$((i + 1))
done

# If this is an image-related command, check the allowlist
if [ -n "$COMMAND" ] && [ -n "$IMAGE" ]; then
    if ! check_image_allowed "$IMAGE"; then
        exit 1
    fi
fi

# Execute real podman with all original arguments
exec /usr/bin/podman.real "$@"
