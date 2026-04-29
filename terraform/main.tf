terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}
resource "aws_s3_bucket" "docflow_bucket" {
  bucket = lower("${var.project_name}-pdfs-hector-${var.environment}")

  tags = {
    Name        = lower(var.project_name)
    Environment = lower(var.environment)

  }
}
resource "aws_s3_bucket_cors_configuration" "docflow_cors" {
  bucket = aws_s3_bucket.docflow_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
resource "aws_sqs_queue" "docflow_dlq" {
  name = lower("${var.project_name}-dlq-${var.environment}")
}
resource "aws_sqs_queue" "docflow_queue" {
  name                       = lower("${var.project_name}-sqs-${var.environment}")
  max_message_size           = 2048
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 60
  receive_wait_time_seconds  = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.docflow_dlq.arn
    maxReceiveCount     = 4
  })

  tags = {
    Environment = lower(var.environment)
  }
}
data "aws_iam_policy_document" "s3_to_sqs_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.docflow_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.docflow_bucket.arn]
    }

  }
}
resource "aws_sqs_queue_policy" "sqs_policy_attachment" {
  queue_url = aws_sqs_queue.docflow_queue.id
  policy    = data.aws_iam_policy_document.s3_to_sqs_policy.json
}
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.docflow_bucket.id
  queue {
    queue_arn     = aws_sqs_queue.docflow_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".pdf"
  }
}

resource "aws_dynamodb_table" "docflow_table" {
  name             = lower("${var.project_name}-dynamodb-${var.environment}")
  hash_key         = "document_id"
  billing_mode     = "PAY_PER_REQUEST"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "document_id"
    type = "S"
  }
}
resource "aws_ecr_repository" "docflow_repository" {
  name                 = lower("docflow-worker-${var.environment}")
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}
