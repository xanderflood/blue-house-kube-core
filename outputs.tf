output "admin_auth_password" {
  value = random_password.admin_basic_auth.result
}
output "postgres_admin_password" {
  value = random_password.postgres_admin_password.result
}
