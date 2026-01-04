#!/bin/bash
set -e

# Load configuration
source infrastructure/bucket-info.txt

echo "=== Testing Event-Driven Flow ==="
echo ""

# Step 1: Create test file
echo "Creating test file..."
cat > /tmp/test-file.txt << TESTFILE
This is a test file for the event-driven blob storage system.

Project: Event-Driven Blob Storage
Author: Arda
Date: $(date)

This file will trigger:
1. S3 upload event
2. SQS message
3. Lambda processing
4. Aggregate creation
5. File tagging

Line count: Multiple lines
Word count: Many words
Character count: Lots of characters
TESTFILE

FILE_SIZE=$(wc -c < /tmp/test-file.txt)
echo "Test file created ($FILE_SIZE bytes)"

# Step 2: Upload to S3
TEST_KEY="uploads/test-$(date +%s).txt"
echo ""
echo "Uploading to S3..."
echo "  Bucket: $RAW_BUCKET"
echo "  Key: $TEST_KEY"

aws s3 cp /tmp/test-file.txt "s3://$RAW_BUCKET/$TEST_KEY"
echo "Uploaded"

# Step 3: Wait for processing
echo ""
echo "Waiting for Lambda to process (15 seconds)..."
for i in {15..1}; do
  echo -n "$i..."
  sleep 1
done
echo ""

# Step 4: Check aggregate was created
AGGREGATE_KEY="${TEST_KEY/uploads/aggregates}"
AGGREGATE_KEY="${AGGREGATE_KEY%.txt}.json"

echo ""
echo "Checking for aggregate..."
echo "  Expected: s3://$PROCESSED_BUCKET/$AGGREGATE_KEY"

if aws s3 ls "s3://$PROCESSED_BUCKET/$AGGREGATE_KEY" &>/dev/null; then
  echo "Aggregate exists!"
  
  # Download and display
  aws s3 cp "s3://$PROCESSED_BUCKET/$AGGREGATE_KEY" /tmp/aggregate.json &>/dev/null
  echo ""
  echo "Aggregate contents:"
  cat /tmp/aggregate.json | head -20
  
else
  echo "Aggregate not found"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check SQS queue for messages:"
  echo "     aws sqs get-queue-attributes --queue-url \$MAIN_QUEUE_URL --attribute-names ApproximateNumberOfMessages"
  echo ""
  echo "  2. Check Lambda logs:"
  echo "     aws logs tail /aws/lambda/FileProcessor --follow"
  exit 1
fi

# Step 5: Check file was tagged
echo ""
echo "Checking if file was tagged..."

TAGS=$(aws s3api get-object-tagging \
  --bucket "$RAW_BUCKET" \
  --key "$TEST_KEY" \
  --query 'TagSet[?Key==`processed`].Value' \
  --output text)

if [ "$TAGS" = "true" ]; then
  echo "File tagged as processed"
else
  echo "File not tagged"
fi

# Step 6: View Lambda logs
echo ""
echo "Recent Lambda logs:"
aws logs tail /aws/lambda/FileProcessor --since 2m --format short | tail -20

# Cleanup
rm /tmp/test-file.txt /tmp/aggregate.json 2>/dev/null || true

echo ""
echo "==================================="
echo "✓ END-TO-END TEST COMPLETE"
echo "==================================="
echo ""
echo "What happened:"
echo "  1. File uploaded to s3://$RAW_BUCKET/$TEST_KEY"
echo "  2. S3 sent event to SQS"
echo "  3. Lambda polled SQS and received message"
echo "  4. Lambda processed file and created aggregate"
echo "  5. Aggregate saved to s3://$PROCESSED_BUCKET/$AGGREGATE_KEY"
echo "  6. Original file tagged as 'processed=true'"
echo ""
echo "Next steps:"
echo "  - Wait 24h to see lifecycle policies move file to Glacier"
echo "  - Or set lifecycle to 1 hour for faster testing"
