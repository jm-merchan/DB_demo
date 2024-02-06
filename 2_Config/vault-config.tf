resource "vault_policy" "boundary_controller" {
  name   = "boundary-controller"
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
  backend           = vault_mount.database.path
  name              = "demo-postgres"
  allowed_roles     = ["*"]
  verify_connection = false

  # Going towards the private IP of the Ubuntu Server
  postgresql {
    connection_url       = "postgresql://{{username}}:{{password}}@${data.terraform_remote_state.local_backend.outputs.rds_hostname}:5432/${var.db_name}?sslmode=disable"
    username             = var.db_username
    password             = var.password
    max_open_connections = 5
  }
}
# Add DB Secret engine mount point
resource "vault_mount" "database_mongo" {
  path        = "mongo"
  type        = "database"
  description = "MongoDB Engine"

  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 7200
}

# Define connection as mongodb
resource "vault_database_secret_backend_connection" "mongo" {
  backend           = vault_mount.database_mongo.path
  name              = "demo-mongo"
  allowed_roles     = ["*"]
  verify_connection = false

  mongodb {
    connection_url = "mongodb://{{username}}:{{password}}@${data.terraform_remote_state.local_backend.outputs.docdb_cluster_endpoint}:27017/admin?tls=true&retryWrites=false"
    username       = var.db_username
    password       = var.password
    # Manually add this cert https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem as CA
  }
}


resource "vault_database_secret_backend_role" "mongo_dba" {
  backend = vault_mount.database_mongo.path
  name    = "dba"
  db_name = vault_database_secret_backend_connection.mongo.name
  creation_statements = [<<-EOF
  { "db": "tes",  "roles": [ {"role": "userAdminAnyDatabase"},{"role":"dbAdminAnyDatabase"},{"role":"readWriteAnyDatabase"}]}
  EOF
  ]
  default_ttl = 3600
  max_ttl     = 84000
}

resource "vault_database_secret_backend_role" "mongo_readwrite" {
  backend = vault_mount.database_mongo.path
  name    = "read_write"
  db_name = vault_database_secret_backend_connection.mongo.name
  creation_statements = [<<-EOF
  { "db": "admin",  "roles": [{ "role": "readWriteAnyDatabase" }]}
  EOF
  ]
  default_ttl = 3600
  max_ttl     = 84000
}

resource "vault_database_secret_backend_role" "mongo_readonly" {
  backend = vault_mount.database_mongo.path
  name    = "read_only"
  db_name = vault_database_secret_backend_connection.mongo.name
  creation_statements = [<<-EOF
  { "db": "admin",  "roles": [{ "role": "readAnyDatabase" }]}
  EOF
  ]
  default_ttl = 3600
  max_ttl     = 84000
}

resource "vault_database_secret_backend_role" "dba" {
  backend = vault_mount.database.path
  name    = "dba"
  db_name = vault_database_secret_backend_connection.postgres.name
  creation_statements = [
    "CREATE USER \"{{name}}\" WITH LOGIN ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT rds_superuser to \"{{name}}\"",
    "GRANT CONNECT ON DATABASE ${var.db_name} TO \"{{name}}\";",
    "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
    "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";",   
    "ALTER ROLE \"{{name}}\" WITH CREATEDB CREATEROLE;",
  ]
  default_ttl = 3600
}

resource "vault_database_secret_backend_role" "read_only" {
  backend = vault_mount.database.path
  name    = "readonly"
  db_name = vault_database_secret_backend_connection.postgres.name
  creation_statements = [
    "CREATE USER \"{{name}}\" WITH LOGIN ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT CONNECT ON DATABASE ${var.db_name} TO \"{{name}}\";",
    "GRANT USAGE ON SCHEMA public TO \"{{name}}\";",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
  ]
  default_ttl = 3600
}

resource "vault_database_secret_backend_role" "write_role" {
  backend = vault_mount.database.path
  name    = "write"
  db_name = vault_database_secret_backend_connection.postgres.name
  creation_statements = [
    "CREATE USER \"{{name}}\" WITH LOGIN ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT CONNECT ON DATABASE ${var.db_name} TO \"{{name}}\";",
    "GRANT USAGE ON SCHEMA public TO \"{{name}}\";",
    "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
    "GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";"
  ]
  default_ttl = 1800
}


resource "vault_policy" "northwind_database" {
  name = "policy-database"

  policy = file("database-policy.hcl")
}

resource "vault_token" "boundary_token_db" {
  no_default_policy = true
  period            = "20m"
  policies = [
    "boundary-controller",
    "policy-database"
  ]
  no_parent = true
  renewable = true

  renew_min_lease = 43200
  renew_increment = 86400

  metadata = {
    "purpose" = "service-account-boundary-database"
  }
}