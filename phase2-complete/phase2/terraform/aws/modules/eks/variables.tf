# terraform/aws/modules/eks/variables.tf
variable "project"                  { type = string }
variable "environment"              { type = string }
variable "kubernetes_version"       { type = string; default = "1.30" }
variable "private_subnet_ids"       { type = list(string) }
variable "public_api_access"        { type = bool; default = false }
variable "api_access_cidrs"         { type = list(string); default = ["0.0.0.0/0"] }
variable "app_node_instance_types"  { type = list(string); default = ["t3.large"] }
variable "app_node_desired"         { type = number; default = 2 }
variable "app_node_min"             { type = number; default = 1 }
variable "app_node_max"             { type = number; default = 10 }
variable "use_spot"                 { type = bool; default = false }
variable "tags"                     { type = map(string); default = {} }
