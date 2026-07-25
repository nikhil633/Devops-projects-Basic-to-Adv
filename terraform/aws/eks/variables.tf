variable "region" {
  type = string
  default = "us-east-1"
  description = "AWS region"
}

variable "cidr_block" {
  type = string
  default = "10.0.0.0/16"
}

variable "tags" {
  type = map(string)
  default = {
    "terraform" = "true"
    "kubernetes" = "demo-eks-cluster"
  }
  description = "Tags to apply to all resources"
}


variable "eks_version" {
  type = string
  default = "1.36"
  description = "EKS version"
}
variable "cluster_name" {
  type = string
  default = "demo-eks_cluster"
  description = "EKS cluster name"
}