# Runbook

## Release is stuck or looks wrong
```bash
kubectl argo rollouts get rollout orders-api -n shop-prod
kubectl argo rollouts get rollout orders-api -n shop-prod -w   # live view
```
- Rollout **Degraded / aborted**: analysis failed; traffic is already back on stable. Inspect with
  `kubectl get analysisrun -n shop-prod` and `kubectl describe analysisrun <name>`.
- Rollout paused unexpectedly: `kubectl argo rollouts promote orders-api -n shop-prod` (only if metrics are healthy).

## High error rate
1. Grafana → *orders-api* dashboard: compare `orders-api-stable` vs `orders-api-canary`.
2. Loki: `{app="orders-api"} | json | status >= 500`; correlate by `request_id`.
3. If it started with a release: `./scripts/rollback.sh shop-prod`, then `git revert` the deploy commit so
   Argo CD self-heal does not redeploy the bad digest.

## High latency
Check HPA (`kubectl get hpa -n shop-prod`), node pressure, downstream dependencies; raise `maxReplicas` via PR if CPU-bound.

## Service down
`kubectl get pods -n shop-prod`, `kubectl describe pod`, `kubectl logs`. If pods are rejected on admission, check
Kyverno: `kubectl get events -n shop-prod | grep -i kyverno` (unsigned/unapproved image, or policy violation).

## Image fails signature verification
Only images signed by `ci.yml` on `main` are admitted. Never disable the policy; re-run the pipeline so the image is signed.

## Disaster recovery
| Failure | Recovery | Target |
|---|---|---|
| Bad release | Rollouts auto-abort / `rollback.sh` | seconds |
| Bad config merged | `git revert`; Argo CD reconciles | minutes |
| Namespace/objects deleted | Argo CD self-heal; else `velero restore` from hourly manifest backup | < 15 min |
| Cluster lost | `terraform apply` (state is versioned in S3) → `make bootstrap` → Argo CD rebuilds all workloads from Git → Velero restore for PVC data | < 1 h |
| Bad Terraform apply | Restore previous state version from S3 versioning; re-apply prior commit | < 1 h |

Run `./scripts/dr-drill.sh` quarterly (restores the latest backup into `shop-prod-drill`) and record the timing.

## Secrets
Never commit secrets (gitleaks blocks). Use External Secrets Operator or SOPS; rotate by changing the source secret.
