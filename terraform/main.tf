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
  region = "us-east-1"
}
resource "aws_s3_bucket" "docflow_bucket" {
  bucket = "docflow-pdfs-hector-dev"

  tags = {
    Name        = "My bucket"
    Environment = "DevOps"
  }
}
resource "aws_sqs_queue" "docflow_dlq" {
  name = "docflow-dlq"

  tags = {
    Environment = "DevOps"
  }
}
resource "aws_sqs_queue" "docflow_queue" {
  name                       = "docflow-sqs"
  max_message_size           = 2048
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 60
  receive_wait_time_seconds  = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.docflow_dlq.arn
    maxReceiveCount     = 4
  })

  tags = {
    Environment = "DevOps"
  }
}

resource "aws_dynamodb_table" "docflow_table" {
  name             = "docflow-documents"
  hash_key         = "document_id"
  billing_mode     = "PAY_PER_REQUEST"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "document_id"
    type = "S"
  }
}
