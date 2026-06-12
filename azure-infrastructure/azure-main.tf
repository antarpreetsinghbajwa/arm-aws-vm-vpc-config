# 1. Terraform Configuration and Remote Cloud Backend
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "p46-terraform-state-rg"
    storage_account_name = "p46aztfstate9988"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

# 2. Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# 3. Create a Logical Resource Group Container
resource "azurerm_resource_group" "p46_rg" {
  name     = "p46-azure-range"
  location = "eastus"
}

# 4. Create the Virtual Network (VNet)
resource "azurerm_virtual_network" "vnet" {
  name                = "p46-azure-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.p46_rg.location
  resource_group_name = azurerm_resource_group.p46_rg.name
}

# 5. Create an Isolated Subnet inside the VNet
resource "azurerm_subnet" "subnet" {
  name                 = "p46-azure-subnet"
  resource_group_name  = azurerm_resource_group.p46_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

# 6. Create a Public IP Address for Remote Access
resource "azurerm_public_ip" "public_ip" {
  name                = "p46-azure-pip"
  location            = azurerm_resource_group.p46_rg.location
  resource_group_name = azurerm_resource_group.p46_rg.name
  sku                 = "Standard"
  allocation_method   = "Static"
}

# 7. Create a Network Security Group (Firewall)
resource "azurerm_network_security_group" "nsg" {
  name                = "p46-azure-nsg"
  location            = azurerm_resource_group.p46_rg.location
  resource_group_name = azurerm_resource_group.p46_rg.name

  # Security Rule to allow Remote Desktop Protocol (RDP)
  security_rule {
    name                       = "Allow-RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*" # Note: Allows any IP for lab purposes
    destination_address_prefix = "*"
  }
}

# 8. Create the Network Interface Card (NIC)
resource "azurerm_network_interface" "nic" {
  name                = "p46-azure-nic01"
  location            = azurerm_resource_group.p46_rg.location
  resource_group_name = azurerm_resource_group.p46_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# 9. Associate the Firewall with the Network Interface
resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 10. Create the Windows Server 2022 Virtual Machine
resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "p46-az-dc03"
  resource_group_name   = azurerm_resource_group.p46_rg.name
  location              = azurerm_resource_group.p46_rg.location
  size                  = "Standard_D2s_v3"
  admin_username        = "adminuser"
  admin_password        = "P@ssw0rd12345!"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# 11. Output the Public IP Address
output "windows_server_public_ip" {
  description = "The public IP address to use for Remote Desktop (RDP)"
  value       = azurerm_public_ip.public_ip.ip_address
}
