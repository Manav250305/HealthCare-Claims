#!/bin/bash

echo "🔍 Diagnosing S3 Upload Issue"
echo "=============================="
echo ""

BUCKET="healthcare-claims-uploads-1768911696"
REGION="us-east-1"

# Check CORS
echo "1. Checking current CORS configuration..."
aws s3api get-bucket-cors --bucket "${BUCKET}" --region "${REGION}" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ No CORS configuration found"
    echo ""
    echo "Applying CORS..."
    cat > cors.json << 'EOF'
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": ["ETag", "x-amz-server-side-encryption"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF
    aws s3api put-bucket-cors --bucket "${BUCKET}" --cors-configuration file://cors.json --region "${REGION}"
    rm cors.json
    echo "✓ CORS applied"
else
    echo "✓ CORS is configured"
fi

echo ""
echo "2. Checking bucket policy..."
aws s3api get-bucket-policy --bucket "${BUCKET}" --region "${REGION}" 2>/dev/null | jq -r .Policy | jq . 2>/dev/null

echo ""
echo "3. Testing presigned URL generation..."
python3 << 'PYEOF'
import boto3
import json

s3 = boto3.client('s3')
bucket = 'healthcare-claims-uploads-1768911696'

# Generate presigned URL
url = s3.generate_presigned_url(
    'put_object',
    Params={
        'Bucket': bucket,
        'Key': 'test-upload.pdf',
        'ContentType': 'application/pdf'
    },
    ExpiresIn=300
)

print("Generated presigned URL:")
print(url[:100] + "...")
print()
print("Testing URL with curl...")

import subprocess
result = subprocess.run(
    ['curl', '-X', 'PUT', '-H', 'Content-Type: application/pdf', 
     '--data-binary', '@/dev/null', url],
    capture_output=True,
    text=True
)

if result.returncode == 0:
    print("✅ Upload test succeeded!")
else:
    print("❌ Upload test failed")
    print("Error:", result.stderr)
PYEOF

echo ""
echo "=============================="
echo "If you see 403 Forbidden, the issue might be:"
echo "  1. Bucket policy doesn't allow PutObject"
echo "  2. Presigned URL signature issues"
echo ""
echo "Solution: Let me check if we need to update bucket policy..."
