#!/bin/bash

echo "🔍 Getting IAM role from existing Lambda functions..."
echo ""

# Get role from claim-orchestrator
ROLE_ARN=$(aws lambda get-function \
    --function-name claim-orchestrator \
    --region us-east-1 \
    --query 'Configuration.Role' \
    --output text)

echo "Role ARN: ${ROLE_ARN}"
echo ""

# Now create the presigned Lambda with the correct role
echo "📦 Creating presigned-url-generator Lambda with correct role"
echo ""

REGION="us-east-1"

# Delete if exists
aws lambda delete-function \
    --function-name presigned-url-generator \
    --region "${REGION}" 2>/dev/null
sleep 2

# Create deployment package
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

echo "Creating Lambda function with role: ${ROLE_ARN}"
aws lambda create-function \
    --function-name presigned-url-generator \
    --runtime python3.11 \
    --role "${ROLE_ARN}" \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://presigned.zip \
    --timeout 30 \
    --memory-size 256 \
    --region "${REGION}"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Lambda created successfully!"

    # Test it
    echo ""
    echo "Testing Lambda..."
    echo '{"filename":"test.pdf"}' > test-event.json
    aws lambda invoke \
        --function-name presigned-url-generator \
        --payload file://test-event.json \
        --region "${REGION}" \
        response.json > /dev/null 2>&1

    echo "Response:"
    cat response.json | python3 -m json.tool 2>/dev/null || cat response.json
    echo ""

    rm -f test-event.json response.json
else
    echo ""
    echo "❌ Failed to create Lambda"
    exit 1
fi

# Cleanup
rm -rf lambda-presigned presigned.zip

echo ""
echo "=========================================="
echo "✅ Lambda Ready!"
echo "=========================================="
echo ""
echo "Next: ./fix-cors-upload.sh"
