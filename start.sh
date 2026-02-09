#!/bin/bash

set -e

# Ensure config directory exists
CONFIG_DIR="$HOME/.config/bitwarden"
mkdir -p "$CONFIG_DIR"/
IMAGE="bitwarden-cli:latest"
DOCKERFILE_PATH="bitwarden/Dockerfile"

echo "Cleaning up any existing Bitwarden container..."
docker rm -f bitwarden
docker image rm bitwarden-cli

echo "Building and running Bitwarden CLI..."
docker build -t "$IMAGE" -f "$DOCKERFILE_PATH" .
docker run -d \
    --name bitwarden \
    -v "$CONFIG_DIR":/root/.config/Bitwarden\ CLI \
    $IMAGE

docker exec bitwarden /scripts/login.sh