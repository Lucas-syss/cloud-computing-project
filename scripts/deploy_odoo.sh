#!/bin/bash
set -e

CLUSTER_ID=$1
CLIENT=$2
ENV=$3
DOMAIN=$4
CERT_B64=$5
KEY_B64=$6
NAMESPACE="${CLIENT}-${ENV}"

echo "[${CLUSTER_ID}] Deploying Odoo for ${DOMAIN}..."

# 1. Switch context
kubectl config use-context "${CLUSTER_ID}"

# 2. Ensure Ingress Addon is enabled and ready
if ! minikube addons list -p "${CLUSTER_ID}" | grep -q "ingress: enabled"; then
    echo "Enabling ingress addon..."
    minikube addons enable ingress -p "${CLUSTER_ID}"
fi

# Wait for ingress controller to be fully ready
echo "Waiting for ingress controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s || echo "Warning: Ingress wait timed out, proceeding anyway..."

# 3. Create Namespace
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# 4. Create TLS Secret
echo "${CERT_B64}" | base64 -d > "certs/${DOMAIN}.crt"
echo "${KEY_B64}" | base64 -d > "certs/${DOMAIN}.key"

# Create certs dir if not exists (it should be created by script if not)
mkdir -p certs

kubectl create secret tls odoo-tls \
  --cert="certs/${DOMAIN}.crt" \
  --key="certs/${DOMAIN}.key" \
  -n "${NAMESPACE}" \
  --dry-run=client -o yaml | kubectl apply -f -

rm "certs/${DOMAIN}.crt" "certs/${DOMAIN}.key"

# 5. Apply Manifests using envsubst
export NAMESPACE
export DOMAIN

# We need to make sure we don't substitute $ in the wrong places if any (yaml doesn't usually have $, but good to be careful)
# Using envsubst to replace only ${NAMESPACE} and ${DOMAIN} is safer if we had other vars, but here we can replace all.
envsubst < templates/odoo-stack.yaml.tmpl | kubectl apply -f -

# 6. Verify Rollout
kubectl rollout status deployment/odoo -n "${NAMESPACE}" --timeout=120s
kubectl rollout status statefulset/db -n "${NAMESPACE}" --timeout=120s

echo "Deployment for ${DOMAIN} completed successfully."
