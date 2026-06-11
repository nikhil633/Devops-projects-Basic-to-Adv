# terraform/azure/modules/aks/main.tf
# Creates:
#   - AKS cluster with Workload Identity Federation (no stored secrets)
#   - System + user node pools
#   - AGIC (Application Gateway Ingress Controller) add-on
#   - Azure Monitor / Container Insights
#   - Key Vault integration

locals {
  name = "${var.project}-${var.environment}"
}

# ── AKS Cluster ───────────────────────────────────────────────────────────
resource "azurerm_kubernetes_cluster" "this" {
  name                = "${local.name}-aks"
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = "${local.name}-aks"
  kubernetes_version  = var.kubernetes_version

  # System node pool — runs kube-system workloads
  default_node_pool {
    name                 = "system"
    node_count           = var.system_node_count
    vm_size              = "Standard_D2s_v3"
    vnet_subnet_id       = var.aks_subnet_id
    os_disk_size_gb      = 50
    os_disk_type         = "Managed"
    type                 = "VirtualMachineScaleSets"
    enable_auto_scaling  = true
    min_count            = 2
    max_count            = 4
    only_critical_addons_enabled = true  # only system pods here

    node_labels = { role = "system" }

    upgrade_settings { max_surge = "33%" }
  }

  # Managed identity for the cluster itself
  identity { type = "SystemAssigned" }

  # Workload Identity Federation — pods get Azure AD tokens,
  # no stored credentials in Kubernetes secrets
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # RBAC + Azure AD integration
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  # Network: Azure CNI gives each pod a real VNet IP (better for peering/firewall)
  network_profile {
    network_plugin     = "azure"
    network_policy     = "calico"   # pod-level firewall (NetworkPolicy support)
    load_balancer_sku  = "standard"
    outbound_type      = "loadBalancer"
    service_cidr       = "10.100.0.0/16"
    dns_service_ip     = "10.100.0.10"
  }

  # AGIC ingress add-on (App Gateway Ingress Controller)
  ingress_application_gateway {
    gateway_id = var.app_gateway_id
  }

  # Azure Monitor / Container Insights
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  }

  # Secret Store CSI driver — mount Key Vault secrets as volumes
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+00:00"
  }

  tags = var.tags
}

# ── Application node pool ──────────────────────────────────────────────────
resource "azurerm_kubernetes_cluster_node_pool" "app" {
  name                  = "app"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.app_node_vm_size
  vnet_subnet_id        = var.aks_subnet_id
  os_disk_size_gb       = 100
  enable_auto_scaling   = true
  min_count             = var.app_node_min
  max_count             = var.app_node_max
  node_count            = var.app_node_desired
  priority              = var.use_spot ? "Spot" : "Regular"
  eviction_policy       = var.use_spot ? "Delete" : null
  spot_max_price        = var.use_spot ? -1 : null  # -1 = pay market price

  node_labels = {
    role                                    = "app"
    "kubernetes.azure.com/scalesetpriority" = var.use_spot ? "spot" : "regular"
  }

  node_taints = var.use_spot ? ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"] : []

  upgrade_settings { max_surge = "33%" }
  tags = var.tags
}

# ── Log Analytics workspace ────────────────────────────────────────────────
resource "azurerm_log_analytics_workspace" "this" {
  name                = "${local.name}-logs"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ── Key Vault for secrets ──────────────────────────────────────────────────
resource "azurerm_key_vault" "this" {
  name                        = "${local.name}-kv"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true   # prevents accidental deletion in prod

  # AKS Workload Identity can read secrets
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id

    secret_permissions = ["Get", "List"]
  }

  tags = var.tags
}

data "azurerm_client_config" "current" {}
