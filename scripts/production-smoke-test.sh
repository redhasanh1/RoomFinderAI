#!/usr/bin/env bash
# Production smoke test — run after Railway redeploy
# Usage: bash scripts/production-smoke-test.sh [base_url]
# Env: SMOKE_CURL_INSECURE=1  skip TLS verify
#      SMOKE_RETRIES=3         retry flaky responses (default 3)

BASE="${1:-https://www.roomfinderai.com}"
RETRIES="${SMOKE_RETRIES:-3}"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'

red() { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[33m%s\033[0m\n' "$1"; }

pass=0
fail=0
warn=0

CURL_EXTRA=()
if ! curl -s -o /dev/null --connect-timeout 10 --max-time 15 "${BASE}/" >/dev/null 2>&1; then
  CURL_EXTRA=(-k)
fi
[ "${SMOKE_CURL_INSECURE:-}" = "1" ] && CURL_EXTRA=(-k)

is_bad_body() {
  local body="$1"
  [[ "$body" == *"Error. Page cannot be displayed"* ]] \
    || [[ "$body" == *"gdprAppliesGlobally"* ]] \
    || [[ "$body" == "OK" ]] \
    || [[ "${#body}" -lt 500 ]]
}

curl_fetch() {
  local path="$1"
  local attempt code body
  for attempt in $(seq 1 "$RETRIES"); do
    body=$(curl "${CURL_EXTRA[@]}" -s --connect-timeout 15 --max-time 30 \
      -A "$UA" -H 'Accept: */*' "${BASE}${path}" 2>/dev/null) || body=""
    code=$(curl "${CURL_EXTRA[@]}" -s -o /dev/null -w "%{http_code}" --connect-timeout 15 --max-time 30 \
      -A "$UA" "${BASE}${path}" 2>/dev/null) || code="000"
    if [ "$code" != "000" ] && ! is_bad_body "$body"; then
      printf '%s\n%s' "$code" "$body"
      return 0
    fi
    [ "$attempt" -lt "$RETRIES" ] && sleep 1
  done
  printf '%s\n%s' "${code:-000}" "$body"
}

check_status() {
  local path="$1"
  local expect="$2"
  local label="$3"
  local fetched code
  fetched=$(curl_fetch "$path")
  code=$(printf '%s' "$fetched" | head -n1)
  if [ "$code" = "$expect" ]; then
    green "PASS [$code] $label"
    pass=$((pass + 1))
  else
    red "FAIL [$code] expected $expect — $label"
    fail=$((fail + 1))
  fi
}

check_html_page() {
  local path="$1"
  local label="$2"
  local fetched code body
  fetched=$(curl_fetch "$path")
  code=$(printf '%s' "$fetched" | head -n1)
  body=$(printf '%s' "$fetched" | tail -n +2)
  if [ "$code" = "200" ] && [[ "$body" == *"RoomFinderAI"* || "$body" == *"roomfinderai"* ]]; then
    green "PASS [$code] $label"
    pass=$((pass + 1))
  else
    red "FAIL [$code] $label (missing RoomFinderAI content — CDN/proxy may be intercepting)"
    fail=$((fail + 1))
  fi
}

check_json() {
  local path="$1"
  local jq_expr="$2"
  local label="$3"
  local fetched body result snippet
  fetched=$(curl_fetch "$path")
  body=$(printf '%s' "$fetched" | tail -n +2)
  result=$(printf '%s' "$body" | python3 -c "
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
    snippet=$(printf '%s' "$body" | head -c 60 | tr '\n' ' ')
    red "FAIL $label (got: ${snippet}...)"
    fail=$((fail + 1))
  fi
}

check_blocked_route() {
  local path="$1"
  local label="$2"
  local fetched code body
  fetched=$(curl_fetch "$path")
  code=$(printf '%s' "$fetched" | head -n1)
  body=$(printf '%s' "$fetched" | tail -n +2)
  if [ "$code" = "404" ] || [[ "$body" == *'"error"'* && "$body" == *"Not found"* ]]; then
    green "PASS [$code] $label"
    pass=$((pass + 1))
  else
    red "FAIL [$code] expected 404 — $label"
    fail=$((fail + 1))
  fi
}

echo "=== RoomFinderAI production smoke test ==="
echo "Base: $BASE"
if [ "${#CURL_EXTRA[@]}" -gt 0 ]; then
  yellow "TLS verification failed — using curl -k (set SMOKE_CURL_INSECURE=1 to silence)"
fi
echo ""

echo "--- Pages (expect 200 + RoomFinderAI content) ---"
for p in / /listings.html /login.html /sublease.html /file-dispute.html /my-disputes.html \
         /student-housing.html /legal.html /ai-negotiator.html /roommate-matching.html \
         /platform-status.html /support.html /pricing.html; do
  check_html_page "$p" "$p"
done

echo ""
echo "--- Security (expect 404 in production) ---"
check_blocked_route "/debug-test" "/debug-test blocked"
check_blocked_route "/api/brevo-status" "/api/brevo-status blocked"

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
  yellow "curl often cannot reach API routes through CDN/proxy — verify in browser:"
  yellow "  ${BASE}/health  → JSON with environment=production"
  yellow "  ${BASE}/debug-test → 404 Not found"
  yellow "If browser shows correct JSON, production is fine; ignore curl API failures."
  exit 1
fi
green "All checks passed — production looks good."
