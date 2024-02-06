resource "boundary_scope" "org" {
  scope_id                 = "global"
  name                     = "db-org-scope"
  description              = "Org for DB MGMT"
  auto_create_default_role = true
  auto_create_admin_role   = true
}

resource "boundary_scope" "project" {
  name                     = "db-org-project"
  description              = "Database MGMT"
  scope_id                 = boundary_scope.org.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "time_sleep" "wait_2_mins" {
  depends_on = [aws_instance.worker]

  create_duration = "120s"
}


resource "boundary_credential_store_vault" "vault" {
  name        = "credential-store"
  description = "Vault for Credential Brokering"
  address     = data.terraform_remote_state.local_backend.outputs.vault_private_url
  token       = vault_token.boundary_token_db.client_token
  scope_id    = boundary_scope.project.id
  namespace   = "admin"
  # Adding worker filter to send request to Vault via Worker, worker that has access to Vault via HVN peering
  worker_filter = " \"worker1\" in \"/tags/type\" "
  # Introducing some delay to let the worker start up
  depends_on = [time_sleep.wait_2_mins]
}

# Credential Libraries Postgres
resource "boundary_credential_library_vault" "dba" {
  name                = "northwind dba"
  description         = "northwind dba"
  credential_store_id = boundary_credential_store_vault.vault.id
  path                = "database/creds/dba" # change to Vault backend path
  http_method         = "GET"
}

resource "boundary_credential_library_vault" "read_only" {
  name                = "northwind readonly"
  description         = "northwind readonly"
  credential_store_id = boundary_credential_store_vault.vault.id
  path                = "database/creds/readonly" # change to Vault backend path
  http_method         = "GET"
}

resource "boundary_credential_library_vault" "write_role" {
  name                = "northwind app"
  description         = "northwind app"
  credential_store_id = boundary_credential_store_vault.vault.id
  path                = "database/creds/write" # change to Vault backend path
  http_method         = "GET"
}

# Credential Librarires DocumentDB
resource "boundary_credential_library_vault" "dba-DocumentDB" {
  name                = "DocumentDB dba"
  description         = "DocumentDB dba"
  credential_store_id = boundary_credential_store_vault.vault.id
  path                = "mongo/creds/dba" # change to Vault backend path
  http_method         = "GET"
}

resource "boundary_credential_library_vault" "readOnlyDocumentDB" {
  name                = "DocumentDB readonly"
  description         = "DocumentDB readonly"
  credential_store_id = boundary_credential_store_vault.vault.id
  path                = "mongo/creds/read_only" # change to Vault backend path
  http_method         = "GET"
}

resource "boundary_credential_library_vault" "readWriteDocumentDB" {
  name                = "DocumentDBind readWrite"
  description         = "DocumentDB readWrite"
  credential_store_id = boundary_credential_store_vault.vault.id
  path                = "mongo/creds/read_write" # change to Vault backend path
  http_method         = "GET"
}

resource "boundary_host_catalog_static" "rds" {
  name        = "db-catalog"
  description = "DB catalog"
  scope_id    = boundary_scope.project.id
}

resource "boundary_host_static" "db" {
  name            = "rds-host"
  host_catalog_id = boundary_host_catalog_static.rds.id
  address         = data.terraform_remote_state.local_backend.outputs.rds_hostname
}

resource "boundary_host_static" "db-mongo" {
  name            = "documentDB-cluster"
  host_catalog_id = boundary_host_catalog_static.rds.id
  address         = data.terraform_remote_state.local_backend.outputs.docdb_cluster_endpoint
}

resource "boundary_host_set_static" "db" {
  name            = "rds-host-set"
  host_catalog_id = boundary_host_catalog_static.rds.id

  host_ids = [
    boundary_host_static.db.id
  ]
}

resource "boundary_host_set_static" "db-mongo" {
  name            = "documentDB-host-set"
  host_catalog_id = boundary_host_catalog_static.rds.id

  host_ids = [
    boundary_host_static.db-mongo.id
  ]
}

resource "boundary_target" "dba" {
  type                     = "tcp"
  name                     = "RDS DBA Access"
  description              = "RDS DBA Permissions"
  ingress_worker_filter    = " \"worker1\" in \"/tags/type\" "
  scope_id                 = boundary_scope.project.id
  session_connection_limit = 3600
  default_port             = 5432
  host_source_ids = [
    boundary_host_set_static.db.id
  ]

  brokered_credential_source_ids = [
    boundary_credential_library_vault.dba.id
  ]

}

resource "boundary_target" "read_only" {
  type                     = "tcp"
  name                     = "RDS ReadOnly Access"
  description              = "RDS: SELECT"
  ingress_worker_filter    = " \"worker1\" in \"/tags/type\" "
  scope_id                 = boundary_scope.project.id
  session_connection_limit = 3600
  default_port             = 5432
  host_source_ids = [
    boundary_host_set_static.db.id
  ]
  brokered_credential_source_ids = [
    boundary_credential_library_vault.read_only.id
  ]
}

resource "boundary_target" "write" {
  type                     = "tcp"
  name                     = "RDS Read/Write Access"
  description              = "RDS: SELECT, INSERT, UPDATE, DELETE"
  ingress_worker_filter    = " \"worker1\" in \"/tags/type\" "
  scope_id                 = boundary_scope.project.id
  session_connection_limit = 3600
  default_port             = 5432
  host_source_ids = [
    boundary_host_set_static.db.id
  ]

  brokered_credential_source_ids = [
    boundary_credential_library_vault.write_role.id
  ]
}
# DocumentDB Targets

resource "boundary_target" "dba_DocumentDB" {
  type                     = "tcp"
  name                     = "DocumentDB DBA Access"
  description              = "DocumentDB: DBA Permissions"
  ingress_worker_filter    = " \"worker1\" in \"/tags/type\" "
  scope_id                 = boundary_scope.project.id
  session_connection_limit = 3600
  default_port             = 27017
  host_source_ids = [
    boundary_host_set_static.db-mongo.id
  ]

  brokered_credential_source_ids = [
    boundary_credential_library_vault.dba-DocumentDB.id
  ]

}

resource "boundary_target" "read_only_DocumentDB" {
  type                     = "tcp"
  name                     = "DocumentDB ReadOnly Access"
  description              = "DocumentDB: readAllDBs"
  ingress_worker_filter    = " \"worker1\" in \"/tags/type\" "
  scope_id                 = boundary_scope.project.id
  session_connection_limit = 3600
  default_port             = 27017
  host_source_ids = [
    boundary_host_set_static.db-mongo.id
  ]
  brokered_credential_source_ids = [
    boundary_credential_library_vault.readOnlyDocumentDB.id
  ]
}

resource "boundary_target" "write_DocumentDB" {
  type                     = "tcp"
  name                     = "DocumentDB Read/Write Access"
  description              = "DocumentDB: readWriteAllDBs"
  ingress_worker_filter    = " \"worker1\" in \"/tags/type\" "
  scope_id                 = boundary_scope.project.id
  session_connection_limit = 3600
  default_port             = 27017
  host_source_ids = [
    boundary_host_set_static.db-mongo.id
  ]

  brokered_credential_source_ids = [
    boundary_credential_library_vault.readWriteDocumentDB.id
  ]
}
