terraform {
    required_providers {
        azurerm = {
            source  = "hashicorp/azurerm"
            version = ">=3.71.0"
        }
    }

    backend "azurerm" {
        features = {}
        # Injected by Github Actions
    }
}

provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "rg" {
  name                  = format("rg-%s", var.name_stub)
  location              = var.azure_region
}

resource "azurerm_log_analytics_workspace" "loganalytics" {
  name                  = format("la-%s", var.name_stub)
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  sku                   = "PerGB2018"
  retention_in_days     = 30
}

resource "azurerm_container_registry" "container_registry" {
  name                        = replace(format("acr-%s", var.name_stub), "-", "")
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  sku                         = "Basic"
}

resource "azurerm_container_app_environment" "container_app_environment" {
  name                        = format("cap-%s", var.name_stub)
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  log_analytics_workspace_id  = azurerm_log_analytics_workspace.loganalytics.id
}

resource "azurerm_user_assigned_identity" "containerapp_identity" {
  location                      = azurerm_resource_group.rg.location
  name                          = format("mi-%s", azurerm_container_app.containerapp.name)
  resource_group_name           = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "containerapp_role_assignment" {
  scope                         = azurerm_container_app.containerapp.id
  role_definition_name          = "acrpull"
  principal_id                  = azurerm_user_assigned_identity.containerapp_identity.principal_id
  depends_on = [ azurerm_user_assigned_identity.containerapp_identity ]
}

resource "azurerm_container_app" "containerapp" {
  name                          = format("aca-%s", var.name_stub)
  container_app_environment_id  = azurerm_container_app_environment.container_app_environment.id
  resource_group_name           = azurerm_resource_group.rg.name
  revision_mode                 = "Single"

  identity {
    type                        = "UserAssigned"
    identity_ids                = [ azurerm_user_assigned_identity.containerapp_identity.id ]
  }

  registry {
    server                      = azurerm_container_registry.container_registry.login_server
    identity                    = azurerm_user_assigned_identity.containerapp_identity.id
  }   

  template {
    container {
      name                      = replace(format("cnt-%s-1", var.name_stub), "-", "")
      image                     = format("%s.azurecr.io/infademo:latest", azurerm_container_registry.container_registry.name)
      cpu                       = 0.25
      memory                    = "0.5Gi"
    }
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = format("vnet-%s", var.name_stub)
  address_space       = ["10.0.0.0/16"]
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet_asp1" {
  name                 = format("subnet-%s", var.name_stub)
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/28"] # 10.0.1.0 - 10.0.1.15
}
