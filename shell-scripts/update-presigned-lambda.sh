#!/bin/bash

echo "📦 Updating presigned-url-generator Lambda"
echo "=========================================="
echo ""

# Create deployment package
mkdir -p lambda-update
cat > lambda-update/lambda_function.py << 'EOF'
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

        # Generate pre-signed URL with CORS-compatible parameters
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': BUCKET_NAME,
                'Key': file_key,
                'ContentType': 'application/pdf',
                'ACL': 'private'
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
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'error': str(e)})
        }
EOF

cd lambda-update
zip -q lambda.zip lambda_function.py
cd ..

echo "Updating Lambda function..."
aws lambda update-function-code \
    --function-name presigned-url-generator \
    --zip-file fileb://lambda-update/lambda.zip \
    --region us-east-1 > /dev/null

if [ $? -eq 0 ]; then
    echo "✅ Lambda updated!"
    echo ""
    echo "Testing..."
    sleep 2
    python3 test-presigned.py
else
    echo "❌ Update failed"
fi

rm -rf lambda-update
