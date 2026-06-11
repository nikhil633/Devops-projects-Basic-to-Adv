# terraform/aws/envs/dev/main.tf
# Root module for the DEV environment.
# Calls VPC, EKS, ECR modules and wires outputs between them.

terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Remote state in S3 — create this bucket manually before first apply
  backend "s3" {
    bucket         = "my-project-terraform-state"   # replace with your bucket
    key            = "aws/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"          # for state locking
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project
    Environment = "dev"
    ManagedBy   = "terraform"
    Team        = var.team
  }
}

# ── VPC ───────────────────────────────────────────────────────────────────
module "vpc" {
  source      = "../../modules/vpc"
  project     = var.project
  environment = "dev"
  vpc_cidr    = "10.0.0.0/16"
  tags        = local.common_tags
}

# ── EKS ───────────────────────────────────────────────────────────────────
module "eks" {
  source             = "../../modules/eks"
  project            = var.project
  environment        = "dev"
  private_subnet_ids = module.vpc.private_subnet_ids

  kubernetes_version      = "1.30"
  public_api_access       = true   # true for dev — restrict in prod
  app_node_instance_types = ["t3.large"]
  app_node_desired        = 2
  app_node_min            = 1
  app_node_max            = 5
  use_spot                = true   # use Spot for cost savings in dev

  tags = local.common_tags
}

# ── ECR ───────────────────────────────────────────────────────────────────
module "ecr" {
  source                 = "../../modules/ecr"
  project                = var.project
  environment            = "dev"
  github_actions_role_arn = aws_iam_role.github_actions.arn
  tags                   = local.common_tags
}

# ── GitHub Actions OIDC (no stored secrets in GitHub!) ───────────────────
# This allows GitHub Actions to assume an AWS role via OIDC token
# The role grants: ECR push + EKS describe (for kubectl/helm)
data "aws_iam_openid_connect_provider" "github" {
  # GitHub's OIDC provider — create once per AWS account
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project}-dev-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        StringLike = {
          # Only allow your repo to assume this role
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
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
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage", "ecr:PutImage",
          "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = values(module.ecr.repository_urls)[*]
      },
      {
        Sid    = "EKSAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
        ]
        Resource = "*"
      }
    ]
  })
}

# ── Outputs (used by CI/CD and Helm deployments) ──────────────────────────
output "cluster_name"        { value = module.eks.cluster_name }
output "cluster_endpoint"    { value = module.eks.cluster_endpoint }
output "ecr_urls"            { value = module.ecr.repository_urls }
output "github_actions_role" { value = aws_iam_role.github_actions.arn }
output "vpc_id"              { value = module.vpc.vpc_id }
