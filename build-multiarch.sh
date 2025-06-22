#!/bin/bash

# Multi-architecture build script for Railway compatibility
set -e

DOCKER_HUB_USERNAME="faazabidi"
BASE_IMAGE_NAME="${DOCKER_HUB_USERNAME}/analysis-service-r-base"
TAG="${1:-latest}"

echo "Building multi-architecture R base image for Railway compatibility..."

# Create and use a new builder that supports multi-platform builds
echo "Setting up multi-platform builder..."
docker buildx create --name multibuilder --use --bootstrap 2>/dev/null || docker buildx use multibuilder

# Build and push multi-architecture base image
echo "Building and pushing multi-arch R base image..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -f Dockerfile.base \
    -t "${BASE_IMAGE_NAME}:${TAG}" \
    --push \
    .

echo ""
echo "✅ Multi-architecture base image built and pushed!"
echo "Image: ${BASE_IMAGE_NAME}:${TAG}"
echo "Platforms: linux/amd64, linux/arm64"
echo ""
echo "This image will now work on:"
echo "  - Your Mac (ARM64)"
echo "  - Railway (AMD64)"
echo "  - Any other platform"

# Clean up builder (optional)
# docker buildx rm multibuilder 