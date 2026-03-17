# s3 bucket para artefatos do pipeline
# Bucket S3 para armazenar os artefatos temporários entre as etapas do pipeline
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket        = lower("${local.name}-codepipeline-artifacts")
  force_destroy = true # Permite destruir o bucket mesmo com objetos dentro
}

# conexão com repositório git
# Conexão Segura com o Repositório de Código (GitLab ou GitHub)
# IMPORTANTE: Após o primeiro apply, autorize manualmente no console AWS:
# CodePipeline -> Settings -> Connections
resource "aws_codestarconnections_connection" "repo" {
  name          = "${local.name}-repo-conn"
  provider_type = "GitLab" # Altere para "GitHub" se necessário
}

# iam role para codebuild
# IAM Role para o AWS CodeBuild com permissões de build
resource "aws_iam_role" "codebuild_role" {
  name = "${local.name}-codebuild-role"
  
  # Trust policy: permite que o CodeBuild assuma esta role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

# Policy com permissões necessárias para o CodeBuild
resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        # Permissões para criar e escrever logs no CloudWatch
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        # Permissões para ler e escrever artefatos no S3
        Action   = ["s3:PutObject", "s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketAcl", "s3:GetBucketLocation"]
        Resource = ["${aws_s3_bucket.codepipeline_bucket.arn}", "${aws_s3_bucket.codepipeline_bucket.arn}/*"]
      },
      {
        Effect   = "Allow"
        # Permissões para fazer push e pull de imagens Docker no ECR
        Action   = ["ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:GetRepositoryPolicy", "ecr:DescribeRepositories", "ecr:ListImages", "ecr:DescribeImages", "ecr:BatchGetImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage"]
        Resource = "*"
      }
    ]
  })
}

# projeto codebuild
# Projeto AWS CodeBuild para executar build, testes e deploy
resource "aws_codebuild_project" "app_build" {
  name         = "${local.name}-build"
  service_role = aws_iam_role.codebuild_role.arn

  # Artefatos serão gerenciados pelo CodePipeline
  artifacts {
    type = "CODEPIPELINE"
  }

  # Configuração do ambiente de build
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL" # 3 GB memória, 2 vCPUs
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true # ESSENCIAL para permitir o build de imagens Docker

    # Variáveis de ambiente disponíveis durante o build
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = local.region
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = local.account_id
    }
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = module.ecr.repository_name
    }
  }

  # Código fonte vem do CodePipeline
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml" # Arquivo com instruções de build
  }
}

# iam role para codepipeline
# IAM Role para o AWS CodePipeline (Orquestração do pipeline)
resource "aws_iam_role" "codepipeline_role" {
  name = "${local.name}-codepipeline-role"
  
  # Trust policy: permite que o CodePipeline assuma esta role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })
}

# Policy com permissões necessárias para o CodePipeline
resource "aws_iam_role_policy" "codepipeline_policy" {
  role = aws_iam_role.codepipeline_role.name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        # Permissões para gerenciar artefatos no S3
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketVersioning", "s3:PutObjectAcl", "s3:PutObject"]
        Resource = ["${aws_s3_bucket.codepipeline_bucket.arn}", "${aws_s3_bucket.codepipeline_bucket.arn}/*"]
      },
      {
        Effect   = "Allow"
        # Permissão para usar a conexão com o repositório Git
        Action   = ["codestar-connections:UseConnection"]
        Resource = aws_codestarconnections_connection.repo.arn
      },
      {
        Effect   = "Allow"
        # Permissões para iniciar e monitorar builds no CodeBuild
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = aws_codebuild_project.app_build.arn
      },
      {
        Effect   = "Allow"
        # Permissões para fazer deploy no ECS
        Action   = ["ecs:DescribeServices", "ecs:DescribeTaskDefinition", "ecs:DescribeTasks", "ecs:ListTasks", "ecs:RegisterTaskDefinition", "ecs:UpdateService"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        # Permissão para passar roles para outros serviços
        Action   = ["iam:PassRole"]
        Resource = "*"
      }
    ]
  })
}

# codepipeline - pipeline ci/cd completo
# Pipeline completo: Source -> Build/Test -> Deploy
resource "aws_codepipeline" "pipeline" {
  name     = "${local.name}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  # Local onde os artefatos serão armazenados entre as etapas
  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  # ETAPA 1: SOURCE - Obtém o código do repositório Git
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.repo.arn
        FullRepositoryId = "hectoravila/dreamsquad-app" # ALTERE para seu repositório
        BranchName       = "main"                       # Branch a ser monitorado
      }
    }
  }

  # ETAPA 2: BUILD AND TEST - Executa build, testes e validações
  stage {
    name = "BuildAndTest"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      
      configuration = {
        ProjectName = aws_codebuild_project.app_build.name
      }
    }
  }

  # ETAPA 3: DEPLOY - Atualiza o serviço ECS com a nova imagem
  stage {
    name = "Deploy"
    action {
      name            = "DeployToECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      version         = "1"
      
      configuration = {
        ClusterName = aws_ecs_cluster.this.name
        ServiceName = aws_ecs_service.app.name
        FileName    = "imagedefinitions.json" # Arquivo gerado pelo CodeBuild
      }
    }
  }
}