# variables.tf
variable "project"                       { type = string }
variable "environment"                   { type = string }
variable "location"                      { type = string }
variable "resource_group_name"           { type = string }
variable "kubelet_identity_object_id"    { type = string }
variable "github_actions_principal_id"   { type = string }
variable "replication_locations"         { type = list(string); default = ["westus2"] }
variable "tags"                          { type = map(string); default = {} }
