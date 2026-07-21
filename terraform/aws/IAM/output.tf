output "user_names" {
    value = [for user in local.users: "${user.first_name} ${user.last_name}"]
}