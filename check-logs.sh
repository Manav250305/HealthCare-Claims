#!/bin/bash

echo "🔍 Checking Lambda logs for errors..."
echo ""
echo "=== PDF Extractor Logs ==="
aws logs tail /aws/lambda/pdf-extractor --since 2m --format short

echo ""
echo "=== Orchestrator Logs ==="
aws logs tail /aws/lambda/claim-orchestrator --since 2m --format short

echo ""
echo "💡 Tip: Look for errors related to Textract permissions or boto3"
