# outputs.tf
output "resource_group_name" { value = azurerm_resource_group.this.name }
output "vnet_id"             { value = azurerm_virtual_network.this.id }
output "aks_subnet_id"       { value = azurerm_subnet.aks.id }
output "appgw_subnet_id"     { value = azurerm_subnet.appgw.id }
output "location"            { value = azurerm_resource_group.this.location }
