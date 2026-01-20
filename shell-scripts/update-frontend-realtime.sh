#!/bin/bash

if [ ! -f api-config.json ]; then
    echo "❌ Error: api-config.json not found"
    echo "Run ./deploy-presigned-upload.sh first"
    exit 1
fi

UPLOAD_ENDPOINT=$(jq -r '.upload_endpoint' api-config.json)
PROCESS_ENDPOINT=$(jq -r '.process_endpoint' api-config.json)

echo "🔄 Updating frontend with API endpoints..."
echo "  Upload: ${UPLOAD_ENDPOINT}"
echo "  Process: ${PROCESS_ENDPOINT}"

sed "s|UPLOAD_ENDPOINT_PLACEHOLDER|${UPLOAD_ENDPOINT}|g; s|PROCESS_ENDPOINT_PLACEHOLDER|${PROCESS_ENDPOINT}|g" \
    claims-frontend-realtime.html > claims-frontend-live.html

echo "✅ Frontend updated!"
echo ""
echo "Open it:"
echo "  open claims-frontend-live.html"
echo ""
echo "Now you can upload ANY PDF and it will be processed!"
