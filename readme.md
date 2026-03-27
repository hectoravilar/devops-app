# Docflow

Docflow is a high-performance, **Asynchronous Event-Driven Document Processing Pipeline**. It allows users to upload receipts or invoices, which are then processed in the background to extract critical metadata such as total amounts, dates, and Tax IDs (CNPJ).

## Objective

The primary goal is to provide a seamless, non-blocking user experience. By utilizing **Presigned URLs**, the system ensures secure file transfers directly to cloud storage, while offloading heavy extraction tasks to a scalable, containerized backend architecture.

## Tech Stack

- **Language:** Python (Lambda & Background Worker)
- **Document Processing:** pypdf (Primary Engine for Text and Metadata Extraction)
- **Frontend Hosting:** AWS CloudFront + S3 (Static Web Hosting with Origin Access Control)
- **Serverless Compute:** AWS API Gateway (HTTP API) + AWS Lambda
- **Infrastructure as Code (IaC):** Terraform
- **CI/CD:** GitHub Actions
- **Containerization:** Docker & AWS ECR (Elastic Container Registry)
- **Messaging/Queuing:** AWS SQS
- **Database:** AWS DynamoDB

## Architecture & Workflow

1. **Secure Upload Authorization:** The frontend hits an **Amazon API Gateway** HTTP endpoint (`POST /upload`). An **AWS Lambda** function intercepts the request and generates a temporary **Presigned POST URL**.
2. **Direct to Storage:** The frontend uses the secure JSON payload to upload the document directly to a private **S3 Bucket**, bypassing the backend servers entirely to prevent bottlenecking.
3. **Event Trigger:** S3 natively triggers an event notification that is sent to an **AWS SQS** queue.
4. **Background Processing:** A Python worker running on Docker consumes the message, downloads the file, and extracts the necessary data using `pypdf`.
5. **Persistence:** The extracted metadata and processing status are stored in **DynamoDB**.

## Current Progress & Features

### Cloud Infrastructure (Terraform)

The entire infrastructure is codified using Terraform, ensuring consistent, repeatable, and automated deployments:

- Provisioned isolated S3 buckets for Frontend (Static Hosting) and Backend (PDF processing).
- Configured **CloudFront Distribution** coupled with **Origin Access Control (OAC)** to enforce that the frontend bucket is entirely private and only accessible via the CDN.
- Built a highly efficient, cost-effective routing layer using **API Gateway v2 (HTTP API)**.
- Configured strict **CORS policies** at the API Gateway level to secure cross-origin frontend requests.
- Applied **Least Privilege IAM Policies**, explicitly granting API Gateway execution permissions to invoke the Lambda, and restricting the Lambda's access strictly to the target S3 bucket and CloudWatch logs.
- Deployed DynamoDB tables with `PAY_PER_REQUEST` billing mode for cost-effective serverless storage.
- Provisioned SQS standard queues with dead-letter queue (DLQ) routing for poison-pill handling.

### Serverless API (Python Lambda)

- **Dynamic Credential Generation:** Fast, cold-start optimized Python 3.12 Lambda function that generates temporary AWS STS security tokens and S3 upload policies.
- **Environment Injection:** Dynamically receives the target S3 bucket name via Terraform environment variables, completely eliminating hardcoded resources.

### Backend Worker (Python/Docker)

Built with production-ready patterns:

- **Graceful Shutdown:** Intercepts `SIGTERM` and `SIGINT` signals to prevent data corruption during container termination.
- **Fail-Fast Configuration:** Validates critical environment variables on startup.
- **SQS Long Polling:** Efficiently polls messages using `WaitTimeSeconds` to significantly reduce AWS API costs.
- **Robust Parsing:** Implements `pypdf` for lightweight, fast, and memory-efficient document data extraction.

### CI/CD Pipeline

A robust automation workflow is actively running:

- **Continuous Deployment:** Configured GitHub Actions to automatically build and push the Docker image to **AWS ECR** upon merging to the `main` branch.
- **Least Privilege Security:** CI/CD pipeline authenticates with AWS using dedicated IAM User credentials stored securely in GitHub Secrets, strictly limited to ECR push access.

## AWS Services Summary

| Service         | Role                                                                          |
| :-------------- | :---------------------------------------------------------------------------- |
| **API Gateway** | HTTP front door (v2) managing routing, CORS, and Lambda integration.          |
| **Lambda**      | Serverless compute engine that generates secure S3 Presigned URLs on demand.  |
| **CloudFront**  | Global content delivery network (CDN) for the frontend with HTTPS enforced.   |
| **S3**          | Secure object storage for static website assets and uploaded document files.  |
| **ECR**         | Secure registry hosting the compiled Docker images for the background worker. |
| **SQS**         | Message broker to decouple the upload layer from the processing layer.        |
| **DynamoDB**    | Serverless NoSQL database to store document metadata and processing status.   |
| **IAM**         | Access management enforcing least privilege for CI/CD and Lambda execution.   |

## Documentation & References Used

### AWS & Serverless Logic

- [Presigned URLs](https://docs.aws.amazon.com/boto3/latest/guide/s3-presigned-urls.html)
- [DynamoDB Client](https://docs.aws.amazon.com/boto3/latest/reference/services/dynamodb.html)
- [SQS.Client.receive_message](https://docs.aws.amazon.com/boto3/latest/reference/services/sqs/client/receive_message.html)
- [Amazon SQS short and long polling](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-short-and-long-polling.html#sqs-long-polling)

### Python & Worker Logic

- [pypdf Documentation](https://pypdf.readthedocs.io/en/stable/)
- [Logging](https://docs.python.org/3/howto/logging.html)
- [Signal Handlers](https://docs.python.org/3/library/signal.html)
- [OOP in Python](https://realpython.com/python3-object-oriented-programming/)

### DevOps & Infrastructure (Terraform)

- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [aws_s3_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy)
- [aws_apigatewayv2_api (HTTP API)](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api)
- [aws_apigatewayv2_integration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration)
- [aws_apigatewayv2_route](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route)
- [aws_lambda_permission](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission)
- [aws_ecr_repository](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository)
- [aws_cloudfront_distribution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution)
- [GitHub Actions: Configure AWS Credentials](https://github.com/aws-actions/configure-aws-credentials)
- [GitHub Actions: Amazon ECR Login](https://github.com/aws-actions/amazon-ecr-login)
