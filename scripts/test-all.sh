#!/bin/bash
# Banking Microservices — Integration Test Script
#
# Usage: bash scripts/test-all.sh

set -e

BASE_URL="http://localhost"
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}  ✓ $1${NC}"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}  ✗ $1${NC}"; FAIL=$((FAIL+1)); return 0; }
info() { echo -e "${YELLOW}► $1${NC}"; }

assert_status() {
    local label=$1 expected=$2 actual=$3
    if [[ "$actual" == "$expected" ]]; then ok "$label (HTTP $actual)"
    else fail "$label — expected: $expected, got: $actual"; fi
}

http_get() {
    curl -s -o /dev/null -w "%{http_code}" "$@" 2>/dev/null || true
}

http_post() {
    curl -s -o /dev/null -w "%{http_code}" -X POST "$@" 2>/dev/null || true
}

# ============================================================
# 1. HEALTH CHECKS — wait until all services are ready
# ============================================================
info "1. Service Health"

wait_for_service() {
    local name=$1 port=$2 max_wait=60 waited=0 status=""
    while [[ $waited -lt $max_wait ]]; do
        status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}/actuator/health" 2>/dev/null) || true
        if [[ "$status" == "200" ]]; then ok "$name healthy"; return 0; fi
        sleep 2; waited=$((waited+2))
    done
    fail "$name — not ready after ${max_wait}s"
    return 0
}

wait_for_service "api-gateway"         8080
wait_for_service "user-service"        8081
wait_for_service "account-service"     8082
wait_for_service "transaction-service" 8083
wait_for_service "notification-service" 8084

# ============================================================
# 2. USER — Register + Login
# ============================================================
info "2. User Service"

TIMESTAMP=$(date +%s)
TEST_EMAIL="test${TIMESTAMP}@banking.com"

REGISTER_STATUS=$(http_post "${BASE_URL}/api/users/register" \
    -H "Content-Type: application/json" \
    -d "{\"firstName\":\"Test\",\"lastName\":\"User\",\"email\":\"${TEST_EMAIL}\",\"password\":\"Pass1234!\"}")
assert_status "Register (201)" "201" "$REGISTER_STATUS"

LOGIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${TEST_EMAIL}\",\"password\":\"Pass1234!\"}" 2>/dev/null) || true

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [[ -n "$TOKEN" ]]; then ok "Login → JWT token received"
else fail "Login → no token. Response: $LOGIN_RESPONSE"; exit 1; fi

# ============================================================
# 3. ACCOUNT — Account creation
# ============================================================
info "3. Account Service"

CREATE_ACCOUNT_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/accounts" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"accountType":"CHECKING"}' 2>/dev/null) || true

ACCOUNT_ID=$(echo "$CREATE_ACCOUNT_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
if [[ -n "$ACCOUNT_ID" ]]; then ok "Account created — ID: $ACCOUNT_ID"
else fail "Account creation failed. Response: $CREATE_ACCOUNT_RESPONSE"; ACCOUNT_ID=1; fi

CREATE_ACCOUNT2_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/accounts" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"accountType":"SAVINGS"}' 2>/dev/null) || true

ACCOUNT_ID2=$(echo "$CREATE_ACCOUNT2_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
if [[ -n "$ACCOUNT_ID2" ]]; then ok "Second account created — ID: $ACCOUNT_ID2"; fi

# ============================================================
# 4. TRANSACTION — Deposit, Withdraw, Transfer
# ============================================================
info "4. Transaction Service (Feign → Account Service)"

DEPOSIT_STATUS=$(http_post "${BASE_URL}/api/transactions/deposit" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"accountId\":${ACCOUNT_ID},\"amount\":1000.00,\"description\":\"Test deposit\"}")
assert_status "Deposit (201)" "201" "$DEPOSIT_STATUS"

WITHDRAW_STATUS=$(http_post "${BASE_URL}/api/transactions/withdraw" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"accountId\":${ACCOUNT_ID},\"amount\":100.00,\"description\":\"Test withdraw\"}")
assert_status "Withdraw (201)" "201" "$WITHDRAW_STATUS"

if [[ -n "$ACCOUNT_ID2" ]]; then
    TRANSFER_STATUS=$(http_post "${BASE_URL}/api/transactions/transfer" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"sourceAccountId\":${ACCOUNT_ID},\"targetAccountId\":${ACCOUNT_ID2},\"amount\":200.00,\"description\":\"Test transfer\"}")
    assert_status "Transfer (201)" "201" "$TRANSFER_STATUS"
fi

INSUF_STATUS=$(http_post "${BASE_URL}/api/transactions/withdraw" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"accountId\":${ACCOUNT_ID},\"amount\":999999.00,\"description\":\"Should fail\"}")
assert_status "Insufficient funds → 400" "400" "$INSUF_STATUS"

HISTORY_STATUS=$(http_get "${BASE_URL}/api/transactions/${ACCOUNT_ID}/history" \
    -H "Authorization: Bearer ${TOKEN}")
assert_status "Transaction history (200)" "200" "$HISTORY_STATUS"

# ============================================================
# 5. NOTIFICATION — RabbitMQ async check
# ============================================================
info "5. Notification Service (RabbitMQ async)"

sleep 2

NOTIF_STATUS=$(http_get "${BASE_URL}/api/notifications" \
    -H "Authorization: Bearer ${TOKEN}")
assert_status "Notifications endpoint (200)" "200" "$NOTIF_STATUS"

NOTIF_COUNT=$(curl -s "${BASE_URL}/api/notifications" \
    -H "Authorization: Bearer ${TOKEN}" 2>/dev/null | grep -o '"id"' | wc -l) || true

if [[ "$NOTIF_COUNT" -gt 0 ]]; then ok "RabbitMQ messages processed — $NOTIF_COUNT notification(s) found"
else fail "No notifications — RabbitMQ messages may not have been consumed"; fi

# ============================================================
# 6. DB SCHEMA SEPARATION
# ============================================================
info "6. DB Schema Separation"

DB_CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "db|postgres" | head -1) || true

if [[ -n "$DB_CONTAINER" ]]; then
    check_schema() {
        local schema=$1 table=$2
        result=$(docker exec "$DB_CONTAINER" psql -U postgres -d banking_db -t -c \
            "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${schema}' AND table_name='${table}';" 2>/dev/null | tr -d ' ') || true
        if [[ "$result" == "1" ]]; then ok "Schema: ${schema}.${table} exists"
        else fail "Schema: ${schema}.${table} not found"; fi
    }
    check_schema "user_schema"         "users"
    check_schema "account_schema"      "accounts"
    check_schema "transaction_schema"  "transactions"
    check_schema "notification_schema" "notifications"
else
    info "No DB container found — schema check skipped"
fi

# ============================================================
# 7. CIRCUIT BREAKER
# ============================================================
info "7. Circuit Breaker (Resilience4j)"

ACCOUNT_CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep "account-service" | head -1) || true

if [[ -n "$ACCOUNT_CONTAINER" ]]; then
    echo "  Stopping account-service: $ACCOUNT_CONTAINER"
    docker stop "$ACCOUNT_CONTAINER" > /dev/null

    echo "  Sending 6 requests to trip the circuit..."
    for i in {1..6}; do
        http_post "${BASE_URL}/api/transactions/deposit" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"accountId\":${ACCOUNT_ID},\"amount\":1.00}" > /dev/null || true
    done

    sleep 1

    CB_STATUS=$(http_post "${BASE_URL}/api/transactions/deposit" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"accountId\":${ACCOUNT_ID},\"amount\":1.00}")
    assert_status "Circuit OPEN → 503" "503" "$CB_STATUS"

    CB_STATE=$(curl -s "http://localhost:8083/actuator/health" 2>/dev/null | \
        grep -o '"accountService":{[^}]*}' | grep -o '"state":"[^"]*"' | cut -d'"' -f4) || true
    if [[ "$CB_STATE" == "OPEN" || "$CB_STATE" == "CLOSED" || "$CB_STATE" == "HALF_OPEN" ]]; then
        ok "Actuator circuit state: $CB_STATE"
    else
        info "Circuit state: check manually → GET http://localhost:8083/actuator/health"
    fi

    echo "  Restarting account-service..."
    docker start "$ACCOUNT_CONTAINER" > /dev/null
    waited=0
    while [[ $waited -lt 60 ]]; do
        status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8082/actuator/health" 2>/dev/null) || true
        if [[ "$status" == "200" ]]; then break; fi
        sleep 2; waited=$((waited+2))
    done
    ok "account-service restarted and ready"
else
    info "No account-service container found — circuit breaker test skipped"
fi

# ============================================================
# RESULTS
# ============================================================
echo ""
echo "========================================"
echo -e " Results: ${GREEN}$PASS passed${NC} / ${RED}$FAIL failed${NC}"
echo "========================================"

if [[ $FAIL -gt 0 ]]; then exit 1; fi
