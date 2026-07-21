resource "aws_iam_user" "name" {

for_each = {for user in local.users: user.first_name => user}

name = lower("${substr(each.value.first_name,0,1)}${each.value.last_name}")
path = "/users/"

tags = {

}

}

