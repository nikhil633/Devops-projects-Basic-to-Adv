# terraform/aws/modules/ecr/variables.tf
variable "project"                  { type = string }
variable "environment"              { type = string }
variable "github_actions_role_arn"  { type = string }
variable "tags"                     { type = map(string); default = {} }
