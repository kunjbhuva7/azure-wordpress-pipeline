provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

resource "azurerm_resource_group" "rg" {
  name     = "wordpress-rg-3"
  location = "East US"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "wordpress-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "wordpress-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "wordpress-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "public_ip" {
  name                = "wordpress-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "wordpress-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "wordpress-vms"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCqAKGb5aEX5ozMFYukLvPseLrMDbUmidA8Hn6rknFxM1zP7bdOgKeMMpRVdUdXF0C0cisZpeczIMQzDJ+aKfSLa27KFdzDuBrkei6PpL4WG98tp+E9KheCUfQSRlGPU+SHbppox6mTSpf9/iUeswkl31/74zww0UQFWiN9Gbc9EMVintuHJDSycm3h/6QIj3cCQiEtCkH+bZFmwfmIO6rZ4c8Vm596vXWS33+V/xv3ifAIq4hOI4yxQPltgaaXRcaCx5oQWRCWvk6sNEGPgxbNrVAKjf7i4lCZUxSWeURCQxMeRJlUl6aVLpMVG/swITCmqA1qY0GQHclo9gm6z7xKsWYM9uQXT7dJNRi9t+/A1joRYZkIxqKw/U2AhPstMCpiID94yX+cZOokAzCvJFhWUuYSoquiv8uALp4qmaZ2xSp9IstJIRlM4QwyTHwqfecvFkwRzRbGLR936m1BA69E63Wb963aUHGobUDIVGrvURDMzYd+cTiMkxPRCR1UyuGCGNADe5zl6veB785YDuNLZ53mSXAGtrj5QZYFGqZRCVw1fYWrB3Jhm8WG/co4CObZ94e9R8TR/fU+r0S1ZVCVNa9QTndbs/tQYraSRix7HMv7grBP3d7rKk4V4jmsy9N+dFOSZeTl9weZzpEiOripApOqTxAyinWQi52IaSqqIQ== kunjbhuva@kunjs-MacBook-Air.local"
  }

  os_disk {
    name                 = "osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  tags = {
    environment = "dev"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2 php mysql-server php-mysql wget unzip",
      "cd /var/www/html",
      "sudo rm index.html",
      "sudo wget https://wordpress.org/latest.zip",
      "sudo unzip latest.zip",
      "sudo mv wordpress/* .",
      "sudo rm -rf wordpress latest.zip",
      "sudo chown -R www-data:www-data /var/www/html"
    ]

    connection {
      type     = "ssh"
      user     = "azureuser"
      password = file("/Users/kunjbhuva/id_rsa")
      host     = azurerm_public_ip.public_ip.ip_address
    }
  }

  depends_on = [
    azurerm_network_interface_security_group_association.nic_nsg,
    azurerm_public_ip.public_ip
  ]
}

