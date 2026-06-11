# variables.tf
variable "location"    { type = string; default = "eastus" }
variable "project"     { type = string; default = "myproject" }
variable "team"        { type = string; default = "platform" }
variable "github_org"  { type = string }
variable "github_repo" { type = string }
