#!/bin/bash

echo "🧪 Testing presigned-url-generator"
echo "==================================="
echo ""

# Wait for function to be active
echo "Waiting for Lambda to be active..."
sleep 3

# Simple direct test
echo "Invoking Lambda..."
aws lambda invoke \
    --function-name presigned-url-generator \
    --payload '{"body": "{\"filename\":\"test.pdf\"}"}' \
    --region us-east-1 \
    response.json

echo ""
echo "Response:"
cat response.json
echo ""
echo ""

# Check for upload_url
if grep -q "upload_url" response.json; then
    echo "✅ Lambda is working! It returns presigned URLs."
    echo ""

    # Parse and show the URL
    UPLOAD_URL=$(cat response.json | python3 -c "import sys, json; data=json.load(sys.stdin); body=json.loads(data['body']); print(body['upload_url'][:80] + '...')" 2>/dev/null)
    S3_KEY=$(cat response.json | python3 -c "import sys, json; data=json.load(sys.stdin); body=json.loads(data['body']); print(body['s3_key'])" 2>/dev/null)

    echo "Generated S3 key: ${S3_KEY}"
    echo ""
    echo "Now set up API Gateway:"
    echo "  ./fix-cors-upload.sh"
else
    echo "❌ Response doesn't look right"
    echo ""
    echo "Checking Lambda logs..."
    aws logs tail /aws/lambda/presigned-url-generator --since 1m --format short --region us-east-1
fi

rm -f response.json
