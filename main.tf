# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "homework_rg" {
  name     = "guranteed-rate-homework"
  location = "westus2"
}

resource "azurerm_virtual_network" "homework_vnet" {
  name                = "homework-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.homework_rg.location
  resource_group_name = azurerm_resource_group.homework_rg.name
}

resource "azurerm_subnet" "homework_subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.homework_rg.name
  virtual_network_name = azurerm_virtual_network.homework_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "homework_network_interface" {
  name                = "homework-nic"
  location            = azurerm_resource_group.homework_rg.location
  resource_group_name = azurerm_resource_group.homework_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.homework_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.homework_ip.id
  }
}

resource "azurerm_network_security_group" "homework_security" {
  name                = "homework-security-group"
  location            = azurerm_resource_group.homework_rg.location
  resource_group_name = azurerm_resource_group.homework_rg.name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "http"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "denyInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "homework_network_security_association" {
  network_interface_id      = azurerm_network_interface.homework_network_interface.id
  network_security_group_id = azurerm_network_security_group.homework_security.id
}

resource "azurerm_public_ip" "homework_ip" {
  name                = "homework-ip"
  resource_group_name = azurerm_resource_group.homework_rg.name
  location            = azurerm_resource_group.homework_rg.location
  allocation_method   = "Static"
}

resource "azurerm_linux_virtual_machine" "homework_machine" {
  name                = "homework-machine"
  resource_group_name = azurerm_resource_group.homework_rg.name
  location            = azurerm_resource_group.homework_rg.location
  size                = "Standard_B1ls" # there is no "free tier" in azure as specified in homework, this is simply a very inexpensive one
  admin_username      = "adminuser"
  # admin_password                  = # REDACTED -- SSH keys are a better option 
  disable_password_authentication = false
  custom_data                     = base64encode(data.local_file.cloudinit.content)

  network_interface_ids = [
    azurerm_network_interface.homework_network_interface.id,
  ]

  os_disk {
    caching              = "None"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

data "local_file" "cloudinit" {
  filename = "${path.module}/cloud-init.conf"
}

resource "azurerm_managed_disk" "homework_disk" {
  name                 = "${azurerm_linux_virtual_machine.homework_machine.name}-disk1"
  location             = azurerm_resource_group.homework_rg.location
  resource_group_name  = azurerm_resource_group.homework_rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 1
}

resource "azurerm_virtual_machine_data_disk_attachment" "homework_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.homework_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.homework_machine.id
  lun                = "10"
  caching            = "ReadWrite"
}
