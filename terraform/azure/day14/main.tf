resource "random_pet" "lb_hostname" {
  
}

resource "azurerm_resource_group" "rg" {
  name = "vmss"
  location = "central India"
}

resource "azurerm_virtual_network" "vnet" {
  name = "${azurerm_resource_group.rg.name}-vnet"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name = "${azurerm_resource_group.rg.name}-subnet"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = [ "10.0.1.0/24" ]
}

resource "azurerm_network_security_group" "nsg" {
  name = "${azurerm_resource_group.rg.name}-nsg"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "rules" {
  for_each = local.security_rules

  name                        = "allow-${each.key}"
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = tostring(each.value.port)
  source_address_prefix       = "*"
  destination_address_prefix  = "*"

  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_subnet_network_security_group_association" "name" {
  subnet_id = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "name" {
  name = "${azurerm_resource_group.rg.name}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku = "Standard"
  zones = ["1"]
  allocation_method = "Static"
  domain_name_label = "${azurerm_resource_group.rg.name}-${random_pet.lb_hostname.id}"
}
resource "azurerm_lb" "example" {
  name                = "myLB"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "myPublicIP"
    public_ip_address_id = azurerm_public_ip.name.id
  }
}

resource "azurerm_lb_backend_address_pool" "bepool" {
  name = "my_backend_pool"
  loadbalancer_id = azurerm_lb.example.id
}

resource "azurerm_lb_rule" "example" {
  name = "http"
  loadbalancer_id = azurerm_lb.example.id
  frontend_port = 80
  backend_port = 80
  frontend_ip_configuration_name = "myPublicIP"
  protocol = "Tcp"
  probe_id = azurerm_lb_probe.example.id
  backend_address_pool_ids = [azurerm_lb_backend_address_pool.bepool.id]
}

resource "azurerm_lb_probe" "example" {
  name = "http_probe"
  loadbalancer_id = azurerm_lb.example.id
  port = 80
  protocol = "Http"
  request_path = "/"
}

resource "azurerm_lb_nat_rule" "ssh" {
  name = "ssh"
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id = azurerm_lb.example.id
  protocol = "Tcp"
  frontend_port_start = 50000
  frontend_port_end = 50019
  backend_port = 22
  frontend_ip_configuration_name = "myPublicIp"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bepool.id
}

resource "azurerm_public_ip" "natgwip" {
  name = "nat_ip"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  sku = "Standard"
  zones = ["1"]
  allocation_method = "Static"
}

resource "azurerm_nat_gateway" "example" {
  name = "nat_gateway"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  sku_name = "Standard"
  idle_timeout_in_minutes = 10
  zones = ["1"]
}

resource "azurerm_subnet_nat_gateway_association" "name" {
  subnet_id = azurerm_subnet.subnet.id
  nat_gateway_id = azurerm_nat_gateway.example.id
}

resource "azurerm_nat_gateway_public_ip_association" "name" {
  public_ip_address_id = azurerm_public_ip.natgwip.id
  nat_gateway_id = azurerm_nat_gateway.example.id
}

