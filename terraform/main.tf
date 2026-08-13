# Provisionnement automatique de l'infrastructure AFI sur Azure (AKS + ACR)
# Usage : terraform init && terraform plan && terraform apply (avec creds Azure)
# État distant conseillé : terraform/backend.tf (Storage Account) — à décommenter

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "azurerm" {
    # Décommenter pour l'état à distance (Azure Storage)
    # resource_group_name  = "rg-afi-terraform"
    # storage_account_name = "afitfstate"
    # container_name       = "tfstate"
    # key                  = "afi-backend.tfstate"
  }
}

provider "azurerm" {
  features {}
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# --- Groupe de ressources ---
resource "azurerm_resource_group" "main" {
  name     = var.resource_group
  location = var.location
  tags     = { project = "afi" }
}

# --- Registre de conteneurs (images Docker du CD) ---
resource "azurerm_container_registry" "acr" {
  name                = "afiacr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

# --- Cluster Kubernetes managé (AKS) ---
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "afi-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "afi"

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  tags = { project = "afi" }
}

# --- Accès AKS -> ACR (pull des images) ---
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# --- Base managée PostgreSQL ---
resource "azurerm_postgresql_flexible_server" "db" {
  name                   = "afi-pgsql-${random_string.suffix.result}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "15"
  administrator_login    = var.db_admin
  administrator_password = var.db_password
  sku_name               = "B_Standard_B1ms"
  storage_mb             = 32768
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = "afi_db"
  server_id = azurerm_postgresql_flexible_server.db.id
}