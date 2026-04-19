#!/bin/bash
# Blue-Green traffic switch.
#
# Blue (active stack):
#   ./scripts/switch-blue-green.sh blue
#
# Green (deploy new version, test, then switch):
#   docker-compose --profile green up -d
#   curl http://localhost:8090/actuator/health   # test
#   ./scripts/switch-blue-green.sh green
#
# Rollback:
#   ./scripts/switch-blue-green.sh blue

set -e

TARGET=$1
NGINX_CONF="./nginx/nginx.conf"

if [[ "$TARGET" != "blue" && "$TARGET" != "green" ]]; then
    echo "Usage: $0 [blue|green]"
    exit 1
fi

echo "Switching traffic to: $TARGET"

cp "./nginx/nginx.${TARGET}.conf" "$NGINX_CONF"

# Graceful reload — does not drop active connections, ~50ms switchover
docker-compose exec nginx nginx -s reload

echo "Done. Traffic is now routed to: $TARGET"
echo "Verify: curl -s http://localhost/actuator/health | jq"
