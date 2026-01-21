#!/bin/bash
set -e

echo "Fetching Minikube IPs for all clients..."

# Function to update a single entry safely in Docker
update_host() {
    local ip=$1
    local domain=$2
    
    # 1. Copy current hosts to a temp file
    cp /etc/hosts /tmp/hosts.tmp
    
    # 2. Remove old entry for this domain from the temp file
    sed -i "/$domain/d" /tmp/hosts.tmp
    
    # 3. Append the new entry to the temp file
    echo "$ip $domain" >> /tmp/hosts.tmp
    
    # 4. Overwrite /etc/hosts content with the temp file content
    cat /tmp/hosts.tmp > /etc/hosts
    
    echo " + Added: $domain -> $ip"
}

# 1. AIRBNB (Dev, Prod)
for env in dev prod; do
    cluster="airbnb-$env"
    domain="odoo.$env.airbnb.local"
    ip=$(minikube ip -p "$cluster" 2>/dev/null || echo "")
    if [ ! -z "$ip" ]; then update_host "$ip" "$domain"; fi
done

# 2. NIKE (Dev, QA, Prod)
for env in dev qa prod; do
    cluster="nike-$env"
    domain="odoo.$env.nike.local"
    ip=$(minikube ip -p "$cluster" 2>/dev/null || echo "")
    if [ ! -z "$ip" ]; then update_host "$ip" "$domain"; fi
done

# 3. MCDONALDS (Dev, QA, Beta, Prod)
for env in dev qa beta prod; do
    cluster="mcdonalds-$env"
    domain="odoo.$env.mcdonalds.local"
    ip=$(minikube ip -p "$cluster" 2>/dev/null || echo "")
    if [ ! -z "$ip" ]; then update_host "$ip" "$domain"; fi
done

echo "Hosts file updated successfully."