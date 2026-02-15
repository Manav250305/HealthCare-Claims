#!/bin/bash

INSTANCE_ID="i-0fece1a5965dbfebb"  # Replace with your actual instance ID
REGION="us-east-1"

echo "🚀 Starting EC2 instance..."
aws ec2 start-instances --instance-ids $INSTANCE_ID --region $REGION

echo "⏳ Waiting for instance to start..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

echo "✅ Instance started!"
echo ""
echo "📡 Getting new public IP..."
NEW_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "🌐 New Public IP: $NEW_IP"
echo ""
echo "📝 Update your .env.local file:"
echo "NEXT_PUBLIC_EC2_IP=$NEW_IP"
echo ""
echo "🔧 Or run this command to update automatically:"
echo "sed -i '' 's/NEXT_PUBLIC_EC2_IP=.*/NEXT_PUBLIC_EC2_IP=$NEW_IP/' .env.local"
echo ""
echo "🔗 SSH Command:"
echo "ssh -i ~/.ssh/claims-processor-key.pem ubuntu@$NEW_IP"
