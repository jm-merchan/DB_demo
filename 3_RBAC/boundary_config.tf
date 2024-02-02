data "boundary_scope" "org" {
  name     = "db-org-scope"
  scope_id = "global"
}

data "boundary_scope" "project" {
  name     = "db-org-project"
  scope_id = data.boundary_scope.org.id
}


# An Auth0 Client loaded using its ID.
data "auth0_client" "boundary" {
  client_id = auth0_client.boundary.client_id
}

data "auth0_tenant" "tenant" {}

resource "boundary_auth_method_oidc" "provider" {
  name                 = "Auth0"
  description          = "OIDC auth method for Auth0"
  scope_id             = data.boundary_scope.org.id
  issuer               = "https://${data.auth0_tenant.tenant.domain}/"
  client_id            = data.auth0_client.boundary.id
  client_secret        = data.auth0_client.boundary.client_secret
  signing_algorithms   = ["RS256"]
  api_url_prefix       = data.terraform_remote_state.local_backend.outputs.boundary_public_url
  is_primary_for_scope = true
  state                = "active-public"
  max_age              = 0
}

# Configs for Admin User
resource "boundary_account_oidc" "admin" {
  name           = auth0_user.admin.name
  description    = "Admin user from Auth0"
  auth_method_id = boundary_auth_method_oidc.provider.id
  issuer         = "https://${data.auth0_tenant.tenant.domain}/"
  subject        = auth0_user.admin.user_id
}

resource "boundary_user" "admin" {
  name        = boundary_account_oidc.admin.name
  description = "Admin user from Auth0"
  account_ids = [boundary_account_oidc.admin.id]
  scope_id    = data.boundary_scope.org.id
}

resource "boundary_role" "admin_project" {
  # All Permissions for Admin at Project Scope
  name          = "admin-project"
  description   = "Full Admin Permisions at Project level"
  principal_ids = [boundary_user.admin.id]
  grant_strings = ["ids=*;type=*;actions=*"]
  scope_id      = data.boundary_scope.project.id
}

resource "boundary_role" "admin_org" {
  name          = "admin-org"
  description   = "Full Admin Permissions at Org level"
  principal_ids = [boundary_user.admin.id]
  grant_strings = ["ids=*;type=*;actions=*"]
  scope_id      = data.boundary_scope.org.id
}

resource "boundary_role" "admin_global" {
  name          = "admin-org"
  description   = "Full Admin Permissions at Global level"
  principal_ids = [boundary_user.admin.id]
  grant_strings = ["ids=*;type=*;actions=*"]
  scope_id      = "global"
}


# Configs for DBA User
resource "boundary_account_oidc" "dba" {
  name           = auth0_user.dba.name
  description    = "DBA user from Auth0"
  auth_method_id = boundary_auth_method_oidc.provider.id
  issuer         = "https://${data.auth0_tenant.tenant.domain}/"
  subject        = auth0_user.dba.user_id
}

resource "boundary_user" "dba" {
  name        = boundary_account_oidc.dba.name
  description = "DBA user from Auth0"
  account_ids = [boundary_account_oidc.dba.id]
  scope_id    = data.boundary_scope.org.id
}

resource "boundary_role" "dba" {
  # Permissions limited to dba target
  name          = "dba"
  description   = "Access to dba target"
  principal_ids = [boundary_user.dba.id]
  grant_strings = [
    "ids=${data.terraform_remote_state.boundary.outputs.rds_target_dba};actions=authorize-session",
    "ids=${data.terraform_remote_state.boundary.outputs.documentDB_target_dba};actions=authorize-session",
    "ids=*;type=session;actions=read:self,cancel:self,list",
    "ids=*;type=*;actions=read,list"
  ]
  scope_id = data.boundary_scope.project.id
}

# Configs for read/write role
resource "boundary_account_oidc" "read_write" {
  name           = auth0_user.readwrite.name
  description    = "ReadWrite user from Auth0"
  auth_method_id = boundary_auth_method_oidc.provider.id
  issuer         = "https://${data.auth0_tenant.tenant.domain}/"
  subject        = auth0_user.readwrite.user_id
}

resource "boundary_user" "read_write" {
  name        = boundary_account_oidc.read_write.name
  description = "ReadWrite user from Auth0"
  account_ids = [boundary_account_oidc.read_write.id]
  scope_id    = data.boundary_scope.org.id
}

resource "boundary_role" "readwrite" {
  # Permissions limited to read_write target
  name          = "Access to Read Write target"
  description   = "Access to read write db target"
  principal_ids = [boundary_user.read_write.id]
  grant_strings = [
    "ids=${data.terraform_remote_state.boundary.outputs.rds_target_readwrite};actions=authorize-session",
    "ids=${data.terraform_remote_state.boundary.outputs.documentDB_target_readwrite};actions=authorize-session",
    "ids=*;type=session;actions=read:self,cancel:self,list",
    "ids=*;type=*;actions=read,list"
  ]
  scope_id = data.boundary_scope.project.id
}

# Configs for readonlu role
resource "boundary_account_oidc" "read_only" {
  name           = auth0_user.readonly.name
  description    = "Read Only user from Auth0"
  auth_method_id = boundary_auth_method_oidc.provider.id
  issuer         = "https://${data.auth0_tenant.tenant.domain}/"
  subject        = auth0_user.readonly.user_id
}

resource "boundary_user" "read_only" {
  name        = boundary_account_oidc.read_only.name
  description = "Read Only user from Auth0"
  account_ids = [boundary_account_oidc.read_only.id]
  scope_id    = data.boundary_scope.org.id
}

resource "boundary_role" "readonly" {
  # Permissions limited to read_write target
  name          = "readonly db"
  description   = "Access to read only target"
  principal_ids = [boundary_user.read_only.id]
  grant_strings = [
    "ids=${data.terraform_remote_state.boundary.outputs.rds_target_readonly};actions=authorize-session",
    "ids=${data.terraform_remote_state.boundary.outputs.documentDB_target_readonly};actions=authorize-session",
    "ids=*;type=session;actions=read:self,cancel:self,list",
    "ids=*;type=*;actions=read,list"
  ]
  scope_id = data.boundary_scope.project.id
}