terraform {
  required_version = ">=1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }

  # ELIMINA completamente la sección backend o coméntala
  # backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "main" {
  name = "Challenge"
}

resource "azurerm_service_plan" "main" {
  name                = "challenge-plan"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "main" {
  name                = "challenge-app"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    application_stack {
      docker_image     = "challenge.azurecr.io/challenge"
      docker_image_tag = var.docker_tag
    }
    always_on = false
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "DOCKER_REGISTRY_SERVER_URL"          = "https://challenge.azurecr.io"
    "DOCKER_REGISTRY_SERVER_USERNAME"     = var.acr_username
    "DOCKER_REGISTRY_SERVER_PASSWORD"     = var.acr_password
  }

  identity {
    type = "SystemAssigned"
  }
}

output "app_url" {
  value = "https://${azurerm_linux_web_app.main.default_hostname}"
}