#!/bin/bash
mkdir -p lambda-debug
cp lambda_function_debug.py lambda-debug/lambda_function.py
cd lambda-debug
zip -r ../pdf-debug.zip lambda_function.py
cd ..
aws lambda update-function-code --function-name pdf-extractor --zip-file fileb://pdf-debug.zip --region us-east-1 > /dev/null
echo "Waiting for deployment..."
sleep 5
echo "Testing with debug logging..."
./test-claim-processing.sh
echo ""
echo "Check logs with: ./check-logs.sh"
rm -rf lambda-debug pdf-debug.zip
