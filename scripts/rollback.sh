#!/usr/bin/env bash
# Emergency rollback. Usage: rollback.sh <namespace>   (default shop-prod)
# Fast path (seconds): Argo Rollouts. Durable path: git revert so Argo CD does not re-apply the bad version.
set -euo pipefail
NS=${1:-shop-prod}
kubectl argo rollouts abort orders-api -n "$NS" || true
kubectl argo rollouts undo  orders-api -n "$NS"
echo "Now make it durable:  git revert <deploy-commit> && git push   (Argo CD selfHeal will otherwise fight the undo)"
