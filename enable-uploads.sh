#!/bin/bash

echo "🔓 Disabling Block Public Access for Uploads"
echo "============================================="
echo ""

BUCKET="healthcare-claims-uploads-1768911696"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"

# Disable block public access
echo "Disabling Block Public Access..."
aws s3api put-public-access-block \
    --bucket "${BUCKET}" \
    --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" \
    --region "${REGION}"

if [ $? -eq 0 ]; then
    echo "✓ Block Public Access disabled"
else
    echo "❌ Failed to disable Block Public Access"
    exit 1
fi

echo ""
echo "Waiting for settings to propagate..."
sleep 3

# Now apply bucket policy
echo "Applying bucket policy..."
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

aws s3api put-bucket-policy \
    --bucket "${BUCKET}" \
    --policy file://bucket-policy.json \
    --region "${REGION}"

if [ $? -eq 0 ]; then
    echo "✓ Bucket policy applied successfully!"
    echo ""

    # Verify
    echo "Verifying policy..."
    aws s3api get-bucket-policy --bucket "${BUCKET}" --region "${REGION}" | jq -r .Policy | jq .
    echo ""

    # Test upload
    echo "Testing presigned URL upload..."
    python3 << 'PYEOF'
import boto3
import json
import subprocess
import tempfile

lambda_client = boto3.client('lambda', region_name='us-east-1')
response = lambda_client.invoke(
    FunctionName='presigned-url-generator',
    Payload=json.dumps({"body": json.dumps({"filename": "test-final.pdf"})})
)
result = json.loads(response['Payload'].read())
body = json.loads(result['body'])

# Create test PDF
with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False, mode='wb') as f:
    f.write(b'%PDF-1.4\ntest')
    test_file = f.name

result = subprocess.run(
    ['curl', '-X', 'PUT', 
     '-H', 'Content-Type: application/pdf',
     '--data-binary', f'@{test_file}',
     '-w', '\nHTTP_CODE:%{http_code}',
     '-s',
     body['upload_url']],
    capture_output=True,
    text=True
)

import os
os.unlink(test_file)

print()
if 'HTTP_CODE:200' in result.stdout:
    print("✅ ✅ ✅ SUCCESS! Upload works!")
    print(f"   File uploaded to: {body['s3_key']}")
    print()
    print("🎉 Real-time uploads are now working!")
    print()
    print("Open the frontend and upload your PDF:")
    print("  open claims-frontend-live.html")
else:
    print("❌ Still having issues:")
    print("Response:", result.stdout)
    if result.stderr:
        print("Error:", result.stderr)
PYEOF

else
    echo "❌ Failed to apply bucket policy"
    exit 1
fi

rm -f bucket-policy.json
