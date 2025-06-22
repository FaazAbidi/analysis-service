#!/bin/bash

# Build script for analysis-service Docker images
set -e

# Configuration
DOCKER_HUB_USERNAME="${DOCKER_HUB_USERNAME:-faazabidi}"
BASE_IMAGE_NAME="${DOCKER_HUB_USERNAME}/analysis-service-r-base"
APP_IMAGE_NAME="analysis-service"
TAG="${1:-latest}"
PUSH_TO_REGISTRY="${2:-false}"

echo "Building Docker images..."

# Build the R base image
echo "Step 1: Building R base image..."
docker build -f Dockerfile.base -t "${BASE_IMAGE_NAME}:${TAG}" .

# Push base image to registry if requested
if [ "$PUSH_TO_REGISTRY" = "true" ] || [ "$PUSH_TO_REGISTRY" = "push" ]; then
    echo "Step 2: Pushing R base image to Docker Hub..."
    docker push "${BASE_IMAGE_NAME}:${TAG}"
    echo "Base image pushed to: ${BASE_IMAGE_NAME}:${TAG}"
fi

# Build the main application image
echo "Step 3: Building main application image..."
docker build -f Dockerfile -t "${APP_IMAGE_NAME}:${TAG}" .

echo "Build completed successfully!"
echo "Base image: ${BASE_IMAGE_NAME}:${TAG}"
echo "App image: ${APP_IMAGE_NAME}:${TAG}"

# Optional: Show image sizes
echo ""
echo "Image sizes:"
docker images | grep -E "analysis-service-r-base|${APP_IMAGE_NAME}" | grep "${TAG}"

echo ""
echo "Usage examples:"
echo "  Build only: ./build.sh"
echo "  Build and push: ./build.sh latest push"
echo "  Build with custom tag: ./build.sh v1.0.0"
echo "  Build and push with custom tag: ./build.sh v1.0.0 push" 