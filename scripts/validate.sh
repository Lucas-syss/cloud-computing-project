#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Starting Validation..."

# Get all domains from the known logic or hardcoded list for validation
# Or extract from main.tf/variables? 
# Let's derive from the standard pattern since we know the inputs.

DOMAINS=(
    "odoo.dev.airbnb.local"
    "odoo.prod.airbnb.local"
    "odoo.dev.nike.local"
    "odoo.qa.nike.local"
    "odoo.prod.nike.local"
    "odoo.dev.mcdonalds.local"
    "odoo.qa.mcdonalds.local"
    "odoo.beta.mcdonalds.local"
    "odoo.prod.mcdonalds.local"
)

FAILED=0

for DOMAIN in "${DOMAINS[@]}"; do
    echo -n "Checking https://${DOMAIN} ... "
    
    # -k for insecure (self-signed certs), -s for silent, -o /dev/null to discard output, -w for http code
    HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}")
    
    if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "302" ]]; then
        echo -e "${GREEN}OK (${HTTP_CODE})${NC}"
    else
        echo -e "${RED}FAILED (${HTTP_CODE})${NC}"
        FAILED=1
    fi
done

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}Some checks failed.${NC}"
    exit 1
fi
