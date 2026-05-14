#!/usr/bin/env bash
set -euo pipefail
cd $(dirname $0)

CLUSTER_NAME="k3"
KIND_CONFIG_FILE="kind-3nodes.ingress.yaml"
INGRESS_DEPLOY_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"

echo "[1/6] Creating Kind cluster config..."
cat > "$KIND_CONFIG_FILE" <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: k3
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
  - role: worker
  - role: worker
EOF

if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "Deleting existing cluster '${CLUSTER_NAME}'..."
  kind delete cluster --name "$CLUSTER_NAME"
fi

echo "[2/6] Creating new Kind cluster '${CLUSTER_NAME}'..."
kind create cluster --config "$KIND_CONFIG_FILE"

echo "[3/6] Installing Ingress NGINX (Kind version)..."
kubectl apply -f "$INGRESS_DEPLOY_URL"

echo "Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=Available deploy/ingress-nginx-controller \
  --timeout=180s
echo "Ingress NGINX Controller is ready."

echo "[4/6] Deploying NGINX demo (3 replicas + Service)..."
cat <<'EOF' | tee nginx-deploy.ingress.yaml | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-demo
  template:
    metadata:
      labels:
        app: nginx-demo
    spec:
      initContainers:
        - name: init-index
          image: busybox:1.36
          command: ["sh", "-c"]
          args: ["echo Pod: $(hostname) > /usr/share/nginx/html/index.html"]
          volumeMounts:
            - name: web
              mountPath: /usr/share/nginx/html
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: web
              mountPath: /usr/share/nginx/html
      volumes:
        - name: web
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
spec:
  selector:
    app: nginx-demo
  ports:
    - name: http
      port: 80
      targetPort: 80
EOF

echo "Waiting for NGINX demo pods to be ready..."
kubectl rollout status deploy/nginx-demo
echo "NGINX demo is ready."

echo "[5/6] Preparing to create Ingress rule..."

echo "Waiting for job ingress-nginx-admission-patch to complete..."
kubectl wait --namespace ingress-nginx --for=condition=complete job/ingress-nginx-admission-patch --timeout=180s || {
  echo "Warning: job ingress-nginx-admission-patch did not complete in time."
}

echo "Waiting for Admission Webhook endpoint to be ready..."
for i in {1..60}; do
  if kubectl get endpoints -n ingress-nginx ingress-nginx-controller-admission -o jsonpath='{.subsets[0].addresses[0].ip}' &>/dev/null; then
    echo "Ingress Admission Webhook endpoint is ready."
    break
  fi
  echo "Still waiting (${i}/60)..."
  sleep 2
done

echo "Temporarily disabling ValidatingWebhookConfiguration to bypass startup race..."
kubectl delete validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found

echo "Creating Ingress rule for localhost..."
cat <<'EOF' | tee nginx-ingress.yaml | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-svc
                port:
                  number: 80
EOF

echo "Reapplying ValidatingWebhookConfiguration for ingress-nginx..."
kubectl apply -f "$INGRESS_DEPLOY_URL" --prune -l app.kubernetes.io/component=admission-webhook

echo "Waiting a few seconds for Ingress sync..."
sleep 10

echo "[6/6] Testing load balancing via localhost..."
for i in {1..10}; do
  curl -s http://localhost/ || echo "Connection failed"
  echo
  sleep 0.3
done

echo
echo "All done!"
echo "Access http://localhost/ in your browser to test load balancing."
