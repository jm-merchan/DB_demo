
resource "auth0_client" "boundary" {
  name                = "Boundary"
  description         = "Boundary"
  app_type            = "regular_web"
  callbacks           = ["${data.terraform_remote_state.local_backend.outputs.boundary_public_url}/v1/auth-methods/oidc:authenticate:callback"]
  allowed_logout_urls = ["${data.terraform_remote_state.local_backend.outputs.boundary_public_url}:3000"]
  oidc_conformant     = true

  jwt_configuration {
    alg = "RS256"
  }
}


resource "auth0_user" "admin" {
  connection_name = "Username-Password-Authentication"
  name            = "Boundary Admin"
  email           = "boundary.admin@boundaryproject.io"
  email_verified  = true
  password        = var.auth0_password
}

resource "auth0_user" "dba" {
  connection_name = "Username-Password-Authentication"
  name            = "DBA User"
  email           = "dba@boundaryproject.io"
  email_verified  = true
  password        = var.auth0_password
}

resource "auth0_user" "readwrite" {
  connection_name = "Username-Password-Authentication"
  name            = "DB Read Write"
  email           = "readwrite@boundaryproject.io"
  email_verified  = true
  password        = var.auth0_password
}

resource "auth0_user" "readonly" {
  connection_name = "Username-Password-Authentication"
  name            = "DB Read Only"
  email           = "readonly@boundaryproject.io"
  email_verified  = true
  password        = var.auth0_password
}



resource "auth0_role" "readonlyDB" {
  name        = "readonlyDB"
  description = "Role for users with readonly access to DB"
}

resource "auth0_user_role" "user_roles1" {
  user_id = auth0_user.readonly.id
  role_id = auth0_role.readonlyDB.id
}

resource "auth0_role" "readwriteDB" {
  name        = "readwriteDB"
  description = "Role for users with readwrite access to DB"
}

resource "auth0_user_role" "user_roles2" {
  user_id = auth0_user.readwrite.id
  role_id = auth0_role.readwriteDB.id
}

resource "auth0_role" "dba" {
  name        = "dbaDB"
  description = "Role for users with dba access to DB"
}

resource "auth0_user_role" "user_roles3" {
  user_id = auth0_user.dba.id
  role_id = auth0_role.dba.id
}

resource "auth0_role" "boundary_admin" {
  name        = "boundary_admin"
  description = "Role for boundary admin"
}

resource "auth0_user_role" "user_roles4" {
  user_id = auth0_user.admin.id
  role_id = auth0_role.boundary_admin.id
}