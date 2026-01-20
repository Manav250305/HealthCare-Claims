#!/bin/bash

CONFIG_FILE="deployment-config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: deployment-config.json not found"
    exit 1
fi

ORCHESTRATOR_FUNCTION=$(jq -r '.resources.lambda_functions.orchestrator' $CONFIG_FILE)
UPLOAD_BUCKET=$(jq -r '.resources.s3_buckets.upload_bucket' $CONFIG_FILE)
TEST_KEY=$(jq -r '.test_event.s3_key' $CONFIG_FILE)

echo "Testing Healthcare Claims Processing System"
echo "==========================================="
echo ""
echo "Invoking: $ORCHESTRATOR_FUNCTION"
echo "PDF: s3://$UPLOAD_BUCKET/$TEST_KEY"
echo ""

PAYLOAD=$(cat <<EOF
{
  "s3_bucket": "$UPLOAD_BUCKET",
  "s3_key": "$TEST_KEY",
  "claim_id": "TEST-$(date +%s)"
}
EOF
)

aws lambda invoke \
    --function-name "$ORCHESTRATOR_FUNCTION" \
    --payload "$PAYLOAD" \
    --cli-binary-format raw-in-base64-out \
    response.json

echo ""
echo "Response:"
cat response.json | jq '.'

echo ""
echo "Check DynamoDB table and S3 results bucket for detailed output"
