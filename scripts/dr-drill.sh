#!/usr/bin/env bash
# Disaster-recovery drill: restore latest Velero backup of shop-prod into an isolated namespace.
set -euo pipefail
B=$(velero backup get -o json | python3 -c 'import sys,json;i=sorted(json.load(sys.stdin)["items"],key=lambda x:x["metadata"]["creationTimestamp"]);print(i[-1]["metadata"]["name"])')
echo "Restoring $B -> shop-prod-drill"
velero restore create "drill-$(date +%s)" --from-backup "$B" --namespace-mappings shop-prod:shop-prod-drill --wait
kubectl -n shop-prod-drill get rollout,svc,hpa
