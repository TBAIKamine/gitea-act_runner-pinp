# Rootless Podman-in-Podman Alpine image for act_runner
FROM alpine:3.20

# Install required packages
RUN apk add --no-cache \
    ca-certificates \
    curl \
    git \
    podman \
    fuse-overlayfs \
    shadow-uidmap \
    su-exec \
    bash \
    && rm -rf /var/cache/apk/*

# Download and install act_runner
ARG ACT_RUNNER_VERSION=0.2.13
RUN curl -L "https://dl.gitea.com/act_runner/${ACT_RUNNER_VERSION}/act_runner-${ACT_RUNNER_VERSION}-linux-amd64" -o /usr/local/bin/act_runner \
    && chmod +x /usr/local/bin/act_runner

# Create a non-root user for running act_runner
RUN adduser -D -u 1000 runner \
    && echo "runner:100000:65536" > /etc/subuid \
    && echo "runner:100000:65536" > /etc/subgid

# Create necessary directories
RUN mkdir -p /home/runner/.config/act_runner \
    && mkdir -p /home/runner/.local/share/containers \
    && mkdir -p /home/runner/data \
    && chown -R runner:runner /home/runner

# Configure Podman for rootless operation
COPY containers.conf /etc/containers/containers.conf
COPY storage.conf /etc/containers/storage.conf

# Set up Podman for the runner user
USER runner
WORKDIR /home/runner

# Initialize Podman storage
RUN podman info > /dev/null 2>&1 || true

# Copy configuration and entrypoint
USER root
COPY config.yaml /home/runner/.config/act_runner/config.yaml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && chown runner:runner /home/runner/.config/act_runner/config.yaml

USER runner

VOLUME ["/home/runner/data", "/home/runner/.local/share/containers"]

ENTRYPOINT ["/entrypoint.sh"]
