resource "random_pet" "lb_hostname" {
  
}

resource "azurerm_resource_group" "rg" {
  name = var.name
  location = var.location
}

resource "azurerm_virtual_network" "vir_net" {
  name = "virtual_network"
  location = azurerm_resource_group.rg.location
  address_space = ["10.0.0.0/16"]
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name = "subnet"
  resource_group_name = azurerm_resource_group.rg.name
  address_prefixes = ["10.0.0.0/24"]
  virtual_network_name = azurerm_virtual_network.vir_net.name
}

resource "azurerm_network_security_group" "myNSG" {
  name                = "myNSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dynamic security_rule {
    for_each = var.security_rules
    content{
    name                       = security_rule.value.name
    priority                   = 100 + security_rule.key
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = security_rule.value.port
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    }
  }

}

resource "azurerm_network_security_group_association" "association" {
  subnet = azurerm_subnet.subnet
  network_security_group_id = azurerm_network_security_group.myNSG.id
}


resource "azurerm_public_ip" "name" {
  name = "lb_public_ip"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method = "static"
  sku = "Standard"
  zones = ["1"]
  domain_name_label = "${azurerm_resource_group.rg.name}-${random_pet.lb_hostname.id}"
}

resource "azurerm_lb" "lb" {
  name = "my_lb"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  sku = "standard"
  frontend_ip_configuration {
    name = "mypublic_ip"
    public_ip_address_id = azurerm_public_ip.name.id
  }
}

resource "azurerm_lb_backend_address_pool" "name" {
  name = "backend_pool"
  loadbalancer_id = azurerm_public_ip.name.id
}

