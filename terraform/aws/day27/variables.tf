variable "environment" {
  description = "Vpc-name"
  type        = string
  default     = "prod"
}


variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "image_id" {
  description = "The image id for ec2"
  type = string
  default = "ami-0332d564d76dbd8d6"
}

variable "instance_type" {
  description = "Instance type for ec2"
  type = string
  default = "t2.nano"
}

variable "desired_capacity" {
  description = "The desired number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "The maximum number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 5
}

variable "min_size" {
  description = "The minimum number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 1
}