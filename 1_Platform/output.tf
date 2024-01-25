output "vault_private_url" {
  value = hcp_vault_cluster.hcp_vault.vault_private_endpoint_url
}

output "vault_public_url" {
  value = hcp_vault_cluster.hcp_vault.vault_public_endpoint_url
}

output "vault_proxy_endpoint" {
  value = hcp_vault_cluster.hcp_vault.vault_proxy_endpoint_url
}


output "boundary_public_url" {
  value = hcp_boundary_cluster.boundary.cluster_url
}

output "vpc" {
  value = aws_vpc.vpc.id
}

output "peering_id" {
  value = hcp_aws_network_peering.peer.provider_peering_id
}

output "vault_token" {
  value = nonsensitive(hcp_vault_cluster_admin_token.token.token)
}

output "rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.boundary_demo.address
}