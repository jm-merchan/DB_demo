# Read Permissions for RDS Postgres
path "database/creds/*" {
  capabilities = ["read"]
}
# Read Permissions for DocumentDB
path "mongo/creds/*" {
  capabilities = ["read"]
}