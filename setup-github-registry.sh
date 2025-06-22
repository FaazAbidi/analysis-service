#!/bin/bash

# Setup script for pushing R base image to GitHub Container Registry for Railway deployment
set -e

echo "=== Railway Deployment Setup (GitHub Container Registry) ==="
echo ""

# Get GitHub username
read -p "Enter your GitHub username: " GITHUB_USERNAME

if [ -z "$GITHUB_USERNAME" ]; then
    echo "Error: GitHub username is required"
    exit 1
fi

# Update Dockerfile references for GitHub Container Registry
echo "Updating Dockerfile references..."
BASE_IMAGE="ghcr.io/$GITHUB_USERNAME/analysis-service-r-base"

sed -i.bak "s|your-dockerhub-username/analysis-service-r-base|$BASE_IMAGE|g" Dockerfile
sed -i.bak "s|your-dockerhub-username/analysis-service-r-base|$BASE_IMAGE|g" Dockerfile.railway

echo "Updated files with GitHub Container Registry: $BASE_IMAGE"

# Login to GitHub Container Registry
echo ""
echo "Please login to GitHub Container Registry:"
echo "You'll need a GitHub Personal Access Token with 'write:packages' permission"
echo "Create one at: https://github.com/settings/tokens"
echo ""
read -p "Enter your GitHub Personal Access Token: " -s GITHUB_TOKEN
echo ""

echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin

# Build and push the base image
echo ""
echo "Building and pushing R base image to GitHub Container Registry..."
docker build -f Dockerfile.base -t "$BASE_IMAGE:latest" .
docker push "$BASE_IMAGE:latest"

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Your R base image is now available at: $BASE_IMAGE:latest"
echo ""
echo "Railway Setup Instructions:"
echo "1. In your Railway project, set the Dockerfile to: Dockerfile.railway"
echo "2. Railway will now use your pre-built R base image instead of building from scratch"
echo "3. Build time should be reduced from 20+ minutes to under 5 minutes" 