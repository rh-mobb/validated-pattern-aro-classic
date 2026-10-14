resource "azurerm_public_ip" "route_server" {
  name                = "${var.cluster_name}-routeserver"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_route_server" "this" {
  name                 = "${var.cluster_name}-routeserver"
  location             = var.location
  resource_group_name  = var.resource_group_name
  sku                  = "Standard"
  public_ip_address_id = azurerm_public_ip.route_server.id
  subnet_id            = var.route_server_subnet_id
  tags                 = var.tags
}
