#!/bin/bash
# Build script for test data generator

set -e

echo "Building test data generator..."

mkdir -p tools/build

odin build tools/generate_test_data.odin -file -out:tools/build/generate_test_data -debug

echo "Build complete! Run with: ./tools/build/generate_test_data"
