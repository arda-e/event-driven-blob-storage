# INFRASTRUCTURE SETUP ORDER:

## S3 Buckets:
1. Create raw bucket (if not exists)
2. Create processed bucket (if not exists)
3. Save bucket info → infrastructure/bucket-info.txt

## SQS Queues:
4. Create DLQ
5. Get DLQ URL
6. Get DLQ ARN
7. Create main queue (with DLQ redrive policy)
8. Configure main queue (visibility timeout, retention, max receive count)
9. Get main queue URL
10. Save queue info → infrastructure/queue-urls.txt

## Lambda IAM Role:
11. Create IAM role (with trust policy for lambda.amazonaws.com)
12. Attach permissions policy (S3, SQS, CloudWatch)
13. Wait 10s for IAM propagation
14. Save role info → infrastructure/lambda-role-info.txt

## Lambda Function:
15. Build TypeScript → JavaScript
16. Package function.zip (code + node_modules)
17. If Lambda exists → update code
18. If Lambda new → create function
19. Update/set configuration (env vars, timeout, memory)
20. Get function ARN
21. Save lambda info → infrastructure/lambda-info.txt

## Connect Everything:
22. Get main queue ARN
23. Create event source mapping (SQS → Lambda trigger)
24. Set SQS policy (allow S3 to send messages)
25. Configure S3 bucket notification (uploads/* → SQS)
