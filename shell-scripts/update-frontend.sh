#!/bin/bash

if [ ! -f api-config.json ]; then
    echo "Error: api-config.json not found. Run ./setup-api-gateway.sh first"
    exit 1
fi

API_ENDPOINT=$(jq -r '.api_endpoint' api-config.json)
S3_BUCKET="healthcare-claims-uploads-1768911696"

echo "Updating frontend with API endpoint..."
echo "API: ${API_ENDPOINT}"

# Update the frontend HTML with real API endpoint
sed -i.bak "s|const API_ENDPOINT = '.*';|const API_ENDPOINT = '${API_ENDPOINT}';|g" claims-frontend.html
sed -i.bak "s|const USE_DEMO = true;|const USE_DEMO = false;|g" claims-frontend.html

echo "✅ Frontend updated!"
echo ""
echo "Open the frontend:"
echo "  open claims-frontend.html"
