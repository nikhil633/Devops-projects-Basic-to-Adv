# terraform/aws/envs/dev/variables.tf
variable "aws_region"   { type = string; default = "us-east-1" }
variable "project"      { type = string; default = "myproject" }
variable "team"         { type = string; default = "platform" }
variable "github_org"   { type = string; description = "Your GitHub organisation or username" }
variable "github_repo"  { type = string; description = "Your GitHub repository name" }
