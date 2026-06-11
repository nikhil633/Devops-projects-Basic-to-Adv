# terraform/aws/envs/prod/variables.tf
variable "aws_region"   { type = string; default = "us-east-1" }
variable "project"      { type = string; default = "myproject" }
variable "team"         { type = string; default = "platform" }
variable "github_org"   { type = string }
variable "github_repo"  { type = string }
variable "vpn_cidrs"    { type = list(string); description = "CIDRs allowed to reach the EKS API server" }
