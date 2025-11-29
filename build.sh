#!/bin/bash
# Build script for wotin

set -e

echo "Building wotin..."

# Create build directory if it doesn't exist
mkdir -p build

# Build in debug mode by default
MODE=${1:-debug}

if [ "$MODE" = "release" ]; then
    echo "Building in release mode..."
    odin build src -out:build/wotin -o:speed
else
    echo "Building in debug mode..."
    odin build src -out:build/wotin -debug
fi

echo "Build complete! Binary located at: build/wotin"
