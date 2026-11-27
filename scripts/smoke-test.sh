#!/usr/bin/env bash
# usage: smoke-test.sh <base-url> <expected-version> [timeout-seconds]
set -euo pipefail
URL=${1:?base url}; WANT=${2:?version}; TIMEOUT=${3:-300}
end=$((SECONDS+TIMEOUT))
until [ "$(curl -fsS "$URL/version" 2>/dev/null | python3 -c 'import sys,json;print(json.load(sys.stdin)["version"])' 2>/dev/null)" = "$WANT" ]; do
  [ $SECONDS -ge $end ] && { echo "timeout waiting for version $WANT at $URL"; exit 1; }
  echo "waiting for $WANT ..."; sleep 10
done
curl -fsS "$URL/readyz" >/dev/null
id=$(curl -fsS -X POST "$URL/orders" -H 'content-type: application/json' -d '{"item":"smoke","quantity":1}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
curl -fsS "$URL/orders/$id" >/dev/null
echo "smoke test passed for $WANT"
