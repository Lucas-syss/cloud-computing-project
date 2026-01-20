#!/bin/bash
set -e

echo "Updating /etc/hosts..."

# Get all minikube profiles
PROFILES=$(minikube profile list -o json | jq -r '.valid[].Name')

for PROFILE in $PROFILES; do
    IP=$(minikube ip -p "$PROFILE")
    # Extract client and env from profile name (e.g., airbnb-dev)
    CLIENT=$(echo "$PROFILE" | cut -d'-' -f1)
    ENV=$(echo "$PROFILE" | cut -d'-' -f2)
    DOMAIN="odoo.${ENV}.${CLIENT}.local"

    echo "Mapping ${DOMAIN} to ${IP}..."
    
    # Remove existing entry if it exists and add new one
    # We avoid sed -i because /etc/hosts is often a mount point in Docker
    grep -v "${DOMAIN}" /etc/hosts > /etc/hosts.tmp || true
    echo "${IP} ${DOMAIN}" >> /etc/hosts.tmp
    cat /etc/hosts.tmp > /etc/hosts
    rm /etc/hosts.tmp
done

echo "/etc/hosts updated successfully."
