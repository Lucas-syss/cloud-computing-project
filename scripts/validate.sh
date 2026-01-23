for client in airbnb-dev airbnb-prod nike-dev nike-qa nike-prod mcdonalds-dev mcdonalds-qa mcdonalds-prod mcdonalds-beta; do
    echo "Testing $client..."
    # Parse the client and env from the string (e.g., nike-dev -> env=dev, client=nike)
    env=$(echo $client | cut -d- -f2)
    company=$(echo $client | cut -d- -f1)
    
    # Construct the URL: http://odoo.<env>.<company>.local
    url="http://odoo.${env}.${company}.local"
    
    # Run curl to check the status code
    curl -o /dev/null -s -w "%{http_code} -> $url\n" $url
done