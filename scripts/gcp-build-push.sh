#!/bin/bash
# Builds images and pushes them to Docker Hub
#
# Usage:
#   1. Set REGISTRY=yourusername/ in .env.gcp
#   2. docker login
#   3. bash scripts/gcp-build-push.sh
#
# Prerequisite: docker login must be completed first

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load .env.gcp
ENV_FILE="$PROJECT_DIR/.env.gcp"
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env.gcp not found. Create it and set REGISTRY and TAG."
  exit 1
fi
source "$ENV_FILE"

if [ -z "$REGISTRY" ] || [[ "$REGISTRY" == *"DOCKER_HUB"* ]]; then
  echo "ERROR: REGISTRY is not set in .env.gcp."
  echo "Example: REGISTRY=johndoe/"
  exit 1
fi

TAG="${TAG:-blue}"

echo "================================================"
echo " Banking Microservices — Build & Push"
echo " Registry: ${REGISTRY}  |  Tag: ${TAG}"
echo "================================================"

cd "$PROJECT_DIR"

SERVICES=(api-gateway user-service account-service transaction-service notification-service)

echo ""
echo "[1/2] Building images..."
for svc in "${SERVICES[@]}"; do
  echo "  Building ${REGISTRY}${svc}:${TAG}..."
  docker build \
    -t "${REGISTRY}${svc}:${TAG}" \
    -f "services/${svc}/Dockerfile" \
    services/
done

echo ""
echo "[2/2] Pushing images to Docker Hub..."
for svc in "${SERVICES[@]}"; do
  echo "  Pushing ${REGISTRY}${svc}:${TAG}..."
  docker push "${REGISTRY}${svc}:${TAG}"
done

echo ""
echo "================================================"
echo " BUILD & PUSH COMPLETE"
echo "================================================"
echo ""
echo "Pushed images:"
for svc in "${SERVICES[@]}"; do
  echo "  ${REGISTRY}${svc}:${TAG}"
done
echo ""
echo "Next step:"
echo "  bash scripts/gcp-deploy.sh"
