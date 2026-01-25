#!/bin/sh
set -e

# Get opencode version from versions.yml
OPENCODE_VERSION=$(yq e '.opencode' /versions.yml)

echo "Setting up opencode v${OPENCODE_VERSION} in seed directory..."

# Create seed directory if it doesn't exist
mkdir -p /opt/mise-seed

# Set mise data dir to seed location for install
export MISE_DATA_DIR=/opt/mise-seed

# Activate mise
eval "$(mise activate bash)"

# Install opencode
echo "Installing opencode v${OPENCODE_VERSION}..."
mise install opencode@${OPENCODE_VERSION}

echo "Setup complete! opencode v${OPENCODE_VERSION} is now in /opt/mise-seed"
echo "This will be synced to persistent volume on container startup via init container."
