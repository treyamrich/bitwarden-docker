#!/bin/bash

echo "Cleaning up any existing Bitwarden container..."
docker rm -f bitwarden
docker image rm bitwarden-cli

set -e
# Ensure config directory exists
CONFIG_DIR="$HOME/.config/bitwarden"
mkdir -p "$CONFIG_DIR"/
IMAGE="bitwarden-cli:latest"

echo "Building and running Bitwarden CLI..."
docker build -t "$IMAGE" .
docker run -d \
    --name bitwarden \
    -v "$CONFIG_DIR":/root/.config/Bitwarden\ CLI \
    $IMAGE

docker exec bitwarden /scripts/login.sh