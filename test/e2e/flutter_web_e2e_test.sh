#!/bin/bash
# Comprehensive E2E test for Flutter Web via flutter-skill CLI
set -e

DART="dart"
CLI="bin/flutter_skill.dart"
URI="${1:-}"  # Pass VM service URI as first arg
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
  if [ -n "$URI" ]; then
    if output=$("$DART" run "$CLI" "$@" "$URI" 2>&1); then
      printf "${GREEN}PASS${NC}\n"
      PASSED=$((PASSED + 1))
      return 0
    else
      printf "${RED}FAIL${NC}\n"
      echo "    $output" | head -3
      FAILED=$((FAILED + 1))
      return 1
    fi
  else
    if output=$("$DART" run "$CLI" "$@" 2>&1); then
      printf "${GREEN}PASS${NC}\n"
      PASSED=$((PASSED + 1))
      return 0
    else
      printf "${RED}FAIL${NC}\n"
      echo "    $output" | head -3
      FAILED=$((FAILED + 1))
      return 1
    fi
  fi
}

# For act commands, URI goes AFTER "act" but BEFORE the action
run_act() {
  local name="$1"
  shift
  TOTAL=$((TOTAL + 1))
  printf "  %-45s" "$name"
  local output
  if [ -n "$URI" ]; then
    if output=$("$DART" run "$CLI" act "$URI" "$@" 2>&1); then
      printf "${GREEN}PASS${NC}\n"
      PASSED=$((PASSED + 1))
      return 0
    else
      printf "${RED}FAIL${NC}\n"
      echo "    $output" | head -3
      FAILED=$((FAILED + 1))
      return 1
    fi
  else
    if output=$("$DART" run "$CLI" act "$@" 2>&1); then
      printf "${GREEN}PASS${NC}\n"
      PASSED=$((PASSED + 1))
      return 0
    else
      printf "${RED}FAIL${NC}\n"
      echo "    $output" | head -3
      FAILED=$((FAILED + 1))
      return 1
    fi
  fi
}

echo "============================================"
echo " Flutter E2E Test Suite (Web)"
echo " URI: ${URI:-auto-discover}"
echo "============================================"

echo ""
echo "--- Inspect ---"
run "inspect" inspect

echo ""
echo "--- Tap ---"
run_act "tap increment_button" tap increment_button
sleep 0.5
run_act "tap (by text) Increment" tap Increment
sleep 0.5

echo ""
echo "--- Enter Text ---"
run_act "enter_text search_field" enter_text search_field "Hello Web E2E"
sleep 0.5

echo ""
echo "--- Get Text ---"
run_act "get_text counter_text" get_text counter_text

echo ""
echo "--- Find Element ---"
run_act "find_element increment_button" find_element increment_button

echo ""
echo "--- Wait For Element ---"
run_act "wait_for_element counter_text" wait_for_element counter_text 3000

echo ""
echo "--- Screenshot ---"
run_act "screenshot" screenshot /tmp/flutter_web_e2e_screenshot.png

echo ""
echo "--- Navigate ---"
run_act "tap navigate_button" tap navigate_button
sleep 0.5
run "inspect detail page" inspect
run_act "go_back" go_back
sleep 0.5
run "inspect home after go_back" inspect

echo ""
echo "--- Scroll ---"
run_act "scroll to item_15" scroll item_15
sleep 0.3
run_act "scroll to item_0" scroll item_0
sleep 0.3

echo ""
echo "--- Swipe ---"
run_act "swipe up" swipe up 400
sleep 0.3
run_act "swipe down" swipe down 400
sleep 0.3

echo ""
echo "--- Form Page ---"
run_act "navigate to form" tap form_button
sleep 0.5
run_act "enter name" enter_text name_field "Charlie"
sleep 0.3
run_act "tap submit" tap submit_button
sleep 0.5
run_act "go_back from form" go_back
sleep 0.3

echo ""
echo "============================================"
echo " Results: $PASSED passed, $FAILED failed, $TOTAL total"
echo "============================================"
