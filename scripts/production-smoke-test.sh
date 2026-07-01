#!/usr/bin/env bash
# Production smoke test — run after Railway redeploy
# Usage: bash scripts/production-smoke-test.sh [base_url]

set -e
BASE="${1:-https://www.roomfinderai.com}"

red() { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }

pass=0
fail=0

check_status() {
  local path="$1"
  local expect="$2"
  local label="$3"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}${path}")
  if [ "$code" = "$expect" ]; then
    green "PASS [$code] $label"
    pass=$((pass + 1))
  else
    red "FAIL [$code] expected $expect — $label"
    fail=$((fail + 1))
  fi
}

check_json() {
  local path="$1"
  local jq_expr="$2"
  local label="$3"
  local result
  result=$(curl -s "${BASE}${path}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print('ok' if ($jq_expr) else 'no')
except Exception:
    print('err')
" 2>/dev/null)
  if [ "$result" = "ok" ]; then
    green "PASS $label"
    pass=$((pass + 1))
  else
    red "FAIL $label"
    fail=$((fail + 1))
  fi
}

echo "=== RoomFinderAI production smoke test ==="
echo "Base: $BASE"
echo ""

echo "--- Pages (expect 200) ---"
for p in / /listings.html /login.html /sublease.html /file-dispute.html /my-disputes.html \
         /student-housing.html /legal.html /ai-negotiator.html /roommate-matching.html \
         /platform-status.html /support.html /pricing.html; do
  check_status "$p" "200" "$p"
done

echo ""
echo "--- Security (expect 404 in production) ---"
check_status "/debug-test" "404" "/debug-test blocked"
check_status "/api/brevo-status" "404" "/api/brevo-status blocked"

echo ""
echo "--- API health ---"
check_status "/health" "200" "/health"
check_json "/health" "d.get('mode',{}).get('environment')=='production'" "NODE_ENV=production"
check_json "/health" "d.get('mode',{}).get('demo')==False" "demo mode off"
check_json "/health" "d.get('services',{}).get('supabase')==True" "Supabase connected"

echo ""
echo "--- Service status ---"
check_status "/api/service-status" "200" "/api/service-status"
check_json "/api/service-status" "d.get('features',{}).get('database')==True" "database feature on"

echo ""
echo "=== Results: $pass passed, $fail failed ==="
if [ "$fail" -gt 0 ]; then
  yellow "Some checks failed — see docs/LIVE_INTEGRATIONS_AUDIT.md"
  exit 1
fi
green "All checks passed — production looks good."
