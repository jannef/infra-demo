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
    name     = "rg-safsafsafsafasf-asdsadasdasd"
    location = "East US"
}
