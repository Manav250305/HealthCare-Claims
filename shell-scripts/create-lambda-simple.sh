#!/bin/bash

echo "📦 Creating presigned-url-generator Lambda"
echo "==========================================="
echo ""

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Delete if exists
echo "Cleaning up any existing function..."
aws lambda delete-function \
    --function-name presigned-url-generator \
    --region "${REGION}" 2>/dev/null
sleep 2

# Create fresh deployment package
echo "Creating deployment package..."
mkdir -p lambda-presigned
cat > lambda-presigned/lambda_function.py << 'LAMBDA_EOF'
import json
import boto3
from datetime import datetime

s3_client = boto3.client('s3')
BUCKET_NAME = 'healthcare-claims-uploads-1768911696'

def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    try:
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event

        filename = body.get('filename', 'unknown.pdf')
        timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
        file_key = f"uploads/{timestamp}_{filename}"

        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': file_key,
                'ContentType': 'application/pdf'
            },
            ExpiresIn=300
        )

        print(f"Generated URL for: {file_key}")

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
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'error': str(e)})
        }
LAMBDA_EOF

cd lambda-presigned
zip -q lambda.zip lambda_function.py
cd ..
mv lambda-presigned/lambda.zip presigned.zip

echo "✓ Package ready"
echo ""

# Create function
echo "Creating Lambda function..."
aws lambda create-function \
    --function-name presigned-url-generator \
    --runtime python3.11 \
    --role "arn:aws:iam::${ACCOUNT_ID}:role/LabRole" \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://presigned.zip \
    --timeout 30 \
    --memory-size 256 \
    --region "${REGION}"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Lambda created successfully!"
else
    echo ""
    echo "❌ Failed to create Lambda"
    exit 1
fi

# Test it
echo ""
echo "Testing Lambda..."
echo '{"filename":"test.pdf"}' > test-event.json
aws lambda invoke \
    --function-name presigned-url-generator \
    --payload file://test-event.json \
    --region "${REGION}" \
    response.json > /dev/null 2>&1

echo ""
echo "Response:"
cat response.json | python3 -m json.tool 2>/dev/null || cat response.json

# Cleanup
rm -rf lambda-presigned presigned.zip test-event.json response.json

echo ""
echo "=========================================="
echo "✅ Ready to configure API Gateway"
echo "=========================================="
echo ""
echo "Next step: ./fix-cors-upload.sh"
