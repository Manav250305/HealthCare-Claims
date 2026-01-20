#!/bin/bash

echo "🔧 Adding CORS Configuration to S3 Bucket"
echo "=========================================="
echo ""

BUCKET="healthcare-claims-uploads-1768911696"
REGION="us-east-1"

# Create CORS configuration
cat > cors-config.json << 'EOF'
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF

echo "Applying CORS configuration to ${BUCKET}..."
aws s3api put-bucket-cors \
    --bucket "${BUCKET}" \
    --cors-configuration file://cors-config.json \
    --region "${REGION}"

if [ $? -eq 0 ]; then
    echo "✅ CORS configuration applied!"
    echo ""
    echo "Verifying..."
    aws s3api get-bucket-cors --bucket "${BUCKET}" --region "${REGION}"
    echo ""
    echo "=========================================="
    echo "✅ S3 Bucket CORS Configured!"
    echo "=========================================="
    echo ""
    echo "Now refresh your browser and try uploading again!"
    echo "  open claims-frontend-live.html"
else
    echo "❌ Failed to apply CORS configuration"
fi

rm -f cors-config.json
