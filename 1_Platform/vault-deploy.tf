resource "hcp_vault_cluster" "hcp_vault" {
  hvn_id          = hcp_hvn.hvn.hvn_id
  cluster_id      = var.vault_cluster_id
  tier            = var.vault_tier
  public_endpoint = true
  proxy_endpoint  = "enabled"
  /*
  Remove stanzas below if not required
  */
  metrics_config {
    datadog_api_key = var.datadog_api_key
    datadog_region  = "us1"
  }
  audit_log_config {
    datadog_api_key = var.datadog_api_key
    datadog_region  = "us1"
  }
}

resource "hcp_vault_cluster_admin_token" "token" {
  cluster_id = var.vault_cluster_id
  depends_on = [hcp_vault_cluster.hcp_vault]
}

