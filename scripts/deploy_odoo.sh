#!/bin/bash
set -e

CLUSTER_ID=$1
CLIENT=$2
ENV=$3
DOMAIN=$4
CERT_B64=$5
KEY_B64=$6
NAMESPACE="${CLIENT}-${ENV}"

echo "Deploying Odoo to cluster ${CLUSTER_ID} for ${DOMAIN}..."

# 1. Switch context
kubectl config use-context "${CLUSTER_ID}"

# 2. Ensure Ingress Addon
echo "Checking if ingress addon is already enabled..."
if ! kubectl get pods -n ingress-nginx | grep -q "ingress-nginx-controller"; then
    echo "Enabling ingress addon..."
    minikube addons enable ingress -p "${CLUSTER_ID}" --force
fi

echo "Waiting for ingress controller to be ready..."
# Wait for the deployment to exist first
until kubectl get deployment ingress-nginx-controller -n ingress-nginx >/dev/null 2>&1; do
    echo "Waiting for ingress-nginx-controller deployment..."
    sleep 5
done

# Wait for the pods to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Small sleep to let the admission webhook service stabilize
sleep 15

# 3. Create Namespace and Secret
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Decode and apply TLS secret
echo "${CERT_B64}" | base64 -d > tls.crt
echo "${KEY_B64}" | base64 -d > tls.key
kubectl create secret tls odoo-tls --cert=tls.crt --key=tls.key -n "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
rm tls.crt tls.key

# 4. Apply Manifests
export NAMESPACE
export DOMAIN
echo "Applying manifests to namespace ${NAMESPACE} in cluster ${CLUSTER_ID}..."
envsubst < templates/odoo-stack.yaml.tmpl | kubectl apply -f -

echo "Verifying deployment in namespace ${NAMESPACE}..."
kubectl get all -n "${NAMESPACE}"

echo "Deployment for ${DOMAIN} completed."
