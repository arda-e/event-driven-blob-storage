#!/bin/bash
set -e

# Configuration
DLQ_NAME="file-processing-dlq"
QUEUE_NAME="file-processing-queue"
OUTPUT_FORMAT="text"
QUERY_FIELD="QueueUrl"

# Queue config
VISIBILITY_TIMEOUT="300"
RETENTION_PERIOD="345600"
MAX_RECEIVE_COUNT="3"

echo "Creating SQS queues..."

# Create Dead Letter Queue
echo "Creating DLQ: $DLQ_NAME"
aws sqs create-queue --queue-name "$DLQ_NAME" > /dev/null

# Get DLQ URL
DLQ_URL=$(aws sqs get-queue-url \
  --queue-name "$DLQ_NAME" \
  --query "$QUERY_FIELD" \
  --output "$OUTPUT_FORMAT")

if [ -z "$DLQ_URL" ]; then
  echo "Error: Failed to get DLQ URL"
  exit 1
fi

echo "DLQ URL: $DLQ_URL"

# Get DLQ ARN
DLQ_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$DLQ_URL" \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' \
  --output "$OUTPUT_FORMAT")

if [ -z "$DLQ_ARN" ]; then
  echo "Error: Failed to get DLQ ARN"
  exit 1
fi

echo "DLQ ARN: $DLQ_ARN"

# Create Main Queue with DLQ Configuration
echo "Creating main queue: $QUEUE_NAME"
aws sqs create-queue \
  --queue-name "$QUEUE_NAME" \
  --attributes '{
    "VisibilityTimeout": "'"$VISIBILITY_TIMEOUT"'",
    "MessageRetentionPeriod": "'"$RETENTION_PERIOD"'",
    "RedrivePolicy": "{\"deadLetterTargetArn\":\"'"$DLQ_ARN"'\",\"maxReceiveCount\":\"'"$MAX_RECEIVE_COUNT"'\"}"
  }' > /dev/null

# Get Main Queue URL
MAIN_QUEUE_URL=$(aws sqs get-queue-url \
  --queue-name "$QUEUE_NAME" \
  --query "$QUERY_FIELD" \
  --output "$OUTPUT_FORMAT")

if [ -z "$MAIN_QUEUE_URL" ]; then
  echo "Error: Failed to get main queue URL"
  exit 1
fi

echo "Main Queue URL: $MAIN_QUEUE_URL"


cat > infrastructure/queue-urls.txt << EOF
DLQ_URL=$DLQ_URL
DLQ_ARN=$DLQ_ARN
MAIN_QUEUE_URL=$MAIN_QUEUE_URL
QUEUE_NAME=$QUEUE_NAME
DLQ_NAME=$DLQ_NAME
EOF

echo ""
echo "SQS queues created successfully"
echo ""
echo "Queue URLs saved to: infrastructure/queue-urls.txt"
echo "To use in other scripts: source infrastructure/queue-urls.txt"  
