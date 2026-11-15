resource "azurerm_resource_group" "main" {
  name     = var.name
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = var.name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_cidr]
}

resource "azurerm_subnet" "nodes" {
  name                 = "nodes"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 4, 0)]
}

resource "azurerm_subnet" "sandbox" {
  name                 = "sandbox"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 32)]
}

resource "azurerm_subnet" "database" {
  name                 = "database"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 33)]

  delegation {
    name = "postgres"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.name
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                 = "default"
    vm_size              = var.node_vm_size
    vnet_subnet_id       = azurerm_subnet.nodes.id
    auto_scaling_enabled = true
    min_count            = var.min_nodes
    max_count            = var.max_nodes
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium" # enforces NetworkPolicy
    pod_cidr            = "10.244.0.0/16" # the base trusted-proxies.conf assumes this range
    service_cidr        = "10.41.0.0/16"
    dns_service_ip      = "10.41.0.10"
  }
}

# ---- PostgreSQL Flexible Server, private access ----
resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.name}.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "postgres"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  resource_group_name   = azurerm_resource_group.main.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "azurerm_postgresql_flexible_server" "postgres" {
  name                          = "${var.name}-pg"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = "16"
  sku_name                      = var.database_sku
  storage_mb                    = 131072
  backup_retention_days         = 14
  delegated_subnet_id           = azurerm_subnet.database.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false
  administrator_login           = "kuasar_admin"
  administrator_password        = random_password.db.result
  zone                          = "1"

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

# ---- Sandbox host ----
resource "azurerm_network_security_group" "sandbox" {
  name                = "${var.name}-sandbox"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.admin_cidrs
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "from-vnet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "8090"]
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "sandbox" {
  subnet_id                 = azurerm_subnet.sandbox.id
  network_security_group_id = azurerm_network_security_group.sandbox.id
}

resource "azurerm_network_interface" "sandbox" {
  name                = "${var.name}-sandbox"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sandbox.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "sandbox" {
  name                  = "${var.name}-sandbox"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  size                  = var.sandbox_vm_size
  admin_username        = "kuasar"
  network_interface_ids = [azurerm_network_interface.sandbox.id]
  custom_data           = base64encode(file("${path.module}/../sandbox-host/cloud-init.yaml"))

  admin_ssh_key {
    username   = "kuasar"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 100
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
