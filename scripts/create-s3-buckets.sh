# Replace with your name/initials
BUCKET_PREFIX="ardico-event-blob"
RAW_BUCKET="${BUCKET_PREFIX}-raw"
PROCESSED_BUCKET="${BUCKET_PREFIX}-processed"

# Create raw bucket
aws s3 mb s3://$RAW_BUCKET

# Create processed bucket
aws s3 mb s3://$PROCESSED_BUCKET

# Verify
aws s3 ls