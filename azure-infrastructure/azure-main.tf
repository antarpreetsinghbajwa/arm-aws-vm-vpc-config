# ==============================================================================
# BLOCK 1: AZURE PROVIDER CONFIGURATION
# ==============================================================================
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0" # Using the stable 3.x Azure provider
    }
  }
}

# Tells Terraform to use your active 'az login' credentials
provider "azurerm" {
  features {}
}

# ==============================================================================
# BLOCK 2: THE RESOURCE GROUP (The Container)
# ==============================================================================
# In Azure, every single resource must belong to a Resource Group. 
# If you delete the Resource Group, it deletes everything inside it automatically.
resource "azurerm_resource_group" "p46_rg" {
  name     = "p46-azure-range"
  location = "East US" # Deploying to Virginia to stay close to your AWS servers
}

# ==============================================================================
# BLOCK 3: AZURE VIRTUAL NETWORK (VNet) & SUBNET
# ==============================================================================
resource "azurerm_virtual_network" "vnet" {
  name                = "p46-azure-vnet"
  address_space       = ["10.1.0.0/16"] # Notice this is 10.1.x.x so it doesn't overlap with AWS (10.0.x.x)
  location            = azurerm_resource_group.p46_rg.location
  resource_group_name = azurerm_resource_group.p46_rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "p46-azure-subnet"
  resource_group_name  = azurerm_resource_group.p46_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

# ==============================================================================
# BLOCK 4: NETWORK INTERFACE CARD (NIC)
# ==============================================================================
# Azure requires you to build the "network card" separately before attaching it to a VM.
resource "azurerm_network_interface" "nic" {
  name                = "p46-azure-nic01"
  location            = azurerm_resource_group.p46_rg.location
  resource_group_name = azurerm_resource_group.p46_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# ==============================================================================
# BLOCK 5: WINDOWS VIRTUAL MACHINE PROVISIONING
# ==============================================================================
resource "azurerm_windows_virtual_machine" "vm" {
  name                = "p46-az-dc03" # Naming this DC03 to act as an Azure backup controller later
  resource_group_name = azurerm_resource_group.p46_rg.name
  location            = azurerm_resource_group.p46_rg.location
  size                = "Standard_B2s" # 2 vCPUs, 4GB RAM (Cost-effective Azure size)
  
  # Azure requires a username and complex password to deploy Windows
  admin_username      = "p46admin"
  admin_password      = "P@ssw0rd1234_Azure!" # (For training only. In production, this goes in a secure variable)
  
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