resource "aws_iam_user" "demo_user" {
  name = "${var.project_name}-demo-user"
  path = "/governance/"

  tags = {
    Environment = "demo"
    Purpose     = "governance-training"
  }
}






































/*
data "aws_iam_policy_document" "mfa_delete_policy" {
  statement {
    sid    = "DenyDeleteWithoutMFA"
    effect = "Deny"

    actions = [
      "s3:DeleteObject"
    ]

    resources = [
      "*"
    ]

    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"

      values = [
        "false"
      ]
    }
  }
}

resource "aws_iam_policy" "mfa_delete_policy" {
  name        = "${var.project_name}-mfa-delete-policy"
  description = "Require MFA before deleting S3 objects"

  policy = data.aws_iam_policy_document.mfa_delete_policy.json
}
*/