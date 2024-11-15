#!/bin/bash
set -e

# Check prerequisites
command -v aws >/dev/null 2>&1 || { echo "AWS CLI not found. Please install it first."; exit 1; }
command -v node >/dev/null 2>&1 || { echo "Node.js not found. Please install it first."; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "npm not found. Please install it first."; exit 1; }

# Get required variables
if [ -z "$EMAIL" ]; then
    read -p "Enter your email for Cognito user: " EMAIL
fi

if [ -z "$TEMP_PASSWORD" ]; then
    read -s -p "Enter temporary password for Cognito user (min 8 chars, requires numbers, special chars): " TEMP_PASSWORD
    echo
    if [[ ! $TEMP_PASSWORD =~ ^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$ ]]; then
        echo "Password must be at least 8 characters and include numbers and special characters"
        exit 1
    fi
fi

# Check and prompt for AWS configuration if needed
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    read -p "Enter AWS region (e.g., us-east-1): " AWS_REGION
    aws configure set region $AWS_REGION
fi

AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    read -p "Enter AWS access key ID: " AWS_ACCESS_KEY_ID
    read -s -p "Enter AWS secret access key: " AWS_SECRET_ACCESS_KEY
    echo
    aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
    aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
    aws configure set output json
fi

# Verify AWS configuration
if ! aws sts get-caller-identity &>/dev/null; then
    echo "Error: AWS credentials invalid"
    exit 1
fi
echo "AWS credentials verified for region: $AWS_REGION"

# Install AWS CDK CLI if needed
if ! command -v cdk &> /dev/null; then
    echo "Installing AWS CDK CLI..."
    npm install -g aws-cdk
fi

# Clone repository
git clone https://github.com/awslabs/multi-agent-orchestrator.git
cd multi-agent-orchestrator

# Navigate to demo app directory
cd examples/chat-demo-app

# Install dependencies
npm install

# Bootstrap CDK
cdk bootstrap

# Deploy the stack
cdk deploy --require-approval never

# Get the user pool ID from stack outputs
USER_POOL_ID=$(aws cloudformation describe-stacks --stack-name ChatDemoAppStack --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' --output text)

# Create Cognito user
aws cognito-idp admin-create-user \
    --user-pool-id $USER_POOL_ID \
    --username $EMAIL \
    --user-attributes Name=email,Value=$EMAIL \
    --temporary-password $TEMP_PASSWORD \
    --message-action SUPPRESS \
    --region $AWS_REGION

echo "Setup complete! Check the CloudFormation outputs for the web app URL"
echo "Login with email: $EMAIL"
echo "Temporary password: $TEMP_PASSWORD"