#!/usr/bin/env bash
# Reproducible local environment on kind: ingress + Argo Rollouts + Prometheus/Grafana + the app.
set -euo pipefail
cd "$(dirname "$0")/.."
cat <<KIND | kind create cluster --name devops-platform --config -
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs: {node-labels: "ingress-ready=true"}
    extraPortMappings:
      - {containerPort: 80, hostPort: 8080, protocol: TCP}
KIND
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/kind/deploy.yaml
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade -i argo-rollouts argo/argo-rollouts -n argo-rollouts --create-namespace --version 2.38.0
helm upgrade -i kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring --create-namespace --version 67.4.0 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
  --set grafana.sidecar.dashboards.searchNamespace=ALL
kubectl -n ingress-nginx wait --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=180s
docker build -t orders-api:local --build-arg APP_VERSION=local app
kind load docker-image orders-api:local --name devops-platform
kubectl apply -k k8s/overlays/local
echo "App: curl -H 'Host: orders.localtest.me' http://localhost:8080/version"
echo "Watch rollouts: kubectl argo rollouts get rollout orders-api -n shop-local -w"
