output "password" {
  value = var.auth0_password
}

output "auth_method_id" {
  value = boundary_auth_method_oidc.provider.id
}

output "boundary_authenticate_cli" {
  value = "boundary authenticate oidc -auth-method-id ${boundary_auth_method_oidc.provider.id}"
}


output "user_dba_email" {
  value = auth0_user.dba.email
}

output "project-scope-id" {
  value = data.boundary_scope.project.id
}

output "user_readwrite_email" {
  value = auth0_user.readwrite.email
}

output "user_readonly_email" {
  value = auth0_user.readonly.email
}