#!/bin/bash

# Setup script for pushing R base image to Docker Hub for Railway deployment
set -e

echo "=== Railway Deployment Setup ==="
echo ""

# Get Docker Hub username
read -p "Enter your Docker Hub username: " DOCKER_HUB_USERNAME

if [ -z "$DOCKER_HUB_USERNAME" ]; then
    echo "Error: Docker Hub username is required"
    exit 1
fi

# Update Dockerfile references
echo "Updating Dockerfile references..."
sed -i.bak "s/your-dockerhub-username/$DOCKER_HUB_USERNAME/g" Dockerfile
sed -i.bak "s/your-dockerhub-username/$DOCKER_HUB_USERNAME/g" Dockerfile.railway
sed -i.bak "s/your-dockerhub-username/$DOCKER_HUB_USERNAME/g" build.sh

echo "Updated files with Docker Hub username: $DOCKER_HUB_USERNAME"

# Login to Docker Hub
echo ""
echo "Please login to Docker Hub:"
docker login

# Build and push the base image
echo ""
echo "Building and pushing R base image..."
export DOCKER_HUB_USERNAME="$DOCKER_HUB_USERNAME"
./build.sh latest push

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Your R base image is now available at: $DOCKER_HUB_USERNAME/analysis-service-r-base:latest"
echo ""
echo "Railway Setup Instructions:"
echo "1. In your Railway project, set the Dockerfile to: Dockerfile.railway"
echo "2. Railway will now use your pre-built R base image instead of building from scratch"
echo "3. Build time should be reduced from 20+ minutes to under 5 minutes"
echo ""
echo "To update the base image in the future:"
echo "  ./build.sh latest push" 