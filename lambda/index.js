const { S3Client, GetObjectCommand, PutObjectCommand, PutObjectTaggingCommand } = require('@aws-sdk/client-s3');

const s3Client = new S3Client();

exports.handler = async (event) => {
  console.log('Deployed via GitHub Actions');
  console.log('Received event:', JSON.stringify(event, null, 2));
  // Process each SQS message
  for (const record of event.Records) {
    try {
      // Parse S3 event from SQS message
      const s3Event = JSON.parse(record.body);
      const s3Record = s3Event.Records[0];
      
      const bucket = s3Record.s3.bucket.name;
      const key = decodeURIComponent(s3Record.s3.object.key.replace(/\+/g, ' '));
      const size = s3Record.s3.object.size;
      
      console.log(`Processing: s3://${bucket}/${key} (${size} bytes)`);
      
      // 1. Download file from S3
      const getCommand = new GetObjectCommand({
        Bucket: bucket,
        Key: key
      });
      const response = await s3Client.send(getCommand);
      const fileContent = await streamToString(response.Body);
      
      // 2. Calculate aggregate (simple stats)
      const aggregate = {
        sourceFile: key,
        sourceBucket: bucket,
        fileSize: size,
        processedAt: new Date().toISOString(),
        stats: {
          sizeBytes: size,
          sizeMB: (size / 1024 / 1024).toFixed(2),
          contentLength: fileContent.length,
          lines: fileContent.split('\n').length,
          contentType: response.ContentType || 'unknown'
        }
      };
      
      console.log('Aggregate calculated:', JSON.stringify(aggregate, null, 2));
      
      // 3. Save aggregate to processed bucket
      const processedKey = key.replace('raw/', 'aggregates/').replace(/\.[^/.]+$/, '.json');
      const putCommand = new PutObjectCommand({
        Bucket: process.env.PROCESSED_BUCKET,
        Key: processedKey,
        Body: JSON.stringify(aggregate, null, 2),
        ContentType: 'application/json'
      });
      await s3Client.send(putCommand);
      
      console.log(`Saved aggregate: s3://${process.env.PROCESSED_BUCKET}/${processedKey}`);
      
      // 4. Tag original file as processed
      const tagCommand = new PutObjectTaggingCommand({
        Bucket: bucket,
        Key: key,
        Tagging: {
          TagSet: [
            { Key: 'processed', Value: 'true' },
            { Key: 'processed-at', Value: new Date().toISOString() }
          ]
        }
      });
      await s3Client.send(tagCommand);
      
      console.log(`Tagged file as processed: ${key}`);
      
    } catch (error) {
      console.error('Error processing record:', error);
      throw error; // SQS will retry
    }
  }
  
  return {
    statusCode: 200,
    body: JSON.stringify({ message: 'Processing complete' })
  };
};

// Helper: Convert stream to string
async function streamToString(stream) {
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString('utf-8');
}
