#!/usr/bin/env bash
# One-time cluster bootstrap: installs Argo CD, then hands everything else to GitOps.
set -euo pipefail
: "${CLUSTER_NAME:=devops-platform-prod}" "${AWS_REGION:=eu-west-1}"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.2/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl apply -f "$(dirname "$0")/../argocd/bootstrap/root.yaml"
echo "Argo CD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
