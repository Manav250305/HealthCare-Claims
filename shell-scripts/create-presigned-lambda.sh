#!/bin/bash

echo "🔍 Checking presigned-url-generator Lambda"
echo "==========================================="
echo ""

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Check if function exists
if aws lambda get-function --function-name presigned-url-generator --region "${REGION}" 2>/dev/null > /dev/null; then
    echo "✓ Function exists, updating code..."
else
    echo "✗ Function does not exist, creating..."
fi

# Create deployment package
echo "Building deployment package..."
mkdir -p temp-presigned
cat > temp-presigned/lambda_function.py << 'EOF'
import json
import boto3
from datetime import datetime

s3_client = boto3.client('s3')
BUCKET_NAME = 'healthcare-claims-uploads-1768911696'

def lambda_handler(event, context):
    """
    Generate pre-signed URL for direct browser upload to S3
    """
    print(f"Received event: {json.dumps(event)}")

    try:
        # Handle API Gateway event
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event

        filename = body.get('filename', 'unknown.pdf')
        print(f"Generating presigned URL for: {filename}")

        # Generate unique key with timestamp
        timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
        file_key = f"uploads/{timestamp}_{filename}"

        # Generate pre-signed URL for PUT operation
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': file_key,
                'ContentType': 'application/pdf'
            },
            ExpiresIn=300  # URL expires in 5 minutes
        )

        print(f"Generated URL for key: {file_key}")

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'POST,OPTIONS',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'upload_url': presigned_url,
                's3_bucket': BUCKET_NAME,
                's3_key': file_key
            })
        }

    except Exception as e:
        print(f"Error generating presigned URL: {str(e)}")
        import traceback
        traceback.print_exc()

        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST,OPTIONS',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': str(e)
            })
        }
EOF

cd temp-presigned
zip -q ../presigned-lambda.zip lambda_function.py
cd ..

echo "✓ Package created"
echo ""

# Try to create function
echo "Creating/Updating Lambda function..."
aws lambda create-function \
    --function-name presigned-url-generator \
    --runtime python3.11 \
    --role arn:aws:iam::${ACCOUNT_ID}:role/LabRole \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://presigned-lambda.zip \
    --timeout 30 \
    --memory-size 256 \
    --region "${REGION}" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Function exists, updating code..."
    aws lambda update-function-code \
        --function-name presigned-url-generator \
        --zip-file fileb://presigned-lambda.zip \
        --region "${REGION}" > /dev/null

    # Wait for update to complete
    sleep 3
    echo "✓ Function updated"
else
    echo "✓ Function created"
fi

# Cleanup
rm -rf temp-presigned presigned-lambda.zip

echo ""
echo "Testing Lambda directly..."
aws lambda invoke \
    --function-name presigned-url-generator \
    --payload '{"filename":"test.pdf"}' \
    --region "${REGION}" \
    test-response.json > /dev/null

echo ""
echo "Lambda Response:"
cat test-response.json | jq .
rm -f test-response.json

echo ""
echo "✅ Lambda is ready!"
echo ""
echo "Now run the CORS fix again:"
echo "  ./fix-cors-upload.sh"
