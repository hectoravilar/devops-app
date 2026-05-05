resource "aws_ecs_cluster" "docflow_cluster" {
  name = "docflow-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
# Execution Role: Allows ECS to pull the Docker image and publish logs to CloudWatch
resource "aws_iam_role" "ecs_execution_role" {
  name = "docflow-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Role: Grants the Python application access to AWS resources (SQS, DynamoDB, S3)
resource "aws_iam_role" "docflow_task_role" {
  name = "docflow-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# Custom policy for the Python Worker permissions
resource "aws_iam_role_policy" "docflow_task_policy" {
  name = "docflow-task-policy"
  role = aws_iam_role.docflow_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.docflow_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.docflow_table.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.docflow_bucket.arn}/*"
      }
    ]
  })
}
resource "aws_cloudwatch_log_group" "docflow_log_group" {
  name              = "/ecs/docflow-worker"
  retention_in_days = 7

  tags = {
    Environment = "dev"
    Application = "docflow"
  }
}
