# resource "random_string" suffix {
#     length = 6
#     special = false
#     upper = false
# }

# resource "aws_s3_bucket" "config_bucket" {
#   bucket = "${var.project_name}-config-bucket-${random_string.suffix.result}"
#   force_destroy = true

#   tags = {
#     name = "${var.project_name}"
#     Environment = "governence"
#     purpose = "aws-config-storage"
#     Managed_by = "Terraform"
#   }
# }

# resource "aws_s3_bucket_versioning" "coonfig_bucket_versoning" {
#   bucket = aws_s3_bucket.config_bucket.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "config_bucket_encryption" {
#   bucket = aws_s3_bucket.config_bucket.id
  
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# resource "aws_s3_bucket_public_access_block" "config_bucket_public_access" {
#   bucket = aws_s3_bucket.config_bucket.id

#   block_public_acls = true
#   block_public_policy = true
#   ignore_public_acls = true
#   restrict_public_buckets = true
# }

# resource "aws_s3_bucket_policy" "config_bucket_policy" {
#   bucket = aws_s3_bucket.config_bucket.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "AWSConfigBucketPermissionsCheck"
#         Effect = "Allow"
#         Principal = {
#           Service = "config.amazonaws.com"
#         }
#         Action   = "s3:GetBucketAcl"
#         Resource = aws_s3_bucket.config_bucket.arn
#       },
#       {
#         Sid    = "AWSConfigBucketExistenceCheck"
#         Effect = "Allow"
#         Principal = {
#           Service = "config.amazonaws.com"
#         }
#         Action   = "s3:ListBucket"
#         Resource = aws_s3_bucket.config_bucket.arn
#       },
#       {
#         Sid    = "AWSConfigBucketPutObject"
#         Effect = "Allow"
#         Principal = {
#           Service = "config.amazonaws.com"
#         }
#         Action   = "s3:PutObject"
#         Resource = "${aws_s3_bucket.config_bucket.arn}/*"
#         Condition = {
#           StringEquals = {
#             "s3:x-amz-acl" = "bucket-owner-full-control"
#           }
#         }
#       },
#       {
#         Sid       = "DenyInsecureTransport"
#         Effect    = "Deny"
#         Principal = "*"
#         Action    = "s3:*"
#         Resource = [
#           aws_s3_bucket.config_bucket.arn,
#           "${aws_s3_bucket.config_bucket.arn}/*"
#         ]
#         Condition = {
#           Bool = {
#             "aws:SecureTransport" = "false"
#           }
#         }
#       }
#     ]
#   })

#   depends_on = [aws_s3_bucket_public_access_block.config_bucket_public_access]
# }



# /*
# data "aws_iam_policy_document" "config_bucket_policy" {

#   statement {
#     sid    = "AWSConfigBucketPermissionsCheck"
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["config.amazonaws.com"]
#     }

#     actions = [
#       "s3:GetBucketAcl"
#     ]

#     resources = [
#       aws_s3_bucket.config_bucket.arn
#     ]
#   }

#   statement {
#     sid    = "AWSConfigBucketExistenceCheck"
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["config.amazonaws.com"]
#     }

#     actions = [
#       "s3:ListBucket"
#     ]

#     resources = [
#       aws_s3_bucket.config_bucket.arn
#     ]
#   }

#   statement {
#     sid    = "AWSConfigBucketPutObject"
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["config.amazonaws.com"]
#     }

#     actions = [
#       "s3:PutObject"
#     ]

#     resources = [
#       "${aws_s3_bucket.config_bucket.arn}/*"
#     ]

#     condition {
#       test     = "StringEquals"
#       variable = "s3:x-amz-acl"

#       values = [
#         "bucket-owner-full-control"
#       ]
#     }
#   }

#   statement {
#     sid    = "DenyInsecureTransport"
#     effect = "Deny"

#     principals {
#       type        = "*"
#       identifiers = ["*"]
#     }

#     actions = [
#       "s3:*"
#     ]

#     resources = [
#       aws_s3_bucket.config_bucket.arn,
#       "${aws_s3_bucket.config_bucket.arn}/*"
#     ]

#     condition {
#       test     = "Bool"
#       variable = "aws:SecureTransport"

#       values = [
#         "false"
#       ]
#     }
#   }
# }

# resource "aws_s3_bucket_policy" "config_bucket_policy" {
#   bucket = aws_s3_bucket.config_bucket.id
#   policy = data.aws_iam_policy_document.config_bucket_policy.json
# }

# */