#!/bin/bash
set -e

# 1. READ INPUTS
CLUSTER_NAME="${CLUSTER_NAME:-}"
CLIENT="${CLIENT:-}"
ENV="${ENV:-}"
DOMAIN="${DOMAIN:-}"
KUBE_CERT="${KUBE_CERT:-}"
KUBE_KEY="${KUBE_KEY:-}"

echo "[$CLUSTER_NAME] Deploying Odoo (Sidecar Mode) for $DOMAIN..."

# 2. CONFIGURE KUBECTL
minikube profile "$CLUSTER_NAME" || exit 1

# 3. NAMESPACE
kubectl create namespace "$CLUSTER_NAME" --dry-run=client -o yaml | kubectl apply -f -

# --- WAIT FOR INGRESS CONTROLLER ---
echo "[$CLUSTER_NAME] Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s
# ----------------------------------------

# 4. CREATE TLS SECRET
CERT_B64=$(echo "$KUBE_CERT" | base64 -w0)
KEY_B64=$(echo "$KUBE_KEY" | base64 -w0)

cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: odoo-tls
  namespace: $CLUSTER_NAME
type: kubernetes.io/tls
data:
  tls.crt: $CERT_B64
  tls.key: $KEY_B64
YAML

# 5. DEPLOY ODOO + POSTGRES 
cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: odoo-stack
  namespace: $CLUSTER_NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: odoo-stack
  template:
    metadata:
      labels:
        app: odoo-stack
    spec:
      containers:
      # --- Container 1: Database ---
      - name: db
        image: postgres:15
        env:
        - name: POSTGRES_DB
          value: postgres
        - name: POSTGRES_PASSWORD
          value: odoo
        - name: POSTGRES_USER
          value: odoo
        ports:
        - containerPort: 5432
        
      # --- Container 2: Odoo App ---
      - name: odoo
        image: odoo:16.0
        ports:
        - containerPort: 8069
        env:
        - name: HOST
          value: "localhost"
        - name: USER
          value: "odoo"
        - name: PASSWORD
          value: "odoo"
---
apiVersion: v1
kind: Service
metadata:
  name: odoo
  namespace: $CLUSTER_NAME
spec:
  selector:
    app: odoo-stack
  ports:
    - protocol: TCP
      port: 8069
      targetPort: 8069
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: odoo-ingress
  namespace: $CLUSTER_NAME
spec:
  tls:
  - hosts:
      - $DOMAIN
    secretName: odoo-tls
  rules:
  - host: $DOMAIN
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: odoo
            port:
              number: 8069
YAML

echo "[$CLUSTER_NAME] Deployment complete."
