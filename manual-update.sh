#!/bin/bash
# Manual Lambda Update Commands

echo "📦 Creating deployment package..."
mkdir -p lambda-deploy
cp lambda_function.py lambda-deploy/
cd lambda-deploy
zip -r ../pdf-extractor-textract.zip lambda_function.py
cd ..

echo "🚀 Updating Lambda function..."
aws lambda update-function-code \
    --function-name pdf-extractor \
    --zip-file fileb://pdf-extractor-textract.zip \
    --region us-east-1

echo "✅ Lambda function updated!"
echo ""
echo "Waiting 5 seconds for deployment to complete..."
sleep 5

echo ""
echo "Testing the updated function..."
./test-claim-processing.sh

# Cleanup
rm -rf lambda-deploy pdf-extractor-textract.zip
