# variables.tf
variable "project"              { type = string }
variable "environment"          { type = string }
variable "location"             { type = string }
variable "resource_group_name"  { type = string }
variable "aks_subnet_id"        { type = string }
variable "app_gateway_id"       { type = string }
variable "kubernetes_version"   { type = string; default = "1.30" }
variable "system_node_count"    { type = number; default = 2 }
variable "app_node_vm_size"     { type = string; default = "Standard_D4s_v3" }
variable "app_node_desired"     { type = number; default = 2 }
variable "app_node_min"         { type = number; default = 1 }
variable "app_node_max"         { type = number; default = 10 }
variable "use_spot"             { type = bool;   default = false }
variable "tags"                 { type = map(string); default = {} }
