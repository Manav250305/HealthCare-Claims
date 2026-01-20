#!/usr/bin/env python3

import boto3
import json

print("🧪 Testing presigned-url-generator with boto3")
print("=" * 50)
print()

# Create Lambda client
lambda_client = boto3.client('lambda', region_name='us-east-1')

# Create test payload
payload = {
    "body": json.dumps({"filename": "test.pdf"})
}

print("Invoking Lambda...")
print(f"Payload: {json.dumps(payload, indent=2)}")
print()

try:
    response = lambda_client.invoke(
        FunctionName='presigned-url-generator',
        InvocationType='RequestResponse',
        Payload=json.dumps(payload)
    )

    # Read response
    result = json.loads(response['Payload'].read())

    print("✅ Lambda Response:")
    print(json.dumps(result, indent=2))
    print()

    # Check if it has upload_url
    if 'body' in result:
        body = json.loads(result['body'])
        if 'upload_url' in body:
            print("✅ SUCCESS! Presigned URL generated:")
            print(f"   S3 Key: {body['s3_key']}")
            print(f"   Upload URL: {body['upload_url'][:80]}...")
            print()
            print("Lambda is working correctly!")
            print()
            print("Next step: Configure API Gateway")
            print("  ./fix-cors-upload.sh")
        else:
            print("❌ Response doesn't contain upload_url")
            print("Body:", body)
    else:
        print("❌ No body in response")

except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
