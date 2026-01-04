#!/bin/bash
set -e

# Configuration
BUCKET_PREFIX="ardico-event-blob"
RAW_BUCKET="${BUCKET_PREFIX}-raw"
PROCESSED_BUCKET="${BUCKET_PREFIX}-processed"
REGION="${AWS_DEFAULT_REGION:-eu-central-1}"

echo "Creating S3 buckets in region: $REGION"

# Check if bucket exists
bucket_exists() {
  aws s3api head-bucket --bucket "$1" 2>/dev/null
  return $?
}

# Create bucket if it doesn't exist
create_bucket() {
  local bucket_name="$1"
  
  if bucket_exists "$bucket_name"; then
    echo "Bucket already exists: $bucket_name"
  else
    echo "Creating bucket: $bucket_name"
    aws s3 mb "s3://$bucket_name" --region "$REGION" > /dev/null
    
    # Verify creation
    if bucket_exists "$bucket_name"; then
      echo "Created successfully"
    else
      echo "Failed to create $bucket_name"
      exit 1
    fi
  fi
}

# Create buckets
create_bucket "$RAW_BUCKET"
create_bucket "$PROCESSED_BUCKET"

# Save bucket info
cat > infrastructure/bucket-info.txt << EOF
RAW_BUCKET=$RAW_BUCKET
PROCESSED_BUCKET=$PROCESSED_BUCKET
REGION=$REGION
EOF

echo ""
echo "Buckets created successfully"
echo ""
echo "Buckets in region $REGION:"
aws s3 ls | grep "$BUCKET_PREFIX"