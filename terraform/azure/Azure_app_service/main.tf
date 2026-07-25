variable "prefix" {
  type = string
  default = "nikhil"
}

resource "azurerm_resource_group" "name" {
  name = "${var.prefix}-rg"
  location = "centralIndia"
}

resource "azurerm_service_plan" "asp" {
  name = "${var.prefix}_asp"
  location = azurerm_resource_group.name.location
  resource_group_name = azurerm_resource_group.name.name

  sku_name = "B1"
  os_type = "Linux"
}

resource "azurerm_linux_web_app" "example" {
  name                = "${var.prefix}web-app"
  resource_group_name = azurerm_resource_group.name.name
  location            = azurerm_service_plan.asp.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {}
}

resource "azurerm_linux_web_app_slot" "example" {
  name           = "example-slot"
  app_service_id = azurerm_linux_web_app.example.id

  site_config {}
}

