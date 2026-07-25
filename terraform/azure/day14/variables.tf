variable "name" {
  default = "testing"
}

variable "location" {
  default = "centralIndia"
}

variable "security_rules" {
  default = [
    {
      name = "allow-SSH"
      port = 22
    },
    {
      name = "allow-HTTP"
      port = 80
    },
    {
      name = "allow-HTTPS"
      port = 443
    }
  ]
}