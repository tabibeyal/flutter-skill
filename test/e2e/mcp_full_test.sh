#!/bin/bash
# Full MCP tool test for v0.8.1 new features
# Usage: ./mcp_full_test.sh <platform> [ws_port]
# platform: electron, android, ios-flutter, tauri, kmp, dotnet, rn
# ws_port: override port (default: auto via scan_and_connect)

set -e
PLATFORM=${1:-electron}
PORT=${2:-""}
export PATH="/Users/cw/development/flutter/bin:$PATH"

PASS=0
FAIL=0
SKIP=0

check() {
  local name="$1"
  local id="$2"
  local response="$3"
  
  if echo "$response" | grep -q '"error"'; then
    if echo "$response" | grep -q 'Not connected\|requires a Flutter'; then
      echo "  ⏭️  $name (not applicable)"
      SKIP=$((SKIP+1))
    else
      echo "  ❌ $name"
      echo "      $(echo "$response" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('error',{}).get('message','unknown')[:120])" 2>/dev/null || echo "$response" | head -c 120)"
      FAIL=$((FAIL+1))
    fi
  elif echo "$response" | grep -q '"result"'; then
    echo "  ✅ $name"
    PASS=$((PASS+1))
  else
    echo "  ❓ $name (unexpected response)"
    FAIL=$((FAIL+1))
  fi
}

echo "============================================"
echo "MCP Full Test — Platform: $PLATFORM"
echo "============================================"

# Build commands
CMDS=""
ID=1

add() {
  CMDS="$CMDS
$1"
  ID=$((ID+1))
}

# Init
add '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}},"id":1}'

# Connect
if [ -n "$PORT" ]; then
  add "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"connect_app\",\"arguments\":{\"uri\":\"ws://127.0.0.1:$PORT\"}},\"id\":2}"
else
  add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"scan_and_connect","arguments":{}},"id":2}'
fi

# Auth tools
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"auth_otp","arguments":{"secret":"JBSWY3DPEHPK3PXP"}},"id":10}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"auth_otp","arguments":{"secret":"JBSWY3DPEHPK3PXP","digits":8,"period":60}},"id":11}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"auth_inject_session","arguments":{"token":"test-token-abc","storage":"local_storage","key":"auth_token"}},"id":12}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"auth_inject_session","arguments":{"token":"test-token-xyz","key":"session"}},"id":13}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"auth_biometric","arguments":{"action":"enroll"}},"id":14}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"auth_biometric","arguments":{"action":"match"}},"id":15}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"auth_biometric","arguments":{"action":"fail"}},"id":16}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"auth_deeplink","arguments":{"url":"myapp://test?token=abc123"}},"id":17}'

# Snapshot modes
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"snapshot","arguments":{"mode":"text"}},"id":20}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"snapshot","arguments":{"mode":"vision"}},"id":21}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"snapshot","arguments":{"mode":"smart"}},"id":22}'

# Video recording
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"video_start","arguments":{}},"id":30}'
# small delay handled by sleep
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"video_stop","arguments":{}},"id":31}'

# Code recording
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"record_start","arguments":{}},"id":40}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"tap","arguments":{"ref":"button:Home"}},"id":41}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"enter_text","arguments":{"text":"test input","ref":"input:textinput"}},"id":42}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"go_back","arguments":{}},"id":43}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"record_stop","arguments":{}},"id":44}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"record_export","arguments":{"format":"jest"}},"id":50}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"record_export","arguments":{"format":"pytest"}},"id":51}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"record_export","arguments":{"format":"dart_test"}},"id":52}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"record_export","arguments":{"format":"playwright"}},"id":53}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"record_export","arguments":{"format":"json"}},"id":54}'

# Parallel (needs multi-session, will likely fail on single device but should not crash)
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"parallel_snapshot","arguments":{}},"id":60}'
add '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"parallel_tap","arguments":{"ref":"button:Home"}},"id":61}'

# Send all commands with delays
TMPOUT=$(mktemp)
{
  echo "$CMDS" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "$line"
    # Longer delay for snapshot/video
    id=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',0))" 2>/dev/null || echo 0)
    case $id in
      1) sleep 3 ;;
      2) sleep 5 ;;
      20|21|22) sleep 4 ;;
      30) sleep 4 ;;  # video needs time
      31) sleep 3 ;;
      *) sleep 2 ;;
    esac
  done
  sleep 3
} | dart run bin/flutter_skill.dart server 2>/dev/null > "$TMPOUT"

echo ""
echo "--- Results ---"

# Parse results
while IFS= read -r line; do
  [ -z "$line" ] && continue
  id=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
  case $id in
    1) ;; # init
    2) 
      if echo "$line" | grep -q '"success":true'; then
        echo "  ✅ connect"
        PASS=$((PASS+1))
      else
        echo "  ❌ connect FAILED — aborting"
        echo "$line" | head -c 200
        FAIL=$((FAIL+1))
      fi
      ;;
    10) check "auth_otp (6-digit)" "$id" "$line" ;;
    11) check "auth_otp (8-digit/60s)" "$id" "$line" ;;
    12) check "auth_inject_session (local_storage)" "$id" "$line" ;;
    13) check "auth_inject_session (shared_prefs)" "$id" "$line" ;;
    14) check "auth_biometric (enroll)" "$id" "$line" ;;
    15) check "auth_biometric (match)" "$id" "$line" ;;
    16) check "auth_biometric (fail)" "$id" "$line" ;;
    17) check "auth_deeplink" "$id" "$line" ;;
    20) check "snapshot (text)" "$id" "$line" ;;
    21) check "snapshot (vision)" "$id" "$line" ;;
    22) check "snapshot (smart)" "$id" "$line" ;;
    30) check "video_start" "$id" "$line" ;;
    31) check "video_stop" "$id" "$line" ;;
    40) check "record_start" "$id" "$line" ;;
    41) check "tap (recorded)" "$id" "$line" ;;
    42) check "enter_text (recorded)" "$id" "$line" ;;
    43) check "go_back (recorded)" "$id" "$line" ;;
    44) check "record_stop" "$id" "$line" ;;
    50) check "record_export (jest)" "$id" "$line" ;;
    51) check "record_export (pytest)" "$id" "$line" ;;
    52) check "record_export (dart_test)" "$id" "$line" ;;
    53) check "record_export (playwright)" "$id" "$line" ;;
    54) check "record_export (json)" "$id" "$line" ;;
    60) check "parallel_snapshot" "$id" "$line" ;;
    61) check "parallel_tap" "$id" "$line" ;;
  esac
done < "$TMPOUT"

rm -f "$TMPOUT"

echo ""
echo "============================================"
echo "Platform: $PLATFORM"
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "Total: $((PASS+FAIL+SKIP)) / 26 tools tested"
echo "============================================"
