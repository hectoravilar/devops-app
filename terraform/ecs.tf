resource "aws_ecs_cluster" "docflow_cluster" {
  name = "docflow-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
