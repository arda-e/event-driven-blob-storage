import { SQSEvent, SQSRecord, Context } from 'aws-lambda';
import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
  PutObjectTaggingCommand,
} from '@aws-sdk/client-s3';
import { Readable } from 'stream';

const s3Client = new S3Client({});
const PROCESSED_BUCKET = process.env.PROCESSED_BUCKET!;

interface S3EventRecord {
  s3: {
    bucket: { name: string };
    object: { key: string; size: number };
  };
}

interface S3EventMessage {
  Records: S3EventRecord[];
}

interface FileAggregate {
  sourceFile: string;
  sourceBucket: string;
  fileSize: number;
  processedAt: string;
  stats: {
    sizeBytes: number;
    sizeMB: string;
    contentLength: number;
    lines: number;
    contentType: string;
  };
}

export const handler = async (event: SQSEvent, context: Context): Promise<void> => {
  console.log('Event received:', JSON.stringify(event, null, 2));
  console.log('Context:', JSON.stringify(context, null, 2));

  // Process each SQS message
  for (const record of event.Records) {
    await processSQSRecord(record);
  }

  console.log('✓ All records processed successfully');
};

async function processSQSRecord(record: SQSRecord): Promise<void> {
  try {
    // Parse S3 event from SQS message body
    const s3Event: S3EventMessage = JSON.parse(record.body);
    const s3Record = s3Event.Records[0];

    const bucket = s3Record.s3.bucket.name;
    const key = decodeURIComponent(s3Record.s3.object.key.replace(/\+/g, ' '));
    const size = s3Record.s3.object.size;

    console.log(`Processing: s3://${bucket}/${key} (${size} bytes)`);

    // 1. Download file from S3
    const fileContent = await downloadFile(bucket, key);

    // 2. Calculate aggregate statistics
    const aggregate = calculateAggregate(bucket, key, size, fileContent);
    console.log('Aggregate calculated:', JSON.stringify(aggregate, null, 2));

    // 3. Save aggregate to processed bucket
    await saveAggregate(aggregate, key);

    // 4. Tag original file as processed
    await tagFileAsProcessed(bucket, key);

    console.log(`✓ Successfully processed: ${key}`);
  } catch (error) {
    console.error('Error processing record:', error);
    throw error; // Let SQS retry
  }
}

async function downloadFile(bucket: string, key: string): Promise<string> {
  const command = new GetObjectCommand({ Bucket: bucket, Key: key });
  const response = await s3Client.send(command);

  if (!response.Body) {
    throw new Error('No body in S3 response');
  }

  return streamToString(response.Body as Readable);
}

function calculateAggregate(
  bucket: string,
  key: string,
  size: number,
  content: string
): FileAggregate {
  return {
    sourceFile: key,
    sourceBucket: bucket,
    fileSize: size,
    processedAt: new Date().toISOString(),
    stats: {
      sizeBytes: size,
      sizeMB: (size / 1024 / 1024).toFixed(2),
      contentLength: content.length,
      lines: content.split('\n').length,
      contentType: 'text/plain',
    },
  };
}

async function saveAggregate(aggregate: FileAggregate, originalKey: string): Promise<void> {
  // Transform key: raw/file.txt -> aggregates/file.json
  const processedKey = originalKey
    .replace('raw/', 'aggregates/')
    .replace(/\.[^/.]+$/, '.json');

  const command = new PutObjectCommand({
    Bucket: PROCESSED_BUCKET,
    Key: processedKey,
    Body: JSON.stringify(aggregate, null, 2),
    ContentType: 'application/json',
  });

  await s3Client.send(command);
  console.log(`Saved aggregate: s3://${PROCESSED_BUCKET}/${processedKey}`);
}

async function tagFileAsProcessed(bucket: string, key: string): Promise<void> {
  const command = new PutObjectTaggingCommand({
    Bucket: bucket,
    Key: key,
    Tagging: {
      TagSet: [
        { Key: 'processed', Value: 'true' },
        { Key: 'processed-at', Value: new Date().toISOString() },
      ],
    },
  });

  await s3Client.send(command);
  console.log(`Tagged as processed: ${key}`);
}

async function streamToString(stream: Readable): Promise<string> {
  const chunks: Buffer[] = [];
  
  for await (const chunk of stream) {
    chunks.push(Buffer.from(chunk));
  }
  
  return Buffer.concat(chunks).toString('utf-8');
}
