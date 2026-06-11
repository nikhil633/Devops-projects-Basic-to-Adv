# terraform/aws/modules/ecr/main.tf
# Creates one ECR repository per service with:
#   - Image scanning on push (detects OS + package vulnerabilities)
#   - Lifecycle policy (keeps only last N images to control storage cost)
#   - Immutable tags (prevents overwriting :latest — enforces traceability)

locals {
  services = [
    "python-url-shortener",
    "nodejs-notification",
    "go-auth",
    "rust-ratelimiter",
    "java-inventory",
  ]
}

resource "aws_ecr_repository" "services" {
  for_each             = toset(local.services)
  name                 = "${var.project}/${var.environment}/${each.value}"
  image_tag_mutability = "IMMUTABLE"  # cannot overwrite existing tags

  image_scanning_configuration {
    scan_on_push = true   # Trivy-style vulnerability scan on every push
  }

  encryption_configuration {
    encryption_type = "KMS"  # encrypt images at rest with KMS
  }

  tags = merge(var.tags, { Service = each.value })
}

# Keep only the last 20 images per repo — older ones are auto-deleted
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 20 tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["v", "sha-"]
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after 7 days"
        selection = {
          tagStatus = "untagged"
          countType = "sinceImagePushed"
          countUnit = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}

# Allow GitHub Actions OIDC role to push images
resource "aws_ecr_repository_policy" "github_push" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGithubActionsOIDC"
        Effect = "Allow"
        Principal = {
          AWS = var.github_actions_role_arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
      }
    ]
  })
}
