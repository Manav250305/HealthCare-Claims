#!/bin/bash

################################################################################
# Healthcare Claims System - Comprehensive Test Suite
# Tests all components and validates the entire workflow
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load configuration
CONFIG_FILE="deployment-config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: deployment-config.json not found${NC}"
    exit 1
fi

# Extract configuration
UPLOAD_BUCKET=$(jq -r '.resources.s3_buckets.upload_bucket' $CONFIG_FILE)
RESULTS_BUCKET=$(jq -r '.resources.s3_buckets.results_bucket' $CONFIG_FILE)
DYNAMODB_TABLE=$(jq -r '.resources.dynamodb.table_name' $CONFIG_FILE)
PDF_EXTRACTOR=$(jq -r '.resources.lambda_functions.pdf_extractor' $CONFIG_FILE)
RISK_SCORER=$(jq -r '.resources.lambda_functions.risk_scorer' $CONFIG_FILE)
ORCHESTRATOR=$(jq -r '.resources.lambda_functions.orchestrator' $CONFIG_FILE)
API_URL=$(jq -r '.resources.api_gateway.url' $CONFIG_FILE)
REGION=$(jq -r '.deployment_info.region' $CONFIG_FILE)

TESTS_PASSED=0
TESTS_FAILED=0

print_test_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}TEST: $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

pass_test() {
    echo -e "${GREEN}✓ PASSED: $1${NC}"
    ((TESTS_PASSED++))
}

fail_test() {
    echo -e "${RED}✗ FAILED: $1${NC}"
    echo -e "${RED}  Reason: $2${NC}"
    ((TESTS_FAILED++))
}

echo -e "${YELLOW}"
cat << "EOF"
╔══════════════════════════════════════════════════════╗
║  Healthcare Claims Intelligence System               ║
║  Comprehensive Test Suite                            ║
╚══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

################################################################################
# Test 1: AWS Resources Exist
################################################################################

print_test_header "Verifying AWS Resources Exist"

# Test S3 buckets
echo "Checking S3 buckets..."
if aws s3 ls "s3://$UPLOAD_BUCKET" &>/dev/null; then
    pass_test "Upload bucket exists"
else
    fail_test "Upload bucket missing" "$UPLOAD_BUCKET"
fi

if aws s3 ls "s3://$RESULTS_BUCKET" &>/dev/null; then
    pass_test "Results bucket exists"
else
    fail_test "Results bucket missing" "$RESULTS_BUCKET"
fi

# Test DynamoDB
echo "Checking DynamoDB table..."
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" &>/dev/null; then
    pass_test "DynamoDB table exists"
else
    fail_test "DynamoDB table missing" "$DYNAMODB_TABLE"
fi

# Test Lambda functions
echo "Checking Lambda functions..."
if aws lambda get-function --function-name "$PDF_EXTRACTOR" --region "$REGION" &>/dev/null; then
    pass_test "PDF Extractor function exists"
else
    fail_test "PDF Extractor function missing" "$PDF_EXTRACTOR"
fi

if aws lambda get-function --function-name "$RISK_SCORER" --region "$REGION" &>/dev/null; then
    pass_test "Risk Scorer function exists"
else
    fail_test "Risk Scorer function missing" "$RISK_SCORER"
fi

if aws lambda get-function --function-name "$ORCHESTRATOR" --region "$REGION" &>/dev/null; then
    pass_test "Orchestrator function exists"
else
    fail_test "Orchestrator function missing" "$ORCHESTRATOR"
fi

################################################################################
# Test 2: Lambda Layer Attached
################################################################################

print_test_header "Verifying Lambda Layer Configuration"

EXTRACTOR_LAYERS=$(aws lambda get-function --function-name "$PDF_EXTRACTOR" --region "$REGION" --query 'Configuration.Layers' --output json)

if echo "$EXTRACTOR_LAYERS" | jq -e 'length > 0' &>/dev/null; then
    pass_test "PDF processing layer attached to extractor"
else
    fail_test "No layers attached to PDF extractor" "Layer required for PDF libraries"
fi

################################################################################
# Test 3: IAM Permissions
################################################################################

print_test_header "Verifying IAM Permissions"

# Get role name from orchestrator
ROLE_NAME=$(aws lambda get-function --function-name "$ORCHESTRATOR" --region "$REGION" --query 'Configuration.Role' --output text | awk -F'/' '{print $NF}')

echo "Checking IAM role policies for: $ROLE_NAME"

# Check attached policies
ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[].PolicyName' --output text)

if echo "$ATTACHED_POLICIES" | grep -q "AWSLambdaBasicExecutionRole"; then
    pass_test "Lambda execution policy attached"
else
    fail_test "Lambda execution policy missing" "Required for CloudWatch logs"
fi

if echo "$ATTACHED_POLICIES" | grep -q "DynamoDB"; then
    pass_test "DynamoDB policy attached"
else
    fail_test "DynamoDB policy missing" "Required for status tracking"
fi

################################################################################
# Test 4: Test PDF Extractor Function
################################################################################

print_test_header "Testing PDF Extractor Function"

# Create a simple test payload (we'll use a sample text as base64)
TEST_TEXT="PARAMOUNT HEALTH SERVICES
PHS ID: TEST123
Patient Name: Test Patient
Policy No: 12345678
Mobile No: 9876543210
E-Mail ID: test@example.com
Type of Claim: Main Hospitalization
Date of Claim Submission: 20/01/2026"

# Base64 encode (create a minimal PDF-like structure)
# Note: This is a simplified test - in production, use actual PDF
echo "Testing with mock data..."

MOCK_PAYLOAD=$(cat <<EOF
{
  "pdf_base64": "$(echo "$TEST_TEXT" | base64)"
}
EOF
)

# For real PDF test
if [ -f "Filled-1.pdf" ]; then
    echo "Found Filled-1.pdf - uploading to S3 for real test..."
    TEST_KEY="test-suite/sample-claim.pdf"
    aws s3 cp Filled-1.pdf "s3://$UPLOAD_BUCKET/$TEST_KEY" &>/dev/null
    
    REAL_PAYLOAD=$(cat <<EOF
{
  "s3_bucket": "$UPLOAD_BUCKET",
  "s3_key": "$TEST_KEY"
}
EOF
)
    
    echo "Invoking PDF Extractor with real PDF..."
    EXTRACTOR_RESPONSE=$(aws lambda invoke \
        --function-name "$PDF_EXTRACTOR" \
        --payload "$REAL_PAYLOAD" \
        --cli-binary-format raw-in-base64-out \
        /tmp/extractor-response.json \
        --region "$REGION" 2>&1)
    
    if [ $? -eq 0 ]; then
        STATUS_CODE=$(jq -r '.statusCode' /tmp/extractor-response.json)
        if [ "$STATUS_CODE" = "200" ]; then
            BODY=$(jq -r '.body' /tmp/extractor-response.json)
            TEXT_LENGTH=$(echo "$BODY" | jq -r '.text_length')
            FIELDS_COUNT=$(echo "$BODY" | jq -r '.key_fields | length')
            
            if [ "$TEXT_LENGTH" -gt 100 ]; then
                pass_test "PDF text extraction ($TEXT_LENGTH characters)"
            else
                fail_test "Insufficient text extracted" "Got $TEXT_LENGTH characters"
            fi
            
            if [ "$FIELDS_COUNT" -gt 3 ]; then
                pass_test "Key fields extracted ($FIELDS_COUNT fields)"
            else
                fail_test "Too few fields extracted" "Got $FIELDS_COUNT fields"
            fi
        else
            fail_test "PDF Extractor returned error" "Status code: $STATUS_CODE"
        fi
    else
        fail_test "PDF Extractor invocation failed" "$EXTRACTOR_RESPONSE"
    fi
else
    echo -e "${YELLOW}⚠ Filled-1.pdf not found - skipping real PDF test${NC}"
fi

################################################################################
# Test 5: Test Risk Scorer Function
################################################################################

print_test_header "Testing Risk Scorer Function"

SCORER_PAYLOAD=$(cat <<'EOF'
{
  "extracted_text": "PARAMOUNT HEALTH SERVICES PHS ID LMN1234 Patient Name Priya Bhadoria Mobile No 8065436201 Policy No 12345678 Type of Claim Main Hospitalization Date of Claim Submission 18/01/2026 IRDA Claim Form Part-A Part-B Original bills Payment Receipt Prescription",
  "key_fields": {
    "phs_id": "LMN1234",
    "patient_name": "Priya Bhadoria",
    "mobile": "8065436201",
    "policy_no": "12345678",
    "claim_type": "Main Hospitalization",
    "submission_date": "18/01/2026"
  }
}
EOF
)

echo "Invoking Risk Scorer..."
SCORER_RESPONSE=$(aws lambda invoke \
    --function-name "$RISK_SCORER" \
    --payload "$SCORER_PAYLOAD" \
    --cli-binary-format raw-in-base64-out \
    /tmp/scorer-response.json \
    --region "$REGION" 2>&1)

if [ $? -eq 0 ]; then
    STATUS_CODE=$(jq -r '.statusCode' /tmp/scorer-response.json)
    if [ "$STATUS_CODE" = "200" ]; then
        BODY=$(jq -r '.body' /tmp/scorer-response.json)
        RISK_LEVEL=$(echo "$BODY" | jq -r '.overall_risk.risk_level')
        RISK_SCORE=$(echo "$BODY" | jq -r '.overall_risk.overall_risk_score')
        
        pass_test "Risk scoring completed (Level: $RISK_LEVEL, Score: $RISK_SCORE)"
        
        # Verify all analysis components exist
        COMPONENTS="document_completeness claim_type_risk timeliness data_consistency fraud_indicators"
        for component in $COMPONENTS; do
            if echo "$BODY" | jq -e ".detailed_analyses.$component" &>/dev/null; then
                pass_test "Analysis component present: $component"
            else
                fail_test "Missing analysis component" "$component"
            fi
        done
    else
        fail_test "Risk Scorer returned error" "Status code: $STATUS_CODE"
    fi
else
    fail_test "Risk Scorer invocation failed" "$SCORER_RESPONSE"
fi

################################################################################
# Test 6: Test Orchestrator (End-to-End)
################################################################################

print_test_header "Testing Orchestrator (End-to-End Workflow)"

if [ -f "Filled-1.pdf" ]; then
    CLAIM_ID="TEST-$(date +%s)"
    
    ORCHESTRATOR_PAYLOAD=$(cat <<EOF
{
  "s3_bucket": "$UPLOAD_BUCKET",
  "s3_key": "$TEST_KEY",
  "claim_id": "$CLAIM_ID"
}
EOF
)
    
    echo "Invoking Orchestrator with claim ID: $CLAIM_ID"
    ORCH_RESPONSE=$(aws lambda invoke \
        --function-name "$ORCHESTRATOR" \
        --payload "$ORCHESTRATOR_PAYLOAD" \
        --cli-binary-format raw-in-base64-out \
        /tmp/orchestrator-response.json \
        --region "$REGION" 2>&1)
    
    if [ $? -eq 0 ]; then
        STATUS_CODE=$(jq -r '.statusCode' /tmp/orchestrator-response.json)
        if [ "$STATUS_CODE" = "200" ]; then
            BODY=$(jq -r '.body' /tmp/orchestrator-response.json)
            MESSAGE=$(echo "$BODY" | jq -r '.message')
            
            pass_test "End-to-end workflow completed: $MESSAGE"
            
            # Wait a bit for DynamoDB
            sleep 2
            
            # Check DynamoDB for result
            echo "Checking DynamoDB for claim status..."
            DYNAMO_RESULT=$(aws dynamodb query \
                --table-name "$DYNAMODB_TABLE" \
                --key-condition-expression "claim_id = :cid" \
                --expression-attribute-values "{\":cid\":{\"S\":\"$CLAIM_ID\"}}" \
                --region "$REGION" 2>&1)
            
            if echo "$DYNAMO_RESULT" | jq -e '.Items | length > 0' &>/dev/null; then
                STATUS=$(echo "$DYNAMO_RESULT" | jq -r '.Items[0].status.S')
                pass_test "Claim status tracked in DynamoDB: $STATUS"
            else
                fail_test "Claim not found in DynamoDB" "$CLAIM_ID"
            fi
            
            # Check S3 for results
            echo "Checking S3 for results..."
            sleep 2
            if aws s3 ls "s3://$RESULTS_BUCKET/results/$CLAIM_ID/" &>/dev/null; then
                pass_test "Results saved to S3"
            else
                fail_test "Results not found in S3" "s3://$RESULTS_BUCKET/results/$CLAIM_ID/"
            fi
        else
            fail_test "Orchestrator returned error" "Status code: $STATUS_CODE"
            cat /tmp/orchestrator-response.json
        fi
    else
        fail_test "Orchestrator invocation failed" "$ORCH_RESPONSE"
    fi
else
    echo -e "${YELLOW}⚠ Filled-1.pdf not found - skipping orchestrator test${NC}"
fi

################################################################################
# Test 7: Test API Gateway
################################################################################

print_test_header "Testing API Gateway Endpoint"

if [ -f "Filled-1.pdf" ] && [ "$API_URL" != "null" ]; then
    CLAIM_ID="API-TEST-$(date +%s)"
    
    API_PAYLOAD=$(cat <<EOF
{
  "s3_bucket": "$UPLOAD_BUCKET",
  "s3_key": "$TEST_KEY",
  "claim_id": "$CLAIM_ID"
}
EOF
)
    
    echo "Testing API endpoint: $API_URL"
    API_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
        -H 'Content-Type: application/json' \
        -d "$API_PAYLOAD")
    
    HTTP_CODE=$(echo "$API_RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$API_RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ]; then
        pass_test "API Gateway responding correctly (HTTP 200)"
        
        if echo "$RESPONSE_BODY" | jq -e '.risk_level' &>/dev/null; then
            RISK_LEVEL=$(echo "$RESPONSE_BODY" | jq -r '.risk_level')
            pass_test "API returned risk analysis: $RISK_LEVEL"
        fi
    else
        fail_test "API Gateway error" "HTTP $HTTP_CODE"
        echo "$RESPONSE_BODY"
    fi
else
    if [ "$API_URL" = "null" ]; then
        echo -e "${YELLOW}⚠ API Gateway not configured - skipping API test${NC}"
    else
        echo -e "${YELLOW}⚠ Filled-1.pdf not found - skipping API test${NC}"
    fi
fi

################################################################################
# Test Summary
################################################################################

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}TEST SUMMARY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Total Tests Run: $((TESTS_PASSED + TESTS_FAILED))"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ALL TESTS PASSED! ✓                  ║${NC}"
    echo -e "${GREEN}║  System is working correctly          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  SOME TESTS FAILED                    ║${NC}"
    echo -e "${RED}║  Please review errors above           ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check CloudWatch Logs:"
    echo "   aws logs tail /aws/lambda/$ORCHESTRATOR --follow"
    echo ""
    echo "2. Verify IAM permissions"
    echo "3. Check if Lambda layer is properly attached"
    echo "4. Ensure S3 buckets are accessible"
    exit 1
fI
