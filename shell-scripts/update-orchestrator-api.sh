#!/bin/bash
echo "📦 Updating orchestrator for API Gateway compatibility..."
mkdir -p lambda-orchestrator-update
cp lambda_function_orchestrator.py lambda-orchestrator-update/lambda_function.py
cd lambda-orchestrator-update
zip -r ../orchestrator-update.zip lambda_function.py
cd ..
aws lambda update-function-code \
    --function-name claim-orchestrator \
    --zip-file fileb://orchestrator-update.zip \
    --region us-east-1 > /dev/null
echo "✅ Orchestrator updated!"
echo "Waiting 5 seconds..."
sleep 5
echo ""
echo "Testing API endpoint..."
curl -X POST https://4uihuye9m0.execute-api.us-east-1.amazonaws.com/prod/process \
  -H 'Content-Type: application/json' \
  -d '{"s3_bucket":"healthcare-claims-uploads-1768911696","s3_key":"test-claims/sample-claim.pdf"}'
rm -rf lambda-orchestrator-update orchestrator-update.zip
