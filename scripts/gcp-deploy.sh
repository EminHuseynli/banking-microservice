#!/bin/bash
# Copies files to the GCP Swarm manager and deploys the stack
#
# Usage: bash scripts/gcp-deploy.sh
# Before: bash scripts/gcp-build-push.sh (images must be in the registry)
#
# Steps:
#   1. Copy .env.gcp and required files to the manager VM
#   2. Run 'docker stack deploy' on the manager VM

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

ZONE="europe-west1-b"   # must match gcp-setup.sh
STACK_NAME="banking"
REMOTE_DIR="/home/\$USER/banking-deploy"

# ─── Load .env.gcp ────────────────────────────────────────────
ENV_FILE="$PROJECT_DIR/.env.gcp"
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env.gcp not found."
  exit 1
fi
source "$ENV_FILE"

# Validate required variables
for VAR in REGISTRY JWT_SECRET DB_PASSWORD RABBIT_USER RABBIT_PASS GF_ADMIN_PASS; do
  if [ -z "${!VAR}" ] || [[ "${!VAR}" == *"BURAYA"* ]] || [[ "${!VAR}" == *"DOCKER_HUB"* ]]; then
    echo "ERROR: '$VAR' is not set in .env.gcp."
    exit 1
  fi
done

MANAGER_EXTERNAL_IP=$(gcloud compute instances describe swarm-manager \
  --zone="$ZONE" \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null)

if [ -z "$MANAGER_EXTERNAL_IP" ]; then
  echo "ERROR: swarm-manager VM not found. Run: bash scripts/gcp-setup.sh"
  exit 1
fi

echo "================================================"
echo " Banking Microservices — GCP Swarm Deploy"
echo " Manager: $MANAGER_EXTERNAL_IP  |  Stack: $STACK_NAME"
echo "================================================"

# ─── 1. Copy files to the manager ─────────────────────────────
echo ""
echo "[1/3] Copying files to the manager VM..."

# Create remote directory
gcloud compute ssh swarm-manager --zone="$ZONE" \
  --command="mkdir -p ~/banking-deploy/nginx ~/banking-deploy/scripts" --quiet

# Stack files
gcloud compute scp \
  "$PROJECT_DIR/docker-stack.yml" \
  "$PROJECT_DIR/prometheus.yml" \
  "$PROJECT_DIR/.env.gcp" \
  "swarm-manager:~/banking-deploy/" \
  --zone="$ZONE" --quiet

# nginx config
gcloud compute scp \
  "$PROJECT_DIR/nginx/nginx.blue.conf" \
  "swarm-manager:~/banking-deploy/nginx/" \
  --zone="$ZONE" --quiet

echo "  Files copied."

# ─── 2. Deploy on the manager ─────────────────────────────────
echo ""
echo "[2/3] Deploying stack..."

# docker login may be required — not needed for public registries
# For private registries: add a docker login command here

gcloud compute ssh swarm-manager --zone="$ZONE" --command="
  set -e
  cd ~/banking-deploy

  # Load env vars
  source .env.gcp

  # Deploy the stack (updates if already running, creates on first run)
  sudo -E docker stack deploy \
    --compose-file docker-stack.yml \
    --with-registry-auth \
    $STACK_NAME

  echo 'Stack deploy command sent.'
" --quiet

# ─── 3. Status check ──────────────────────────────────────────
echo ""
echo "[3/3] Checking service status (waiting 30s)..."
sleep 30

gcloud compute ssh swarm-manager --zone="$ZONE" \
  --command="sudo docker stack services $STACK_NAME" --quiet

echo ""
echo "================================================"
echo " DEPLOY COMPLETE"
echo "================================================"
echo ""
echo "Endpoints:"
echo "  API Gateway / Swagger:  http://$MANAGER_EXTERNAL_IP"
echo "  RabbitMQ UI:            http://$MANAGER_EXTERNAL_IP:15672"
echo "  Prometheus:             http://$MANAGER_EXTERNAL_IP:9090"
echo "  Grafana:                http://$MANAGER_EXTERNAL_IP:3000"
echo ""
echo "Useful commands (run on the manager):"
echo "  Service status:   docker stack services $STACK_NAME"
echo "  Service logs:     docker service logs banking_transaction-service"
echo "  Node list:        docker node ls"
echo "  Scale example:    docker service scale banking_account-service=5"
echo ""
echo "SSH to manager:"
echo "  gcloud compute ssh swarm-manager --zone=$ZONE"
