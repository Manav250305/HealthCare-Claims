#!/bin/bash

echo "🧪 Testing presigned-url-generator"
echo "==================================="
echo ""

# Create payload file
cat > payload.json << 'EOF'
{
  "body": "{"filename":"test.pdf"}"
}
EOF

echo "Testing Lambda with payload file..."
aws lambda invoke \
    --function-name presigned-url-generator \
    --payload file://payload.json \
    --region us-east-1 \
    response.json

echo ""
echo "Raw Response:"
cat response.json
echo ""
echo ""

# Parse the response
if [ -f response.json ] && grep -q "upload_url" response.json; then
    echo "✅ SUCCESS! Lambda is generating presigned URLs!"
    echo ""

    # Pretty print
    echo "Parsed Response:"
    cat response.json | python3 -m json.tool
    echo ""

    # Extract key info
    S3_KEY=$(cat response.json | python3 -c "import sys, json; r=json.load(sys.stdin); b=json.loads(r['body']); print(b.get('s3_key', 'N/A'))" 2>/dev/null)
    echo "📁 S3 Key that will be used: ${S3_KEY}"
    echo ""
    echo "✅ Lambda is ready!"
    echo ""
    echo "Next step: Configure API Gateway"
    echo "  ./fix-cors-upload.sh"

elif [ -f response.json ]; then
    echo "⚠️  Lambda responded but format is unexpected:"
    cat response.json | python3 -m json.tool 2>/dev/null || cat response.json
else
    echo "❌ No response file created"
fi

# Cleanup
rm -f payload.json response.json
