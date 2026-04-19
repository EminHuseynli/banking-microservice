#!/bin/bash
# Docker Swarm — Horizontal Scaling
#
# Usage:
#   bash scripts/swarm-scale.sh transaction-service 5
#   bash scripts/swarm-scale.sh account-service 3
#
# Thesis demo: scale replicas up during a JMeter load test
# and measure the change in response time and throughput.

set -e

STACK_NAME="banking"
SERVICE=$1
REPLICAS=$2

if [[ -z "$SERVICE" || -z "$REPLICAS" ]]; then
    echo "Usage: $0 <service-name> <replica-count>"
    echo ""
    echo "Examples:"
    echo "  $0 transaction-service 5"
    echo "  $0 account-service 3"
    echo "  $0 user-service 2"
    echo ""
    echo "Current status:"
    docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME" \
        --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}" 2>/dev/null || \
    docker stack services $STACK_NAME
    exit 1
fi

FULL_NAME="${STACK_NAME}_${SERVICE}"

echo "Scaling $FULL_NAME → $REPLICAS replicas..."
docker service scale "${FULL_NAME}=${REPLICAS}"

echo ""
echo "New status:"
docker service ps "$FULL_NAME" --format "table {{.Name}}\t{{.CurrentState}}\t{{.Node}}"
