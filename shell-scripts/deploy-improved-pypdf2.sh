#!/bin/bash
echo "📦 Deploying improved PyPDF2 extractor..."
mkdir -p lambda-deploy-improved
cp lambda_function_improved.py lambda-deploy-improved/lambda_function.py
cd lambda-deploy-improved
zip -r ../pdf-extractor-improved.zip lambda_function.py
cd ..

echo "🚀 Updating Lambda function..."
aws lambda update-function-code \
    --function-name pdf-extractor \
    --zip-file fileb://pdf-extractor-improved.zip \
    --region us-east-1

echo "✅ Updated! Waiting 5 seconds..."
sleep 5

echo ""
echo "🧪 Testing improved extraction..."
./test-claim-processing.sh

# Cleanup
rm -rf lambda-deploy-improved pdf-extractor-improved.zip
