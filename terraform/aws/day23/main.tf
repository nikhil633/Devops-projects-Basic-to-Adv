resource "aws_iam_openid_connect_provider" "github" {

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Name = "GitHub-OIDC"
  }
}


data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_trust_policy" {

  statement {

    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {

      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {

      test = "StringEquals"

      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {

      test = "StringEquals"

      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
      ]
    }
  }
}


resource "aws_iam_role" "github_actions" {

  name = "github-actions-terraform-role"

  assume_role_policy = data.aws_iam_policy_document.github_trust_policy.json
}


data "aws_iam_policy_document" "terraform_policy" {

  statement {

    effect = "Allow"

    actions = [
      "ec2:*",
      "iam:*",
      "s3:*",
      "lambda:*",
      "cloudwatch:*",
      "route53:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "acm:*",
      "eks:*",
      "ecs:*",
      "logs:*",
      "sns:*",
      "sqs:*",
      "dynamodb:*",
      "rds:*",
      "secretsmanager:*",
      "kms:*",
      "cloudfront:*",
      "ecr:*",
      "events:*",
      "ssm:*"
    ]

    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "terraform_policy" {

  name = "github-actions-terraform-policy"

  policy = data.aws_iam_policy_document.terraform_policy.json
}

resource "aws_iam_role_policy_attachment" "terraform_attachment" {

  role = aws_iam_role.github_actions.name

  policy_arn = aws_iam_policy.terraform_policy.arn
}


