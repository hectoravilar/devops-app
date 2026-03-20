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
resource "aws_s3_bucket" "example" {
  bucket = "docflow-pdfs-hector-dev"

  tags = {
    Name        = "My bucket"
    Environment = "DevOps"
  }
}
