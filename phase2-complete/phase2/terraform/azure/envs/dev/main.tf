# terraform/azure/envs/dev/main.tf
terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = { source = "hashicorp/azurerm"; version = "~> 3.100" }
    azuread = { source = "hashicorp/azuread"; version = "~> 2.50" }
  }

  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"    # create manually first
    storage_account_name = "myprojtfstate"          # globally unique name
    container_name       = "tfstate"
    key                  = "azure/dev/terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault { purge_soft_delete_on_destroy = false }
  }
}

locals {
  common_tags = {
    Project     = var.project
    Environment = "dev"
    ManagedBy   = "terraform"
    Team        = var.team
  }
}

# ── VNet ──────────────────────────────────────────────────────────────────
module "vnet" {
  source      = "../../modules/vnet"
  project     = var.project
  environment = "dev"
  location    = var.location
  vnet_cidr   = "10.1.0.0/16"
  tags        = local.common_tags
}

# ── Application Gateway (required by AGIC) ────────────────────────────────
resource "azurerm_public_ip" "appgw" {
  name                = "${var.project}-dev-appgw-pip"
  resource_group_name = module.vnet.resource_group_name
  location            = module.vnet.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_application_gateway" "this" {
  name                = "${var.project}-dev-appgw"
  resource_group_name = module.vnet.resource_group_name
  location            = module.vnet.location

  sku { name = "Standard_v2"; tier = "Standard_v2"; capacity = 2 }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = module.vnet.appgw_subnet_id
  }

  frontend_port          { name = "http-port";  port = 80  }
  frontend_port          { name = "https-port"; port = 443 }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  # Placeholder backend/listener — AGIC will manage these after AKS deploys
  backend_address_pool     { name = "placeholder-pool" }
  backend_http_settings    { name = "placeholder-settings"; cookie_based_affinity = "Disabled"; port = 80; protocol = "Http"; request_timeout = 20 }
  http_listener            { name = "placeholder-listener"; frontend_ip_configuration_name = "appgw-frontend-ip"; frontend_port_name = "http-port"; protocol = "Http" }
  request_routing_rule     { name = "placeholder-rule"; rule_type = "Basic"; http_listener_name = "placeholder-listener"; backend_address_pool_name = "placeholder-pool"; backend_http_settings_name = "placeholder-settings"; priority = 1 }

  tags = local.common_tags
}

# ── GitHub Actions Workload Identity Federation ───────────────────────────
data "azurerm_subscription" "current" {}
data "azuread_client_config" "current" {}

resource "azuread_application" "github_actions" {
  display_name = "${var.project}-dev-github-actions"
}

resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
}

# Federated credential — no client secrets, GitHub gets tokens from OIDC
resource "azuread_application_federated_identity_credential" "github" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-actions-dev"
  description    = "GitHub Actions OIDC for dev"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:environment:dev"
}

resource "azurerm_role_assignment" "github_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# ── AKS ───────────────────────────────────────────────────────────────────
module "aks" {
  source              = "../../modules/aks"
  project             = var.project
  environment         = "dev"
  location            = module.vnet.location
  resource_group_name = module.vnet.resource_group_name
  aks_subnet_id       = module.vnet.aks_subnet_id
  app_gateway_id      = azurerm_application_gateway.this.id
  use_spot            = true
  app_node_vm_size    = "Standard_D2s_v3"
  app_node_min        = 1
  app_node_max        = 5
  app_node_desired    = 2
  tags                = local.common_tags
}

# ── ACR ───────────────────────────────────────────────────────────────────
module "acr" {
  source                      = "../../modules/acr"
  project                     = var.project
  environment                 = "dev"
  location                    = module.vnet.location
  resource_group_name         = module.vnet.resource_group_name
  kubelet_identity_object_id  = module.aks.kubelet_identity_obj_id
  github_actions_principal_id = azuread_service_principal.github_actions.object_id
  tags                        = local.common_tags
}

# ── Outputs ───────────────────────────────────────────────────────────────
output "cluster_name"          { value = module.aks.cluster_name }
output "acr_login_server"      { value = module.acr.login_server }
output "oidc_issuer_url"       { value = module.aks.oidc_issuer_url }
output "resource_group"        { value = module.vnet.resource_group_name }
output "client_id"             { value = azuread_application.github_actions.client_id }
