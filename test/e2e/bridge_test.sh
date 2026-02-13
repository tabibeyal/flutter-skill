#!/bin/bash
# Comprehensive E2E test for bridge-protocol SDKs (Electron, Android, etc.)
# Tests all actions via WebSocket JSON-RPC 2.0 on port 18118

set -e

PORT="${1:-18118}"
HOST="127.0.0.1"
PASSED=0
FAILED=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

ws_call() {
  local id="$1"
  local method="$2"
  local params="$3"
  local msg="{\"jsonrpc\":\"2.0\",\"id\":$id,\"method\":\"$method\",\"params\":$params}"
  echo "$msg" | websocat -t -1 "ws://$HOST:$PORT/ws" 2>/dev/null
}

run_test() {
  local name="$1"
  local method="$2"
  local params="$3"
  local check="$4"  # grep pattern to verify success
  
  TOTAL=$((TOTAL + 1))
  printf "  %-40s" "$name"
  
  local result
  result=$(ws_call $TOTAL "$method" "$params" 2>&1) || true
  
  if [ -z "$result" ]; then
    printf "${RED}FAIL${NC} (no response)\n"
    FAILED=$((FAILED + 1))
    return
  fi
  
  if echo "$result" | grep -q '"error"'; then
    printf "${RED}FAIL${NC} %s\n" "$(echo "$result" | head -c 120)"
    FAILED=$((FAILED + 1))
    return
  fi
  
  if [ -n "$check" ]; then
    if echo "$result" | grep -q "$check"; then
      printf "${GREEN}PASS${NC}\n"
      PASSED=$((PASSED + 1))
    else
      printf "${RED}FAIL${NC} expected: %s got: %s\n" "$check" "$(echo "$result" | head -c 120)"
      FAILED=$((FAILED + 1))
    fi
  else
    printf "${GREEN}PASS${NC}\n"
    PASSED=$((PASSED + 1))
  fi
}

echo "============================================"
echo " Bridge E2E Test Suite"
echo " Target: ws://$HOST:$PORT/ws"
echo "============================================"

# Check websocat is available
if ! command -v websocat &>/dev/null; then
  echo "websocat not found. Install: brew install websocat"
  exit 1
fi

# Check health endpoint first
echo ""
echo "--- Health Check ---"
HTTP_HEALTH=$(curl -s "http://$HOST:$PORT/.flutter-skill" 2>/dev/null || echo "FAIL")
if echo "$HTTP_HEALTH" | grep -q '"sdk_version"'; then
  printf "  HTTP health:                            ${GREEN}PASS${NC}\n"
  echo "  $HTTP_HEALTH"
else
  printf "  HTTP health:                            ${RED}FAIL${NC} (app not running on port $PORT)\n"
  exit 1
fi

echo ""
echo "--- Initialize ---"
run_test "initialize" "initialize" '{"protocol_version":"1.0","client":"test"}' '"success"'

echo ""
echo "--- Inspect ---"
run_test "inspect" "inspect" '{}' '"elements"'

echo ""
echo "--- Tap ---"
run_test "tap (by key)" "tap" '{"key":"increment_btn"}' '"success"'
sleep 0.3
run_test "tap (by text)" "tap" '{"text":"Increment"}' '"success"'
sleep 0.3

echo ""
echo "--- Enter Text ---"
run_test "enter_text" "enter_text" '{"key":"input_field","text":"Hello E2E"}' '"success"'
sleep 0.3

echo ""
echo "--- Get Text ---"
run_test "get_text (counter)" "get_text" '{"key":"counter_text"}' '"text"'
run_test "get_text (input)" "get_text" '{"key":"input_field"}' '"text"'

echo ""
echo "--- Find Element ---"
run_test "find_element (by key)" "find_element" '{"key":"increment_btn"}' '"found":true'
run_test "find_element (by text)" "find_element" '{"text":"Increment"}' '"found":true'
run_test "find_element (missing)" "find_element" '{"key":"nonexistent_xyz"}' '"found":false'

echo ""
echo "--- Wait For Element ---"
run_test "wait_for_element (exists)" "wait_for_element" '{"key":"counter_text","timeout":3000}' '"found":true'
run_test "wait_for_element (by text)" "wait_for_element" '{"text":"Count","timeout":3000}' '"found":true'

echo ""
echo "--- Scroll ---"
run_test "scroll down" "scroll" '{"direction":"down","distance":300}' '"success"'
sleep 0.3
run_test "scroll up" "scroll" '{"direction":"up","distance":300}' '"success"'
sleep 0.3

echo ""
echo "--- Screenshot ---"
run_test "screenshot" "screenshot" '{}' '"image"'

echo ""
echo "--- Navigation ---"
run_test "tap detail_btn" "tap" '{"key":"detail_btn"}' '"success"'
sleep 0.5
run_test "inspect detail page" "inspect" '{}' '"elements"'
run_test "go_back" "go_back" '{}' '"success"'
sleep 0.5
run_test "inspect home page" "inspect" '{}' '"elements"'

echo ""
echo "--- Swipe ---"
run_test "swipe up" "swipe" '{"direction":"up","distance":400}' '"success"'
sleep 0.3
run_test "swipe down" "swipe" '{"direction":"down","distance":400}' '"success"'
sleep 0.3

echo ""
echo "--- Logs ---"
run_test "get_logs" "get_logs" '{}' '"logs"'
run_test "clear_logs" "clear_logs" '{}' '"success"'

echo ""
echo "============================================"
echo " Results: $PASSED passed, $FAILED failed, $TOTAL total"
echo "============================================"

if [ $FAILED -gt 0 ]; then
  exit 1
fi
