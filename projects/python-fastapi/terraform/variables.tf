variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "productapi"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "node_count" {
  description = "AKS node count"
  type        = number
  default     = 2
}
