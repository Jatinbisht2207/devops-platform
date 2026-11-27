#!/usr/bin/env bash
# Demonstrates progressive delivery locally. good = healthy v2, bad = v2 with 30% injected 5xx (auto-rollback).
set -euo pipefail
cd "$(dirname "$0")/.."
MODE=${1:?good|bad}; TAG="v-$(date +%s)"
docker build -q -t orders-api:$TAG --build-arg APP_VERSION=$TAG app
kind load docker-image orders-api:$TAG --name devops-platform
kubectl -n shop-local set image rollout/orders-api orders-api=orders-api:$TAG
[ "$MODE" = bad ] && kubectl -n shop-local set env rollout/orders-api ERROR_RATE=0.3
echo "generating traffic; watch: kubectl argo rollouts get rollout orders-api -n shop-local -w"
for i in $(seq 1 600); do curl -s -o /dev/null -H 'Host: orders.localtest.me' http://localhost:8080/orders & sleep 0.2; done; wait
