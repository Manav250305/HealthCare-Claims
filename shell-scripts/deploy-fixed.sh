#!/bin/bash
echo "🔧 Deploying FIXED version..."
mkdir -p lambda-fixed
cp lambda_function_fixed.py lambda-fixed/lambda_function.py
cd lambda-fixed
zip -r ../pdf-fixed.zip lambda_function.py
cd ..
aws lambda update-function-code --function-name pdf-extractor --zip-file fileb://pdf-fixed.zip --region us-east-1 > /dev/null
echo "⏳ Waiting for deployment..."
sleep 5
echo ""
echo "✅ Testing fixed version..."
./test-claim-processing.sh
rm -rf lambda-fixed pdf-fixed.zip
