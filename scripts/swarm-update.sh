#!/bin/bash
# Docker Swarm — Rolling Update
#
# Difference from compose blue-green (nginx switch):
#   - Compose: two separate stacks running, nginx switches traffic
#   - Swarm:   single stack, image is updated, replicas replaced one by one
#              new replica must be healthy before old one is stopped (order: start-first)
#              → zero downtime
#
# Usage:
#   bash scripts/swarm-update.sh green          # update all services to green
#   bash scripts/swarm-update.sh blue           # roll back to blue
#   bash scripts/swarm-update.sh green account-service   # update a single service
#
# Native Swarm rollback:
#   docker service rollback banking_transaction-service

set -e

STACK_NAME="banking"
VERSION=$1
TARGET_SERVICE=$2   # if empty, all services are updated

SERVICES=("api-gateway" "user-service" "account-service" "transaction-service" "notification-service")

if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version> [service-name]"
    echo "  version: blue | green | v2 | ..."
    echo ""
    echo "Examples:"
    echo "  $0 green                    # all services"
    echo "  $0 green transaction-service # single service"
    echo "  $0 blue                     # roll back"
    exit 1
fi

update_service() {
    local service=$1
    local full_name="${STACK_NAME}_${service}"
    local new_image="${service}:${VERSION}"

    echo "Updating $full_name → $new_image"
    docker service update \
        --image "$new_image" \
        --update-parallelism 1 \
        --update-delay 10s \
        --update-failure-action rollback \
        --update-order start-first \
        "$full_name"
    echo "  ✓ $service updated"
}

if [[ -n "$TARGET_SERVICE" ]]; then
    update_service "$TARGET_SERVICE"
else
    echo "Updating all services to version: $VERSION ..."
    echo "(Each service updated sequentially with zero-downtime rolling update)"
    echo ""
    for service in "${SERVICES[@]}"; do
        update_service "$service"
    done
fi

echo ""
echo "Update complete. Current status:"
docker stack services "$STACK_NAME"
