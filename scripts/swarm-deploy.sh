#!/bin/bash
# Docker Swarm — Local deploy script
#
# Usage: bash scripts/swarm-deploy.sh
#
# Steps:
#   1. Load .env file (if present)
#   2. Initialize Docker Swarm (skip if already active)
#   3. Build all service images locally
#   4. Deploy the stack

set -e

STACK_NAME="banking"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "================================================"
echo " Banking Microservices — Docker Swarm Deploy"
echo "================================================"

# 0. Load .env (if present)
if [ -f "$PROJECT_DIR/.env" ]; then
    echo "[0/4] Loading .env file..."
    set -a
    source "$PROJECT_DIR/.env"
    set +a
else
    echo "[0/4] .env not found — using default values."
fi

# 1. Swarm init (no-op if already active)
if ! docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q "active"; then
    echo "[1/4] Initializing Swarm..."
    docker swarm init
else
    echo "[1/4] Swarm already active — skipping."
fi

# 2. Image build
echo "[2/4] Building images..."
cd "$PROJECT_DIR"

TAG="${TAG:-blue}"

docker build -t "api-gateway:${TAG}"          -f services/api-gateway/Dockerfile          services/
docker build -t "user-service:${TAG}"         -f services/user-service/Dockerfile         services/
docker build -t "account-service:${TAG}"      -f services/account-service/Dockerfile      services/
docker build -t "transaction-service:${TAG}"  -f services/transaction-service/Dockerfile  services/
docker build -t "notification-service:${TAG}" -f services/notification-service/Dockerfile services/

echo "Image build complete (tag: ${TAG})."

# 3. Stack deploy
echo "[3/4] Deploying stack: $STACK_NAME"
docker stack deploy -c docker-stack.yml "$STACK_NAME"

echo ""
echo "================================================"
echo " Deploy complete!"
echo "================================================"
echo ""
echo "Service status:"
echo "  docker stack services $STACK_NAME"
echo ""
echo "Watch until all replicas are ready:"
echo "  watch docker stack services $STACK_NAME"
echo ""
echo "Endpoints:"
echo "  API Gateway:      http://localhost"
echo "  Swagger UI:       http://localhost/swagger-ui.html"
echo "  RabbitMQ UI:      http://localhost:15672  (guest/guest)"
echo "  Prometheus:       http://localhost:9090"
echo "  Grafana:          http://localhost:3000   (admin/admin)"
