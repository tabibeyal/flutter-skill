#!/bin/bash
# Comprehensive E2E test for Flutter apps via flutter-skill CLI
set -e

DART="dart"
CLI="bin/flutter_skill.dart"
PASSED=0
FAILED=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

run() {
  local name="$1"
  shift
  TOTAL=$((TOTAL + 1))
  printf "  %-45s" "$name"
  local output
  if output=$("$DART" run "$CLI" "$@" 2>&1); then
    printf "${GREEN}PASS${NC}\n"
    PASSED=$((PASSED + 1))
    [ -n "$VERBOSE" ] && echo "    $output"
    return 0
  else
    printf "${RED}FAIL${NC}\n"
    echo "    $output" | head -3
    FAILED=$((FAILED + 1))
    return 1
  fi
}

echo "============================================"
echo " Flutter CLI E2E Test Suite"
echo "============================================"

echo ""
echo "--- Inspect ---"
run "inspect" inspect

echo ""
echo "--- Tap ---"
run "tap increment_button" act tap increment_button
sleep 0.5
run "tap (by text) Increment" act tap Increment
sleep 0.5

echo ""
echo "--- Enter Text ---"
run "enter_text search_field" act enter_text search_field "Hello Flutter E2E"
sleep 0.5

echo ""
echo "--- Get Text ---"
run "get_text counter_text" act get_text counter_text

echo ""
echo "--- Find Element ---"
run "find_element increment_button" act find_element increment_button
run "find_element nonexistent" act find_element nonexistent_xyz || true
TOTAL=$((TOTAL - 1))  # don't count expected failure

echo ""
echo "--- Wait For Element ---"
run "wait_for_element counter_text" act wait_for_element counter_text 3000

echo ""
echo "--- Screenshot ---"
run "screenshot to /tmp/flutter_e2e_screenshot.png" act screenshot /tmp/flutter_e2e_screenshot.png

echo ""
echo "--- Navigate ---"
run "tap navigate_button (to detail)" act tap navigate_button
sleep 0.5
run "inspect detail page" inspect
run "go_back" act go_back
sleep 0.5
run "inspect home page after go_back" inspect

echo ""
echo "--- Scroll ---"
run "scroll to item_15" act scroll item_15
sleep 0.3
run "scroll to item_0" act scroll item_0
sleep 0.3

echo ""
echo "--- Swipe ---"
run "swipe up" act swipe up 400
sleep 0.3
run "swipe down" act swipe down 400
sleep 0.3

echo ""
echo "--- Form Page ---"
run "navigate to form" act tap form_button
sleep 0.5
run "enter name" act enter_text name_field "Charlie"
sleep 0.3
run "tap submit" act tap submit_button
sleep 0.5
run "go_back from form" act go_back
sleep 0.3

echo ""
echo "============================================"
echo " Results: $PASSED passed, $FAILED failed, $TOTAL total"
echo "============================================"
