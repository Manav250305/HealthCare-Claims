#!/bin/bash

echo "🔍 Verifying presigned-url-generator Lambda"
echo "==========================================="
echo ""

# Get the function details
aws lambda get-function \
    --function-name presigned-url-generator \
    --region us-east-1 \
    --query 'Configuration.[FunctionName,Handler,Runtime,LastModified]' \
    --output table

echo ""
echo "Testing with correct payload..."
echo ""

# Create test event
cat > test-presigned.json << 'EOF'
{
  "body": "{"filename":"test.pdf"}"
}
EOF

# Invoke
aws lambda invoke \
    --function-name presigned-url-generator \
    --payload file://test-presigned.json \
    --region us-east-1 \
    presigned-response.json > /dev/null 2>&1

echo "Response:"
cat presigned-response.json | python3 -m json.tool

# Check if it contains upload_url
if grep -q "upload_url" presigned-response.json; then
    echo ""
    echo "✅ Lambda is working correctly!"
    echo ""
    echo "Now configure API Gateway:"
    echo "  ./fix-cors-upload.sh"
else
    echo ""
    echo "❌ Lambda response doesn't contain upload_url"
    echo "This might be the wrong function. Let me check..."

    # Download the code
    URL=$(aws lambda get-function --function-name presigned-url-generator --region us-east-1 --query 'Code.Location' --output text)
    echo ""
    echo "Downloading function code..."
    curl -s "$URL" -o check-lambda.zip
    unzip -q check-lambda.zip
    echo ""
    echo "Lambda code:"
    head -20 lambda_function.py
    rm -f check-lambda.zip lambda_function.py
fi

rm -f test-presigned.json presigned-response.json
