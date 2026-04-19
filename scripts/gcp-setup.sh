#!/bin/bash
# GCP — Docker Swarm Cluster Setup Script
#
# PREREQUISITES:
#   1. Install gcloud CLI: https://cloud.google.com/sdk/docs/install
#   2. gcloud auth login
#   3. gcloud config set project YOUR_PROJECT_ID
#
# Usage:
#   bash scripts/gcp-setup.sh
#
# Creates:
#   swarm-manager  — 1 instance (e2-standard-2, 50 GB disk)
#   swarm-worker-1 — 1 instance (e2-standard-2, 30 GB disk)
#   swarm-worker-2 — 1 instance (e2-standard-2, 30 GB disk)
#
# Topology:
#   manager  → DBs, RabbitMQ, nginx, Prometheus, Grafana, api-gateway
#   worker-1 → user-service (x2), account-service (x3 shared)
#   worker-2 → transaction-service (x3 shared), notification-service (x2)
#
# Estimated cost: ~$150-200/month (3x e2-standard-2)
# Tip: switch MACHINE_TYPE to e2-medium (4 GB RAM) to reduce to ~$90/month

set -e

# ─── Configuration ────────────────────────────────────────────
ZONE="europe-west1-b"          # Closest to Istanbul: europe-west1 (Belgium)
MACHINE_TYPE="e2-standard-2"   # 2 vCPU, 8 GB RAM
MANAGER_DISK="50"              # GB — DB volumes live here
WORKER_DISK="30"               # GB
IMAGE_FAMILY="ubuntu-2404-lts-amd64"
IMAGE_PROJECT="ubuntu-os-cloud"
NETWORK_TAG="banking-swarm"
# ──────────────────────────────────────────────────────────────

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
  echo "ERROR: No GCP project set. Run: gcloud config set project YOUR_PROJECT_ID"
  exit 1
fi

echo "================================================"
echo " GCP Docker Swarm Setup"
echo " Project: $PROJECT_ID | Zone: $ZONE"
echo "================================================"

# ─── 1. Create VMs ────────────────────────────────────────────
echo ""
echo "[1/5] Creating VMs..."

gcloud compute instances create swarm-manager \
  --zone="$ZONE" \
  --machine-type="$MACHINE_TYPE" \
  --image-family="$IMAGE_FAMILY" \
  --image-project="$IMAGE_PROJECT" \
  --boot-disk-size="${MANAGER_DISK}GB" \
  --boot-disk-type=pd-ssd \
  --tags="$NETWORK_TAG,swarm-manager" \
  --metadata=enable-oslogin=TRUE \
  --quiet

for i in 1 2; do
  gcloud compute instances create "swarm-worker-$i" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --image-family="$IMAGE_FAMILY" \
    --image-project="$IMAGE_PROJECT" \
    --boot-disk-size="${WORKER_DISK}GB" \
    --boot-disk-type=pd-ssd \
    --tags="$NETWORK_TAG,swarm-worker" \
    --metadata=enable-oslogin=TRUE \
    --quiet
done

echo "VMs created."

# ─── 2. Firewall rules ────────────────────────────────────────
echo ""
echo "[2/5] Creating firewall rules..."

# Swarm internal communication (between cluster nodes only)
gcloud compute firewall-rules create banking-swarm-internal \
  --allow=tcp:2377,tcp:7946,udp:7946,udp:4789 \
  --source-tags="$NETWORK_TAG" \
  --target-tags="$NETWORK_TAG" \
  --description="Docker Swarm cluster internal communication" \
  --quiet 2>/dev/null || echo "  banking-swarm-internal already exists, skipping."

# Externally exposed ports (accessible from the internet)
gcloud compute firewall-rules create banking-swarm-external \
  --allow=tcp:80,tcp:8080,tcp:9090,tcp:3000,tcp:15672 \
  --source-ranges="0.0.0.0/0" \
  --target-tags="swarm-manager" \
  --description="Banking application public ingress ports" \
  --quiet 2>/dev/null || echo "  banking-swarm-external already exists, skipping."

# SSH access
gcloud compute firewall-rules create banking-swarm-ssh \
  --allow=tcp:22 \
  --source-ranges="0.0.0.0/0" \
  --target-tags="$NETWORK_TAG" \
  --description="SSH access" \
  --quiet 2>/dev/null || echo "  banking-swarm-ssh already exists, skipping."

echo "Firewall rules ready."

# ─── 3. Install Docker ────────────────────────────────────────
echo ""
echo "[3/5] Installing Docker on all VMs..."

DOCKER_INSTALL_CMD='
  set -e
  export DEBIAN_FRONTEND=noninteractive
  # Remove old versions
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y $pkg 2>/dev/null || true
  done
  # Install
  sudo apt-get update -q
  sudo apt-get install -y -q ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -q
  sudo apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker $USER
  sudo systemctl enable docker
  echo "Docker installed: $(docker --version)"
'

for VM in swarm-manager swarm-worker-1 swarm-worker-2; do
  echo "  Installing Docker on: $VM..."
  gcloud compute ssh "$VM" --zone="$ZONE" --command="$DOCKER_INSTALL_CMD" --quiet
done

echo "Docker installed on all VMs."

# ─── 4. Initialize Swarm ──────────────────────────────────────
echo ""
echo "[4/5] Initializing Docker Swarm..."

MANAGER_INTERNAL_IP=$(gcloud compute instances describe swarm-manager \
  --zone="$ZONE" \
  --format='get(networkInterfaces[0].networkIP)')

echo "  Manager IP (internal): $MANAGER_INTERNAL_IP"

# Init Swarm on the manager
gcloud compute ssh swarm-manager --zone="$ZONE" --command="
  sudo docker swarm init --advertise-addr $MANAGER_INTERNAL_IP 2>/dev/null || echo 'Swarm already active'
" --quiet

# Retrieve the worker join token
WORKER_TOKEN=$(gcloud compute ssh swarm-manager --zone="$ZONE" \
  --command="sudo docker swarm join-token worker -q" --quiet 2>/dev/null | tr -d '[:space:]')

echo "  Join token retrieved."

# Join workers to the Swarm
for i in 1 2; do
  echo "  Joining swarm-worker-$i..."
  gcloud compute ssh "swarm-worker-$i" --zone="$ZONE" --command="
    sudo docker swarm join --token $WORKER_TOKEN $MANAGER_INTERNAL_IP:2377 2>/dev/null || echo 'Already a Swarm member'
  " --quiet
done

echo "Swarm cluster ready."

# ─── 5. Summary ───────────────────────────────────────────────
MANAGER_EXTERNAL_IP=$(gcloud compute instances describe swarm-manager \
  --zone="$ZONE" \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo ""
echo "================================================"
echo " SETUP COMPLETE"
echo "================================================"
echo ""
echo "Manager external IP: $MANAGER_EXTERNAL_IP"
echo ""
echo "Verify node status:"
echo "  gcloud compute ssh swarm-manager --zone=$ZONE --command='sudo docker node ls'"
echo ""
echo "Next step — build and push images:"
echo "  bash scripts/gcp-build-push.sh"
echo ""
echo "Then deploy the stack:"
echo "  bash scripts/gcp-deploy.sh"
