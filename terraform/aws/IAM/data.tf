data "aws_caller_identity" "account_id" {
  
}

output "account_id" {
  value = data.aws_caller_identity.account_id
}

