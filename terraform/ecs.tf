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
# Fetch the default VPC automatically
data "aws_vpc" "default" {
  default = true
}

# Fetch the subnets associated with the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for the Fargate tasks
# It must allow outbound traffic to pull the ECR image and talk to AWS APIs
resource "aws_security_group" "docflow_ecs_sg" {
  name        = "docflow-ecs-tasks-sg"
  description = "Allow outbound internet access for Fargate Worker"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Keeps exactly 1 instance of our Worker running 24/7
resource "aws_ecs_service" "docflow_worker_service" {
  name            = "docflow-worker-service"
  cluster         = aws_ecs_cluster.docflow_cluster.id
  task_definition = aws_ecs_task_definition.docflow_worker_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = data.aws_subnets.default.ids
    security_groups = [aws_security_group.docflow_ecs_sg.id]
    # Required to be true so Fargate can reach the internet to pull the Docker image
    assign_public_ip = true
  }
}
