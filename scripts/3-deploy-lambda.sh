#!/bin/bash
set -e

FUNCTION_NAME="FileProcessor"
HANDLER="index.handler"
RUNTIME="nodejs20.x"
TIMEOUT=300
MEMORY=512

# Load configuration
source infrastructure/bucket-info.txt
source infrastructure/lambda-role-info.txt

echo "Building TypeScript..."
cd lambda
npm run build
cd ..
echo "TypeScript compiled"

echo "Packaging Lambda function..."
cd lambda/dist
zip -r ../function.zip . -x "*.map" > /dev/null

# Include node_modules (only production dependencies)
cd ..
zip -r function.zip node_modules -x "node_modules/@types/*" "node_modules/typescript/*" > /dev/null
cd ..
echo "Package created"

# Check if function exists
if aws lambda get-function --function-name "$FUNCTION_NAME" 2>/dev/null; then
  echo "Updating existing function..."
  
  aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file fileb://lambda/function.zip \
    > /dev/null
  
  sleep 2  # Wait for code update
  
  aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --environment "Variables={PROCESSED_BUCKET=$PROCESSED_BUCKET}" \
    --timeout "$TIMEOUT" \
    --memory-size "$MEMORY" \
    > /dev/null
  
  echo "Function updated"
else
  echo "Creating new function..."
  
  aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime "$RUNTIME" \
    --role "$ROLE_ARN" \
    --handler "$HANDLER" \
    --zip-file fileb://lambda/function.zip \
    --timeout "$TIMEOUT" \
    --memory-size "$MEMORY" \
    --environment "Variables={PROCESSED_BUCKET=$PROCESSED_BUCKET}" \
    > /dev/null
    echo "Function created"
fi

FUNCTION_ARN=$(aws lambda get-function \
  --function-name "$FUNCTION_NAME" \
  --query 'Configuration.FunctionArn' \
  --output text)

cat > infrastructure/lambda-info.txt << LAMBDA_EOF
FUNCTION_NAME=$FUNCTION_NAME
FUNCTION_ARN=$FUNCTION_ARN
LAMBDA_EOF

echo ""
echo "Lambda deployed successfully"
echo "Function: $FUNCTION_NAME"
echo "Runtime: $RUNTIME"
echo "Handler: $HANDLER"
echo "ARN: $FUNCTION_ARN"