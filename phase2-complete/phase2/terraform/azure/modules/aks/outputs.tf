# outputs.tf
output "cluster_name"              { value = azurerm_kubernetes_cluster.this.name }
output "cluster_id"                { value = azurerm_kubernetes_cluster.this.id }
output "kube_config"               { value = azurerm_kubernetes_cluster.this.kube_config_raw; sensitive = true }
output "oidc_issuer_url"           { value = azurerm_kubernetes_cluster.this.oidc_issuer_url }
output "kubelet_identity_obj_id"   { value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id }
output "key_vault_id"              { value = azurerm_key_vault.this.id }
output "key_vault_uri"             { value = azurerm_key_vault.this.vault_uri }
