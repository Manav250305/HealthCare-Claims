#!/bin/bash

echo "🔧 Fixing Upload Issues"
echo "========================"
echo ""

# Update Lambda to remove ACL
echo "1. Updating Lambda (removing ACL parameter)..."
mkdir -p fix-upload
cat > fix-upload/lambda_function.py << 'EOF'
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

        # Simple presigned URL without ACL
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
                'Access-Control-Allow-Headers': 'Content-Type',
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
EOF

cd fix-upload
zip -q lambda.zip lambda_function.py
cd ..

aws lambda update-function-code \
    --function-name presigned-url-generator \
    --zip-file fileb://fix-upload/lambda.zip \
    --region us-east-1 > /dev/null

rm -rf fix-upload

echo "✓ Lambda updated (ACL removed)"
echo ""

# Update S3 CORS to be more permissive
echo "2. Updating S3 CORS..."
cat > cors.json << 'EOF'
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "HEAD"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": ["ETag", "x-amz-server-side-encryption", "x-amz-request-id"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF

aws s3api put-bucket-cors \
    --bucket healthcare-claims-uploads-1768911696 \
    --cors-configuration file://cors.json \
    --region us-east-1

rm cors.json

echo "✓ CORS updated"
echo ""
echo "=========================================="
echo "✅ All fixes applied!"
echo "=========================================="
echo ""
echo "Testing upload with curl..."
sleep 2
python3 << 'PYEOF'
import boto3
import json

lambda_client = boto3.client('lambda', region_name='us-east-1')
response = lambda_client.invoke(
    FunctionName='presigned-url-generator',
    Payload=json.dumps({"body": json.dumps({"filename": "test.pdf"})})
)
result = json.loads(response['Payload'].read())
body = json.loads(result['body'])
print(f"Upload URL generated: {body['upload_url'][:80]}...")

import subprocess
import tempfile
with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as f:
    f.write(b'%PDF-1.4 test')
    test_file = f.name

result = subprocess.run(
    ['curl', '-X', 'PUT', '-H', 'Content-Type: application/pdf',
     '--data-binary', f'@{test_file}', '-v', body['upload_url']],
    capture_output=True,
    text=True
)

import os
os.unlink(test_file)

if '200 OK' in result.stderr or '200' in result.stderr:
    print("✅ Upload test SUCCESSFUL!")
else:
    print("Response:", result.stderr[-500:] if len(result.stderr) > 500 else result.stderr)
PYEOF

echo ""
echo "Now open the frontend and try uploading:"
echo "  open claims-frontend-live.html"
