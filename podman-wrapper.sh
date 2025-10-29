#!/bin/sh
# Podman wrapper script to enforce image allowlist
# Only allows Ubuntu LTS (Long Term Support) images

# Define allowed Ubuntu LTS images
# Updated as of 2025: 24.04 (latest LTS), 22.04, 20.04
ALLOWED_IMAGES="
docker\.io/library/ubuntu:24\.04
docker\.io/library/ubuntu:22\.04
docker\.io/library/ubuntu:20\.04
docker\.io/ubuntu:24\.04
docker\.io/ubuntu:22\.04
docker\.io/ubuntu:20\.04
ubuntu:24\.04
ubuntu:22\.04
ubuntu:20\.04
docker\.io/library/ubuntu:latest
docker\.io/ubuntu:latest
ubuntu:latest
"

# Function to check if image is allowed
check_image_allowed() {
    local image="$1"
    
    # Skip check for non-image commands
    if [ -z "$image" ]; then
        return 0
    fi
    
    # Check against allowlist
    for pattern in $ALLOWED_IMAGES; do
        if echo "$image" | grep -qE "^${pattern}$"; then
            return 0
        fi
    done
    
    # Image not allowed
    echo "❌ ERROR: Image '$image' is NOT allowed!" >&2
    echo "" >&2
    echo "Only Ubuntu LTS images are permitted:" >&2
    echo "  ✅ ubuntu:24.04 (Noble Numbat - Latest LTS)" >&2
    echo "  ✅ ubuntu:22.04 (Jammy Jellyfish)" >&2
    echo "  ✅ ubuntu:20.04 (Focal Fossa)" >&2
    echo "  ✅ ubuntu:latest (alias for latest LTS)" >&2
    echo "" >&2
    echo "Blocked image: $image" >&2
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
