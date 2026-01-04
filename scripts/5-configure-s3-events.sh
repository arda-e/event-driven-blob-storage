# Load config
source infrastructure/bucket-info.txt
source infrastructure/queue-urls.txt

# Get queue ARN
QUEUE_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$MAIN_QUEUE_URL" \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' \
  --output text)

echo "Configuring S3 → SQS..."
echo "  Bucket: $RAW_BUCKET"
echo "  Queue ARN: $QUEUE_ARN"
echo ""

# Step 1: Set SQS policy (allow S3 to send messages)
echo "Step 1: Setting SQS policy..."
aws sqs set-queue-attributes \
  --queue-url "$MAIN_QUEUE_URL" \
  --attributes '{"Policy":"{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"s3.amazonaws.com\"},\"Action\":\"sqs:SendMessage\",\"Resource\":\"'$QUEUE_ARN'\",\"Condition\":{\"ArnLike\":{\"aws:SourceArn\":\"arn:aws:s3:::'$RAW_BUCKET'\"}}}]}"}'

echo "  ✓ SQS policy set"
echo ""

# Step 2: Configure S3 notification
echo "Step 2: Configuring S3 notification..."

cat > /tmp/s3-notification.json << EOF
{
  "QueueConfigurations": [
    {
      "QueueArn": "$QUEUE_ARN",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {
              "Name": "prefix",
              "Value": "uploads/"
            }
          ]
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-notification-configuration \
  --bucket "$RAW_BUCKET" \
  --notification-configuration file:///tmp/s3-notification.json

echo "  ✓ S3 notification configured"
echo ""
echo "✓ Configuration complete!"