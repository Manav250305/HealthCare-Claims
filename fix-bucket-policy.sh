#!/bin/bash

echo "🔧 Adding Bucket Policy for Presigned URL Uploads"
echo "=================================================="
echo ""

BUCKET="healthcare-claims-uploads-1768911696"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"

# Create bucket policy that allows uploads
cat > bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPresignedUploads",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${BUCKET}/uploads/*"
    },
    {
      "Sid": "AllowLambdaAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${ACCOUNT_ID}:role/HealthcareClaimsLambdaRole"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET}/*",
        "arn:aws:s3:::${BUCKET}"
      ]
    }
  ]
}
EOF

echo "Current bucket policy:"
aws s3api get-bucket-policy --bucket "${BUCKET}" --region "${REGION}" 2>/dev/null | jq -r .Policy | jq . || echo "No policy currently set"

echo ""
echo "Applying new bucket policy..."
aws s3api put-bucket-policy \
    --bucket "${BUCKET}" \
    --policy file://bucket-policy.json \
    --region "${REGION}"

if [ $? -eq 0 ]; then
    echo "✅ Bucket policy applied!"
    echo ""
    echo "Verifying..."
    aws s3api get-bucket-policy --bucket "${BUCKET}" --region "${REGION}" | jq -r .Policy | jq .
    echo ""

    # Test upload again
    echo "Testing upload with new policy..."
    python3 << 'PYEOF'
import boto3
import json
import subprocess
import tempfile

lambda_client = boto3.client('lambda', region_name='us-east-1')
response = lambda_client.invoke(
    FunctionName='presigned-url-generator',
    Payload=json.dumps({"body": json.dumps({"filename": "test-policy.pdf"})})
)
result = json.loads(response['Payload'].read())
body = json.loads(result['body'])

# Create test PDF
with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False, mode='wb') as f:
    f.write(b'%PDF-1.4\n test content')
    test_file = f.name

result = subprocess.run(
    ['curl', '-X', 'PUT', 
     '-H', 'Content-Type: application/pdf',
     '--data-binary', f'@{test_file}',
     '-w', '\nHTTP_CODE:%{http_code}',
     body['upload_url']],
    capture_output=True,
    text=True
)

import os
os.unlink(test_file)

if 'HTTP_CODE:200' in result.stdout:
    print("✅ SUCCESS! Upload works with new bucket policy!")
    print(f"   Uploaded to: {body['s3_key']}")
else:
    print("❌ Still getting error:")
    print(result.stdout)
    print(result.stderr)
PYEOF

else
    echo "❌ Failed to apply bucket policy"
fi

rm -f bucket-policy.json

echo ""
echo "=========================================="
echo "If successful, refresh browser and upload:"
echo "  open claims-frontend-live.html"
echo "=========================================="
