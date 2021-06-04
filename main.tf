terraform {
  backend "azurerm" {
    storage_account_name  = "terraformstate1994"
    container_name        = "terraformstate"
    key                   = "storage.terraform.tfstate"
  }
}

provider "azurerm" { 
  version = "~>2.0"
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "linuxserver"
  location = "East US"
}

resource "azurerm_storage_account" "sa" {
  name                     = "linuxvmstorageacct"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "linuxvm"
  }
}

resource "azurerm_public_ip" "pip" {
  name                = "linuxvmpublicip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "linuxvm"
  }   

}

resource "azurerm_ssh_public_key" "sshkey" {
  name                = "linuxserver-key"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "East US"
  public_key          = file("~/.ssh/id_rsa.pub")
}

resource "azurerm_network_security_group" "nsg" {
  name                = "linuxvmSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges     = ["22", "80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_virtual_network" "vn" {
  name                = "linux-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet {
    name           = "subnetforvm"
    address_prefix = "10.0.1.0/24"
  }
}

resource "azurerm_subnet" "sub" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vn.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "ni" {
  name                = "linuxvm-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    public_ip_address_id          = azurerm_public_ip.pip.id
    subnet_id                     = azurerm_subnet.sub.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "lvm" {
  name                = "linux-testserver"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1S"
  admin_username      = "sudoer"
  network_interface_ids = [
    azurerm_network_interface.ni.id,
  ]

  admin_ssh_key {
    username   = "sudoer"
    public_key = azurerm_ssh_public_key.sshkey.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}