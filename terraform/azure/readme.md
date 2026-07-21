1. VNet Peering Project (Azure version of VPC Peering)
Resources Needed
2 × Virtual Networks (VNets)
2 × Subnets
2 × Network Security Groups (NSGs)
2 × Route Tables (optional)
2 × Public IPs
2 × Network Interfaces
2 × Virtual Machines
2 × VNet Peerings
Terraform Resources
azurerm_virtual_network
azurerm_subnet
azurerm_network_security_group
azurerm_virtual_network_peering
azurerm_linux_virtual_machine
2. IAM User Management (Azure)
Resources Needed
Azure AD Users
Groups
Role Assignments
Service Principals
Terraform Resources
azuread_user
azuread_group
azurerm_role_assignment
azuread_service_principal
3. Blue-Green Deployment
Resources Needed
2 VM Scale Sets or App Services
Azure Load Balancer / Application Gateway
Backend Pools
Health Probes
Flow

Traffic:
Application Gateway → Blue

After deployment:
Application Gateway → Green

Terraform Resources
azurerm_application_gateway
azurerm_linux_virtual_machine_scale_set
4. Canary Deployment
Resources Needed
Application Gateway
Multiple Backend Pools
VM Scale Sets
Traffic Weighting Rules
Flow
90% → old version
10% → new version
5. Highly Available Web App
Resources Needed
1 VNet
Public & Private Subnets
NAT Gateway
NSGs
Application Gateway
VM Scale Sets
Architecture

Internet → Application Gateway → Private VMs

6. Static Website Hosting
Resources Needed
Storage Account
Static Website Feature
CDN
DNS Zone
SSL Certificate
Terraform Resources
azurerm_storage_account
azurerm_cdn_profile
azurerm_dns_zone
7. Multi-Region Disaster Recovery
Resources Needed
2 Regions
Replicated VNets
Traffic Manager
Geo-Redundant Storage
Common Services
Azure Site Recovery
Geo-replication
8. Bastion Host Architecture
Resources Needed
Public Subnet
Private Subnet
Azure Bastion
Private VM
NSGs
Flow

Laptop → Azure Bastion → Private VM

9. CI/CD Pipeline
Resources Needed
Azure Native
Azure DevOps
Repos
Pipelines
Artifacts
Service Connections
Terraform Resources

Mostly configured inside Azure DevOps rather than AzureRM provider.

10. AKS Kubernetes Cluster

(Azure equivalent of EKS)

Resources Needed
VNet
Subnets
AKS Cluster
Node Pools
Managed Identity
NSGs
Terraform Resources
azurerm_kubernetes_cluster
11. Container Deployment

(Azure equivalent of ECS/Fargate)

Resources Needed
Azure Container Registry (ACR)
Container Apps or AKS
Load Balancer
Terraform Resources
azurerm_container_registry
azurerm_container_group
12. SQL Database Production Setup

(Azure equivalent of RDS)

Resources Needed
SQL Server
SQL Database
Private Endpoint
Firewall Rules
Backup Policies
Terraform Resources
azurerm_mssql_server
azurerm_mssql_database
13. Serverless Application

(Azure equivalent of Lambda)

Resources Needed
Function App
Storage Account
API Management
Cosmos DB
Terraform Resources
azurerm_function_app
14. Monitoring & Logging
Resources Needed
Log Analytics Workspace
Azure Monitor
Alerts
Action Groups
Example

CPU > 80% → Send alert

15. Secure Production Network
Resources Needed
NSGs
Azure Firewall
DDoS Protection
Sentinel
Flow Logs
16. Site-to-Site VPN
Resources Needed
Virtual Network Gateway
Local Network Gateway
VPN Connection
17. Hub-Spoke Architecture

(Azure equivalent of Transit Gateway architecture)

Resources Needed
Hub VNet
Multiple Spoke VNets
Peerings
Azure Firewall
18. Auto Scaling Web App
Resources Needed
VM Scale Sets
Load Balancer
Autoscale Rules
Monitor Metrics
19. Secure Storage/Data Lake
Resources Needed
Storage Account
Key Vault
RBAC
Lifecycle Rules
20. Hybrid Architecture
Resources Needed
ExpressRoute
VPN Gateway
Hub VNet
Route Tables


az ad sp create-for-rbac -n az-demo --role="Contributer" --scopes="/subscriptions/subscription-id"
copy appId, password, tenant

They will be used to authenticate terraform account

command to display service priciple   - -  az ad sp list --output table
az ad sp list --display-name "terraform-sp"

export ARM_CLIENT_ID = ""
export ARM_CLIENT_SECRET = ""
export ARM_SUBSCRIPTION_ID = ""
EXPORT arm_TENANT_ID = ""



#!/bin/bash

RESOURCE_GROUP_NAME=tfstate-day04
STORAGE_ACCOUNT_NAME=day04$RANDOM
CONTAINER_NAME=tfstate

# Create resource group
az group create --name $RESOURCE_GROUP_NAME --location eastus

# Create storage account
az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob

# Create blob container
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME