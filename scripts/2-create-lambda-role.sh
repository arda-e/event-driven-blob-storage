#!/bin/bash
set -e

ROLE_NAME="FileProcessorLambdaRole"

echo "Creating Lambda IAM role: $ROLE_NAME"

# Check if role exists
if aws iam get-role --role-name "$ROLE_NAME" 2>/dev/null; then
  echo "Role already exists: $ROLE_NAME"
else
  echo "Creating role..."
  
  # Create role
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file://infrastructure/lambda-trust-policy.json \
    > /dev/null
  
  echo "Role created"
fi

# Attach/update permissions (even if role exists, update policy)
echo "Attaching permissions..."
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name FileProcessorPermissions \
  --policy-document file://infrastructure/lambda-permissions.json

echo "Permissions attached"

# Get role ARN
ROLE_ARN=$(aws iam get-role \
  --role-name "$ROLE_NAME" \
  --query 'Role.Arn' \
  --output text)

echo ""
echo "Lambda role ready"
echo "Role ARN: $ROLE_ARN"

# Save role info
cat > infrastructure/lambda-role-info.txt << ROLE_EOF
ROLE_NAME=$ROLE_NAME
ROLE_ARN=$ROLE_ARN
ROLE_EOF

echo ""
echo "Waiting 10 seconds for IAM propagation..."
sleep 10
echo "Ready to create Lambda function"
