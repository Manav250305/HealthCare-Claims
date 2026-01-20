#!/bin/bash

echo "🔐 Deploying Pre-Signed URL Generator Lambda"
echo "============================================="
echo ""

# Create deployment package
mkdir -p presigned-url-lambda
cp presigned_url_lambda.py presigned-url-lambda/lambda_function.py
cd presigned-url-lambda
zip -r ../presigned-url-lambda.zip lambda_function.py
cd ..

# Create Lambda function
echo "Creating Lambda function..."
aws lambda create-function \
    --function-name presigned-url-generator \
    --runtime python3.11 \
    --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/LabRole \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://presigned-url-lambda.zip \
    --timeout 30 \
    --memory-size 256 \
    --region us-east-1 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Lambda function created"
else
    echo "Function exists, updating code..."
    aws lambda update-function-code \
        --function-name presigned-url-generator \
        --zip-file fileb://presigned-url-lambda.zip \
        --region us-east-1 > /dev/null
    echo "✅ Lambda function updated"
fi

# Create API Gateway endpoint for pre-signed URL
echo ""
echo "Creating API Gateway endpoint..."

API_ID=$(jq -r '.api_id' api-config.json 2>/dev/null)

if [ -z "$API_ID" ] || [ "$API_ID" = "null" ]; then
    echo "❌ Error: API Gateway not found. Run ./setup-api-gateway.sh first"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"

# Get root resource
ROOT_ID=$(aws apigateway get-resources \
    --rest-api-id "${API_ID}" \
    --region "${REGION}" \
    --query 'items[?path==`/`].id' \
    --output text)

# Create /upload resource
echo "Creating /upload endpoint..."
UPLOAD_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id "${API_ID}" \
    --parent-id "${ROOT_ID}" \
    --path-part "upload" \
    --region "${REGION}" \
    --query 'id' \
    --output text 2>/dev/null)

if [ -z "$UPLOAD_RESOURCE_ID" ]; then
    # Resource might already exist
    UPLOAD_RESOURCE_ID=$(aws apigateway get-resources \
        --rest-api-id "${API_ID}" \
        --region "${REGION}" \
        --query 'items[?path==`/upload`].id' \
        --output text)
fi

echo "Resource ID: ${UPLOAD_RESOURCE_ID}"

# Create POST method
aws apigateway put-method \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method POST \
    --authorization-type NONE \
    --region "${REGION}" > /dev/null 2>&1

# Create OPTIONS for CORS
aws apigateway put-method \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method OPTIONS \
    --authorization-type NONE \
    --region "${REGION}" > /dev/null 2>&1

# Set up CORS
aws apigateway put-method-response \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Headers":false,"method.response.header.Access-Control-Allow-Methods":false,"method.response.header.Access-Control-Allow-Origin":false}' \
    --region "${REGION}" > /dev/null 2>&1

aws apigateway put-integration \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json":"{\"statusCode\": 200}"}' \
    --region "${REGION}" > /dev/null 2>&1

aws apigateway put-integration-response \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Headers":"'"'"'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"'"'","method.response.header.Access-Control-Allow-Methods":"'"'"'POST,OPTIONS'"'"'","method.response.header.Access-Control-Allow-Origin":"'"'"'*'"'"'"}' \
    --region "${REGION}" > /dev/null 2>&1

# POST method response
aws apigateway put-method-response \
    --rest-api-id "${API_ID}" \
    --resource-id "${UPLOAD_RESOURCE_ID}" \
    --http-method POST \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Origin":false}' \
    --region "${REGION}" > /dev/null 2>&1

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

# Grant permission
STATEMENT_ID="apigateway-upload-$(date +%s)"
aws lambda add-permission \
    --function-name presigned-url-generator \
    --statement-id "${STATEMENT_ID}" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" \
    --region "${REGION}" 2>/dev/null || echo "  (Permission may already exist)"

# Deploy API
echo ""
echo "Deploying API updates..."
aws apigateway create-deployment \
    --rest-api-id "${API_ID}" \
    --stage-name prod \
    --region "${REGION}" > /dev/null

UPLOAD_ENDPOINT="https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/upload"
PROCESS_ENDPOINT="https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/process"

# Update config
cat > api-config.json <<EOF
{
  "api_id": "${API_ID}",
  "upload_endpoint": "${UPLOAD_ENDPOINT}",
  "process_endpoint": "${PROCESS_ENDPOINT}",
  "region": "${REGION}"
}
EOF

echo ""
echo "=========================================="
echo "✅ Upload Endpoint Ready!"
echo "=========================================="
echo ""
echo "Upload Endpoint: ${UPLOAD_ENDPOINT}"
echo "Process Endpoint: ${PROCESS_ENDPOINT}"
echo ""

# Cleanup
rm -rf presigned-url-lambda presigned-url-lambda.zip

echo "Next: Update frontend to use real uploads"
echo "Run: ./update-frontend-realtime.sh"
