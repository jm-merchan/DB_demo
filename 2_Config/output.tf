output "worker_fqdn" {
  value = aws_instance.worker.public_dns
}

output "ssh_worker_fqdn" {
  value = "ssh -i ${var.key_pair_name}.pem ubuntu@${aws_instance.worker.public_dns}"
}

output "connect_rds_target_readonly" {
  value = "boundary connect postgres -target-id ${boundary_target.read_only.id} -dbname northwind"
}

output "connect_rds_target_readwrite" {
  value = "boundary connect postgres -target-id ${boundary_target.write.id} -dbname northwind"
}

output "connect_rds_target_dba" {
  value = "boundary connect postgres -target-id ${boundary_target.dba.id} -dbname northwind"
}

output "connect_documentDB_target_readonly" {
  value = <<-EOF
  eval "$(boundary targets authorize-session -id ${boundary_target.read_only_DocumentDB.id} -format json | jq -r '.item | "export BOUNDARY_SESSION_TOKEN=\(.authorization_token) BOUNDARY_SESSION_USERNAME=\(.credentials[0].secret.decoded.username) BOUNDARY_SESSION_PASSWORD=\(.credentials[0].secret.decoded.password)"')"
  boundary connect -exec mongosh -authz-token=$BOUNDARY_SESSION_TOKEN --  --tls --host {{boundary.addr}} --username $BOUNDARY_SESSION_USERNAME --password $BOUNDARY_SESSION_PASSWORD --tlsAllowInvalidCertificates --retryWrites false
  
  EOF
}

output "connect_documentDB_target_readwrite" {
  value = <<-EOF
  eval "$(boundary targets authorize-session -id ${boundary_target.write_DocumentDB.id} -format json | jq -r '.item | "export BOUNDARY_SESSION_TOKEN=\(.authorization_token) BOUNDARY_SESSION_USERNAME=\(.credentials[0].secret.decoded.username) BOUNDARY_SESSION_PASSWORD=\(.credentials[0].secret.decoded.password)"')"
  boundary connect -exec mongosh -authz-token=$BOUNDARY_SESSION_TOKEN --  --tls --host {{boundary.addr}} --username $BOUNDARY_SESSION_USERNAME --password $BOUNDARY_SESSION_PASSWORD --tlsAllowInvalidCertificates --retryWrites false
  
  EOF
}

output "connect_documentDB_target_dba" {
  value = <<-EOF
  eval "$(boundary targets authorize-session -id ${boundary_target.dba_DocumentDB.id} -format json | jq -r '.item | "export BOUNDARY_SESSION_TOKEN=\(.authorization_token) BOUNDARY_SESSION_USERNAME=\(.credentials[0].secret.decoded.username) BOUNDARY_SESSION_PASSWORD=\(.credentials[0].secret.decoded.password)"')"
  boundary connect -exec mongosh -authz-token=$BOUNDARY_SESSION_TOKEN --  --tls --host {{boundary.addr}} --username $BOUNDARY_SESSION_USERNAME --password $BOUNDARY_SESSION_PASSWORD --tlsAllowInvalidCertificates --retryWrites false
  
  EOF
}

# targets only

output "rds_target_readonly" {
  value = boundary_target.read_only.id
}

output "rds_target_readwrite" {
  value = boundary_target.write.id
}

output "rds_target_dba" {
  value = boundary_target.dba.id
}

output "documentDB_target_readonly" {
  value = boundary_target.read_only_DocumentDB.id
}

output "documentDB_target_readwrite" {
  value = boundary_target.write_DocumentDB.id
}

output "documentDB_target_dba" {
  value = boundary_target.dba_DocumentDB.id
}