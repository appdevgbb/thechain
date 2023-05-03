resource "azurerm_public_ip" "jumpbox-pip" {
  name                = "${local.hostname}-jumpbox-pip-${var.index}"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "jumpbox" {
  name                = "${local.hostname}-jumpbox-nic-${var.index}"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  enable_accelerated_networking = true

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox-pip.id
  }
}

resource "azurerm_network_security_group" "jumpbox" {
  name                = "JumpboxNSG"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "jumpbox" {
  network_interface_id      = azurerm_network_interface.jumpbox.id
  network_security_group_id = azurerm_network_security_group.jumpbox.id
}


resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                = "${local.hostname}jumpbox${var.index}"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  size                = var.sku
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.jumpbox.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("~/.ssh/id_rsa.pub")
  }

  custom_data = base64encode(templatefile("${path.module}/config/cloud-init.yaml",
    {
      admin_username = var.admin_username
      ssh_key        = file("~/.ssh/id_rsa.pub")
  }))

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = var.caching
    storage_account_type = var.storage_account_type
    disk_size_gb         = var.disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_role_assignment" "jumpbox-contributor" {
  scope                = var.resource_group.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_linux_virtual_machine.jumpbox.identity[0].principal_id
}