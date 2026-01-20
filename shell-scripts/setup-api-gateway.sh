#!/bin/bash

# API Gateway Setup for Healthcare Claims System
set -e

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_FUNCTION="claim-orchestrator"
API_NAME="HealthcareClaimsAPI"

echo "🔧 Setting up API Gateway for Claims Processing System..."
echo ""

# Check if API already exists and delete it
echo "Checking for existing API..."
EXISTING_API=$(aws apigateway get-rest-apis --region "${REGION}" --query "items[?name=='${API_NAME}'].id" --output text)
if [ ! -z "$EXISTING_API" ]; then
    echo "Found existing API: ${EXISTING_API}. Deleting..."
    aws apigateway delete-rest-api --rest-api-id "${EXISTING_API}" --region "${REGION}"
    echo "✓ Old API deleted"
    sleep 2
fi

# Create REST API
echo "Creating REST API..."
API_ID=$(aws apigateway create-rest-api \
    --name "${API_NAME}" \
    --description "API for Healthcare Claims Processing" \
    --region "${REGION}" \
    --endpoint-configuration types=REGIONAL \
    --query 'id' \
    --output text)

echo "✓ API created: ${API_ID}"

# Get root resource ID
ROOT_ID=$(aws apigateway get-resources \
    --rest-api-id "${API_ID}" \
    --region "${REGION}" \
    --query 'items[0].id' \
    --output text)

# Create /process resource
echo "Creating /process endpoint..."
RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id "${API_ID}" \
    --parent-id "${ROOT_ID}" \
    --path-part "process" \
    --region "${REGION}" \
    --query 'id' \
    --output text)

echo "✓ Resource created"

# Create OPTIONS method for CORS preflight
echo "Setting up CORS..."
aws apigateway put-method \
    --rest-api-id "${API_ID}" \
    --resource-id "${RESOURCE_ID}" \
    --http-method OPTIONS \
    --authorization-type NONE \
    --region "${REGION}" > /dev/null

aws apigateway put-method-response \
    --rest-api-id "${API_ID}" \
    --resource-id "${RESOURCE_ID}" \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Headers":false,"method.response.header.Access-Control-Allow-Methods":false,"method.response.header.Access-Control-Allow-Origin":false}' \
    --region "${REGION}" > /dev/null

aws apigateway put-integration \
    --rest-api-id "${API_ID}" \
    --resource-id "${RESOURCE_ID}" \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json":"{\"statusCode\": 200}"}' \
    --region "${REGION}" > /dev/null

aws apigateway put-integration-response \
    --rest-api-id "${API_ID}" \
    --resource-id "${RESOURCE_ID}" \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Headers":"'"'"'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"'"'","method.response.header.Access-Control-Allow-Methods":"'"'"'POST,OPTIONS'"'"'","method.response.header.Access-Control-Allow-Origin":"'"'"'*'"'"'"}' \
    --region "${REGION}" > /dev/null

echo "✓ CORS configured"

# Create POST method
echo "Creating POST method..."
aws apigateway put-method \
    --rest-api-id "${API_ID}" \
    --resource-id "${RESOURCE_ID}" \
    --http-method POST \
    --authorization-type NONE \
    --region "${REGION}" > /dev/null

# Enable CORS for POST response
aws apigateway put-method-response \
    --rest-api-id "${API_ID}" \
    --resource-id "${RESOURCE_ID}" \
    --http-method POST \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Origin":false}' \
    --region "${REGION}" > /dev/null

echo "✓ POST method created"

# Set up Lambda integration for POST
echo "Integrating Lambda function..."
LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${LAMBDA_FUNCTION}"

aws apigateway put-integration \
    --rest-api-id "${API_ID}" \
    --resource-id "${RESOURCE_ID}" \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
    --region "${REGION}" > /dev/null

echo "✓ Lambda integration configured"

# Grant API Gateway permission to invoke Lambda
echo "Setting Lambda permissions..."
STATEMENT_ID="apigateway-invoke-$(date +%s)"
aws lambda add-permission \
    --function-name "${LAMBDA_FUNCTION}" \
    --statement-id "${STATEMENT_ID}" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" \
    --region "${REGION}" 2>/dev/null || echo "  (Permission may already exist)"

echo "✓ Permissions granted"

# Deploy API
echo "Deploying API to production..."
aws apigateway create-deployment \
    --rest-api-id "${API_ID}" \
    --stage-name prod \
    --region "${REGION}" > /dev/null

echo "✓ API deployed"

# Get API endpoint
API_ENDPOINT="https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/process"

echo ""
echo "=========================================="
echo "✅ API Gateway Setup Complete!"
echo "=========================================="
echo ""
echo "API Endpoint:"
echo "${API_ENDPOINT}"
echo ""
echo "Test with curl:"
echo "curl -X POST ${API_ENDPOINT} \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{"s3_bucket":"healthcare-claims-uploads-1768911696","s3_key":"test-claims/sample-claim.pdf"}'"
echo ""

# Save config
cat > api-config.json <<EOF
{
  "api_id": "${API_ID}",
  "api_endpoint": "${API_ENDPOINT}",
  "region": "${REGION}"
}
EOF

echo "Configuration saved to: api-config.json"
echo ""
echo "Next step: Update frontend with this endpoint"
echo "Run: ./update-frontend.sh"
