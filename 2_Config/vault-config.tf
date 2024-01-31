resource "vault_policy" "boundary_controller" {
  name = "boundary-controller"
  policy = file("boundary-controller-policy.hcl")
}


resource "vault_mount" "database" {
  path        = "database"
  type        = "database"
  description = "Postgres DB Engine"

  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 7200
}

resource "vault_database_secret_backend_connection" "postgres" {
  backend       = vault_mount.database.path
  name          = "boundarydemo"
  allowed_roles = ["*"]
  verify_connection = false

  # Going towards the private IP of the Ubuntu Server
  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@${data.terraform_remote_state.local_backend.outputs.rds_hostname}:5432/postgres?sslmode=disable"
    username       = var.db_name
    password       = var.password
    max_open_connections = 5
  }
}

resource "vault_database_secret_backend_role" "dba" {
  backend             = vault_mount.database.path
  name                = "dba"
  db_name             = vault_database_secret_backend_connection.postgres.name
  creation_statements = [
    "CREATE USER \"{{name}}\" WITH LOGIN ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT rds_superuser to \"{{name}}\"",
    "GRANT CONNECT ON DATABASE northwind TO \"{{name}}\";",
    "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
    "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";",
    "ALTER ROLE \"{{name}}\" WITH CREATEDB;"
    ]
  revocation_statements = [
    "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM \"{{name}}\";", 
    "DROP OWNED BY \"{{name}}\";",
    "DROP ROLE \"{{name}}\";"
    ]
  default_ttl = 3600
}

resource "vault_database_secret_backend_role" "read_only" {
  backend             = vault_mount.database.path
  name                = "readonly"
  db_name             = vault_database_secret_backend_connection.postgres.name
  creation_statements = [
    "CREATE USER \"{{name}}\" WITH LOGIN ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT readonly TO \"{{name}}\";"
    ]
  revocation_statements = [
    "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM \"{{name}}\";", 
    "DROP OWNED BY \"{{name}}\";",
    "DROP ROLE \"{{name}}\";"
    ]
  default_ttl = 3600
}

resource "vault_database_secret_backend_role" "write_role" {
  backend             = vault_mount.database.path
  name                = "write"
  db_name             = vault_database_secret_backend_connection.postgres.name
  creation_statements = [
    "CREATE USER \"{{name}}\" WITH LOGIN ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT readwrite TO \"{{name}}\";",
    ]
  revocation_statements = [
    "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM \"{{name}}\";", 
    "DROP OWNED BY \"{{name}}\";",
    "DROP ROLE \"{{name}}\";"
    ]
  default_ttl = 1800
}


resource "vault_policy" "northwind_database" {
  name = "northwind-database"

  policy = file("northwind-database-policy.hcl")
}

resource "vault_token" "boundary_token_db" {
  no_default_policy = true
  period            = "20m"
  policies = [
    "boundary-controller",
    "northwind-database"
  ]
  no_parent = true
  renewable = true

  renew_min_lease = 43200
  renew_increment = 86400

  metadata = {
    "purpose" = "service-account-boundary-database"
  }
}