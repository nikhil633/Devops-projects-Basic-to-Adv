locals {
  security_rules = {
    http = {
      priority = 100
      port     = 80
    }

    https = {
      priority = 101
      port     = 443
    }

    ssh = {
      priority = 102
      port     = 22
    }
  }
}