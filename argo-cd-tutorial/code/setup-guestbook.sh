#!/usr/bin/env bash
set -euo pipefail

# === Configuration ===
CLUSTER_NAME="guestbook"
NAMESPACE="guestbook"
PORT=8080

echo "🚀 [1/6] Creating Kind cluster '$CLUSTER_NAME'..."
cat >kind-${CLUSTER_NAME}.yaml <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
YAML

kind create cluster --name "${CLUSTER_NAME}" --config kind-${CLUSTER_NAME}.yaml

echo "✅ Cluster created!"
echo

echo "🚀 [2/6] Creating namespace '${NAMESPACE}'..."
kubectl create namespace "${NAMESPACE}" || true

echo "🚀 [3/6] Deploying Guestbook (Redis leader/follower + frontend)..."
kubectl apply -n "${NAMESPACE}" -f https://k8s.io/examples/application/guestbook/redis-leader-deployment.yaml
kubectl apply -n "${NAMESPACE}" -f https://k8s.io/examples/application/guestbook/redis-leader-service.yaml
kubectl apply -n "${NAMESPACE}" -f https://k8s.io/examples/application/guestbook/redis-follower-deployment.yaml
kubectl apply -n "${NAMESPACE}" -f https://k8s.io/examples/application/guestbook/redis-follower-service.yaml
kubectl apply -n "${NAMESPACE}" -f https://k8s.io/examples/application/guestbook/frontend-deployment.yaml
kubectl apply -n "${NAMESPACE}" -f https://k8s.io/examples/application/guestbook/frontend-service.yaml

echo
echo "⏳ [4/6] Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod -l app=redis,role=leader -n "${NAMESPACE}" --timeout=180s
kubectl wait --for=condition=ready pod -l app=redis,role=follower -n "${NAMESPACE}" --timeout=180s
kubectl wait --for=condition=ready pod -l app=guestbook -n "${NAMESPACE}" --timeout=180s

echo
echo "✅ All pods ready!"
kubectl get pods -n "${NAMESPACE}"

echo
echo "🚀 [5/6] Exposing frontend on localhost:${PORT} ..."
kubectl port-forward -n "${NAMESPACE}" svc/frontend ${PORT}:80 >/tmp/guestbook-port-forward.log 2>&1 &
PF_PID=$!

sleep 3
echo "✅ Port-forward running in background (PID ${PF_PID})."
echo

echo "🌐 [6/6] Open your browser at: http://localhost:${PORT}"
echo
echo "Press ENTER to stop and delete the cluster."
read -r

kill ${PF_PID} || true
kind delete cluster --name "${CLUSTER_NAME}"
echo "🧹 Cluster deleted. Bye!"
