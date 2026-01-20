#!/bin/bash

# Get only the project domains from /etc/hosts
DOMAINS=$(grep -oE "odoo\.[a-z]+\.[a-z]+\.local" /etc/hosts | sort -u)

echo "Validating Odoo endpoints..."

for DOMAIN in $DOMAINS; do
    echo -n "Checking https://${DOMAIN} ... "
    
    # Try up to 5 times with a 5s sleep
    for i in {1..5}; do
        STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}")
        if [ "$STATUS" == "200" ]; then
            echo "OK (200)"
            break
        fi
        
        if [ $i -eq 5 ]; then
            echo "FAILED (Status: $STATUS)"
        else
            sleep 5
        fi
    done
done
