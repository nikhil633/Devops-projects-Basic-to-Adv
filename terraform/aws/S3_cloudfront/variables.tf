variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
  default     = "s3-bucket-static-website-central-india"
}

variable "aws_region" {
  description = "The AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}