# terraform/aws/envs/prod/main.tf
terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = { source = "hashicorp/aws"; version = "~> 5.50" }
    tls = { source = "hashicorp/tls"; version = "~> 4.0" }
  }

  backend "s3" {
    bucket         = "my-project-terraform-state"
    key            = "aws/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = local.common_tags }
}

locals {
  common_tags = {
    Project     = var.project
    Environment = "prod"
    ManagedBy   = "terraform"
    Team        = var.team
  }
}

module "vpc" {
  source      = "../../modules/vpc"
  project     = var.project
  environment = "prod"
  vpc_cidr    = "10.10.0.0/16"   # different CIDR from dev to allow VPC peering
  tags        = local.common_tags
}

module "eks" {
  source             = "../../modules/eks"
  project            = var.project
  environment        = "prod"
  private_subnet_ids = module.vpc.private_subnet_ids

  kubernetes_version      = "1.30"
  public_api_access       = false    # API server not reachable from internet
  api_access_cidrs        = var.vpn_cidrs  # only from VPN
  app_node_instance_types = ["m5.xlarge", "m5.2xlarge"]
  app_node_desired        = 4
  app_node_min            = 3
  app_node_max            = 20
  use_spot                = false   # On-Demand only in prod

  tags = local.common_tags
}

module "ecr" {
  source                  = "../../modules/ecr"
  project                 = var.project
  environment             = "prod"
  github_actions_role_arn = aws_iam_role.github_actions.arn
  tags                    = local.common_tags
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project}-prod-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringLike = {
          # Prod: only allow deploys from main branch
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "github_actions" {
  role = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage", "ecr:PutImage",
          "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = values(module.ecr.repository_urls)[*]
      },
      { Effect = "Allow"; Action = ["eks:DescribeCluster"]; Resource = "*" }
    ]
  })
}

output "cluster_name"        { value = module.eks.cluster_name }
output "cluster_endpoint"    { value = module.eks.cluster_endpoint }
output "ecr_urls"            { value = module.ecr.repository_urls }
output "github_actions_role" { value = aws_iam_role.github_actions.arn }
