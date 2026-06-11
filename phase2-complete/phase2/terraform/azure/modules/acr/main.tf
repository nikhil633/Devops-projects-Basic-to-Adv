# terraform/azure/modules/acr/main.tf
resource "azurerm_container_registry" "this" {
  name                = "${replace(var.project, "-", "")}${var.environment}acr"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.environment == "prod" ? "Premium" : "Standard"

  # Premium: geo-replication, content trust, private endpoints
  admin_enabled = false  # use Workload Identity, not admin credentials

  # Enable vulnerability scanning (Microsoft Defender for Containers)
  dynamic "georeplications" {
    for_each = var.environment == "prod" ? var.replication_locations : []
    content {
      location                = georeplications.value
      zone_redundancy_enabled = true
    }
  }

  tags = var.tags
}

# Grant AKS kubelet identity pull access to ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = var.kubelet_identity_object_id
}

# Grant GitHub Actions federated credential push access
resource "azurerm_role_assignment" "github_acr_push" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = var.github_actions_principal_id
}
