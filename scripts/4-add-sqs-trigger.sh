#!/bin/bash
set -e

# Load configuration
source infrastructure/lambda-info.txt
source infrastructure/queue-urls.txt

echo "Adding SQS trigger to Lambda..."

# Get queue ARN
QUEUE_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$MAIN_QUEUE_URL" \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' \
  --output text)

echo "Queue: $QUEUE_ARN"
echo "Lambda: $FUNCTION_ARN"

# Add SQS as event source
aws lambda create-event-source-mapping \
  --function-name "$FUNCTION_NAME" \
  --event-source-arn "$QUEUE_ARN" \
  --batch-size 10 \
  --enabled \
  > /dev/null

echo ""
echo "SQS trigger added"
echo "Lambda will poll queue every few seconds"
echo "Batch size: 10 messages"
