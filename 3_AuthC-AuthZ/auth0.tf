resource "random_string" "random" {
  count            = 4
  length           = 4
  special          = true
  override_special = "."
  lower            = true
  min_special      = 0
}


resource "auth0_user" "user" {
  for_each = {
    "random1" = random_string.random[0].result
    "random2" = random_string.random[1].result
    "random3" = random_string.random[2].result
    "random4" = random_string.random[3].result
  }
  connection_name = "Username-Password-Authentication"
  name           = "${var.auth0_name}${each.value}"
  email          = "${var.auth0_name}${each.value}@boundaryproject.io"
  email_verified = true
  password       = var.auth0_password
}

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

resource "auth0_role" "readonlyDB" {
  name        = "readonlyDB"
  description = "Role for users with readonly access to DB"
}

resource "auth0_user_role" "user_roles1" {
  user_id = auth0_user.user["random1"].id
  role_id = auth0_role.readonlyDB.id
}

resource "auth0_role" "readwriteDB" {
  name        = "readwriteDB"
  description = "Role for users with readwrite access to DB"
}

resource "auth0_user_role" "user_roles2" {
  user_id = auth0_user.user["random2"].id
  role_id = auth0_role.readwriteDB.id
}

resource "auth0_role" "dba" {
  name        = "dbaDB"
  description = "Role for users with dba access to DB"
}

resource "auth0_user_role" "user_roles3" {
  user_id = auth0_user.user["random3"].id
  role_id = auth0_role.dba.id
}

resource "auth0_role" "boundary_admin" {
  name        = "boundary_admin"
  description = "Role for boundary admin"
}

resource "auth0_user_role" "user_roles4" {
  user_id = auth0_user.user["random4"].id
  role_id = auth0_role.boundary_admin.id
}


resource "auth0_action" "my_action" {
  name    = "Test Action"
  runtime = "node18"
  deploy  = true
  code    = <<-EOT
    exports.onExecuteCredentialsExchange = async (event, api) => {
    api.accessToken.setCustomClaim('myClaim', 'this is a private, non namespaced claim');
  };
  EOT

  supported_triggers {
    id      = "credentials-exchange"
    version = "v2"
  }

}