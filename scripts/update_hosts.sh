#!/bin/bash
set -e

# Path to the hosts file
HOSTS_FILE="/etc/hosts"
# Marker for our section
START_MARKER="#### CLOUD-PROJ-START ####"
END_MARKER="#### CLOUD-PROJ-END ####"

# Create a temporary file for new hosts entries
TEMP_HOSTS=$(mktemp)

echo "${START_MARKER}" > "${TEMP_HOSTS}"

# Get all running minikube profiles and their IPs
PROFILES=$(minikube profile list -o json | jq -r '.valid[] | .Name')

for PROFILE in ${PROFILES}; do
    IP=$(minikube ip -p "${PROFILE}")
    # Extract client and env from profile name (format: client-env)
    # But wait, the domain depends on the mapping in terraform.
    # The profile name is client-env.
    # The domain is odoo.env.client.local
    
    # Split profile by last hyphen to separate client and env?
    # Actually, simplistic split might fail if client has hyphens.
    # Assuming standard format from main.tf: ${client_name}-${env}
    
    # We can reconstruct because the profile IDs match the structure.
    # But we need to perform the exact string manipulation.
    # Easier: Just loop through the known domains? No, we need dynamic from minikube.
    
    # Let's rely on the profile name convention: CLIENT-ENV.
    # If client is "airbnb" and env is "dev", profile is "airbnb-dev".
    # Domain: odoo.dev.airbnb.local
    
    # Regex to capture parts. Assumes env doesn't have hyphens.
    if [[ $PROFILE =~ ^(.+)-([^-]+)$ ]]; then
        CLIENT="${BASH_REMATCH[1]}"
        ENV="${BASH_REMATCH[2]}"
        DOMAIN="odoo.${ENV}.${CLIENT}.local"
        echo "${IP} ${DOMAIN}" >> "${TEMP_HOSTS}"
    fi
done

echo "${END_MARKER}" >> "${TEMP_HOSTS}"

# Read the current hosts file, excluding our old section
# We'll use sed to delete the range between markers if it exists
if grep -q "${START_MARKER}" "${HOSTS_FILE}"; then
    # Create temp file without our section
    sed "/${START_MARKER}/,/${END_MARKER}/d" "${HOSTS_FILE}" > "${HOSTS_FILE}.tmp"
    mv "${HOSTS_FILE}.tmp" "${HOSTS_FILE}"
fi

# Append our new section
cat "${TEMP_HOSTS}" >> "${HOSTS_FILE}"

rm "${TEMP_HOSTS}"

echo "Updated /etc/hosts with Minikube IPs."
