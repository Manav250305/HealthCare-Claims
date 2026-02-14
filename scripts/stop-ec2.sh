#!/bin/bash

INSTANCE_ID="i-YOUR-INSTANCE-ID"  # Replace with your actual instance ID
REGION="us-east-1"

echo "🛑 Stopping EC2 instance..."
aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION

echo "⏳ Waiting for instance to stop..."
aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID --region $REGION

echo "✅ Instance stopped!"
echo "💰 You're now in savings mode: ~$0.80/month"
