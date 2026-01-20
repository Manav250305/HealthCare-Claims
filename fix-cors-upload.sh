#!/bin/bash

echo "🔧 Fixing CORS for Upload Endpoint"
echo "===================================="
echo ""

API_ID=$(jq -r '.api_id' api-config.json)
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Get upload resource ID
UPLOAD_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id "${API_ID}" \
    --region "${REGION}" \
    --query 'items[?path==`/upload`].id' \
    --output text)

echo "API ID: ${API_ID}"
echo "Upload Resource ID: ${UPLOAD_RESOURCE_ID}"
echo ""

# Delete existing methods to start fresh
echo "Cleaning up existing methods..."
aws apigateway delete-method \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method POST \
    --region "${REGION}" 2>/dev/null

aws apigateway delete-method \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method OPTIONS \
    --region "${REGION}" 2>/dev/null

echo "✓ Cleaned up"
echo ""

# Create OPTIONS method for CORS
echo "Setting up CORS (OPTIONS method)..."
aws apigateway put-method \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method OPTIONS \
    --authorization-type NONE \
    --region "${REGION}" > /dev/null

aws apigateway put-method-response \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Headers":false,"method.response.header.Access-Control-Allow-Methods":false,"method.response.header.Access-Control-Allow-Origin":false}' \
    --region "${REGION}" > /dev/null

aws apigateway put-integration \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json":"{\"statusCode\": 200}"}' \
    --region "${REGION}" > /dev/null

aws apigateway put-integration-response \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Headers":"'"'"'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"'"'","method.response.header.Access-Control-Allow-Methods":"'"'"'POST,OPTIONS'"'"'","method.response.header.Access-Control-Allow-Origin":"'"'"'*'"'"'"}' \
    --region "${REGION}" > /dev/null

echo "✓ CORS configured"
echo ""

# Create POST method
echo "Setting up POST method..."
aws apigateway put-method \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method POST \
    --authorization-type NONE \
    --region "${REGION}" > /dev/null

aws apigateway put-method-response \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method POST \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Origin":false}' \
    --region "${REGION}" > /dev/null

# Lambda integration
LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:presigned-url-generator"

aws apigateway put-integration \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
    --region "${REGION}" > /dev/null

echo "✓ POST method configured"
echo ""

# Add Lambda permission
echo "Adding Lambda permission..."
STATEMENT_ID="apigateway-upload-fixed-$(date +%s)"
aws lambda add-permission \
    --function-name presigned-url-generator \
    --statement-id "${STATEMENT_ID}" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*/upload" \
    --region "${REGION}" 2>/dev/null || echo "  (Permission already exists)"

echo "✓ Permission granted"
echo ""

# Deploy changes
echo "Deploying API..."
aws apigateway create-deployment \
    --rest-api-id "${API_ID}" \
    --stage-name prod \
    --region "${REGION}" > /dev/null

echo "✓ Deployed"
echo ""
echo "=========================================="
echo "✅ CORS Fixed!"
echo "=========================================="
echo ""
echo "Test the upload endpoint:"
echo "curl -X POST https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/upload \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{"filename":"test.pdf"}'"
echo ""
echo "Refresh browser and try uploading!"
