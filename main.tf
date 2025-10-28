terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.environment}-${var.app_name}"
  location = var.location
}

# Container Registry (usar uno existente)
data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group
}

# Application Insights para monitoreo
resource "azurerm_application_insights" "app_insights" {
  name                = "ai-${var.environment}-${var.app_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
}

# API Management con JWT
resource "azurerm_api_management" "apim" {
  name                = "apim-${var.environment}-${var.app_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = "DevOps Team"
  publisher_email     = "team@devops.com"
  sku_name            = var.environment == "prod" ? "Developer_1" : "Consumption_0" # Plan más económico para dev

  policy {
    xml_content = file("${path.module}/policies/jwt-validate.xml")
  }
}

# WEB APP DEPLOYMENT (Development)
resource "azurerm_service_plan" "app" {
  count               = var.deployment_target == "webapp" ? 1 : 0
  name                = "asp-${var.environment}-${var.app_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "B1"  # Plan básico económico
}

resource "azurerm_linux_web_app" "app" {
  count               = var.deployment_target == "webapp" ? 1 : 0
  name                = "app-${var.environment}-${var.app_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.app[0].id

  site_config {
    always_on        = false  # Ahorro de costos
    app_command_line = "dotnet Devops.Api.dll"
    health_check_path = "/health"
    
    application_stack {
      docker_image     = "${data.azurerm_container_registry.acr.login_server}/${var.docker_image}"
      docker_image_tag = var.docker_tag
    }
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.app_insights.instrumentation_key
    "DOCKER_REGISTRY_SERVER_URL"     = data.azurerm_container_registry.acr.login_server
    "ASPNETCORE_ENVIRONMENT"         = var.environment
    "JWT_SECRET"                     = var.jwt_secret
  }

  # Auto-scaling para Web App
  dynamic "logs" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      application_logs {
        file_system_level = "Information"
      }
    }
  }
}

# AKS CLUSTER ECONÓMICO (Production)
resource "azurerm_kubernetes_cluster" "aks" {
  count               = var.deployment_target == "aks" ? 1 : 0
  name                = "aks-${var.environment}-${var.app_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-${var.environment}"
  kubernetes_version  = "1.27"  # Versión estable

  # Configuración económica: System Node Pool pequeño
  default_node_pool {
    name                = "systempool"
    node_count          = 1  # Mínimo para sistema
    vm_size             = "Standard_B2s"  # VM más económica
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = false
  }

  # User Node Pool para la aplicación
  resource "azurerm_kubernetes_cluster_node_pool" "user" {
    count                 = var.deployment_target == "aks" ? 1 : 0
    name                  = "userpool"
    kubernetes_cluster_id = azurerm_kubernetes_cluster.aks[0].id
    vm_size               = "Standard_B2s"  # VM económica
    node_count            = 2  # Mínimo 2 nodos para balanceo
    enable_auto_scaling   = true
    min_count            = 2
    max_count            = 3   # Máximo económico
    os_type              = "Linux"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"  # Más económico que Azure CNI
    load_balancer_sku = "basic" # Load balancer básico
  }

  # Auto-scaling del cluster
  automatic_channel_upgrade = "patch"

  tags = {
    Environment = var.environment
    CostCenter  = "DevOps"
  }
}

# Kubernetes Provider
provider "kubernetes" {
  host = var.deployment_target == "aks" ? azurerm_kubernetes_cluster.aks[0].kube_config[0].host : ""
  client_certificate = var.deployment_target == "aks" ? base64decode(azurerm_kubernetes_cluster.aks[0].kube_config[0].client_certificate) : ""
  client_key = var.deployment_target == "aks" ? base64decode(azurerm_kubernetes_cluster.aks[0].kube_config[0].client_key) : ""
  cluster_ca_certificate = var.deployment_target == "aks" ? base64decode(azurerm_kubernetes_cluster.aks[0].kube_config[0].cluster_ca_certificate) : ""
}

# Kubernetes Deployment con Auto-scaling
resource "kubernetes_deployment" "app" {
  count = var.deployment_target == "aks" ? 1 : 0
  
  metadata {
    name = "devops-api"
    labels = {
      app = "devops-api"
    }
  }

  spec {
    replicas = 2  # Mínimo 2 réplicas para alta disponibilidad

    selector {
      match_labels = {
        app = "devops-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "devops-api"
        }
      }

      spec {
        container {
          image = "${data.azurerm_container_registry.acr.login_server}/${var.docker_image}:${var.docker_tag}"
          name  = "devops-api"

          ports {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          env {
            name  = "ASPNETCORE_ENVIRONMENT"
            value = var.environment
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 80
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

# Horizontal Pod Autoscaler para escalabilidad dinámica
resource "kubernetes_horizontal_pod_autoscaler" "app" {
  count = var.deployment_target == "aks" ? 1 : 0
  
  metadata {
    name = "devops-api-hpa"
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.app[0].metadata[0].name
    }

    min_replicas = 2
    max_replicas = 5

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 50
        }
      }
    }
  }
}

# Load Balancer Service
resource "kubernetes_service" "app" {
  count = var.deployment_target == "aks" ? 1 : 0
  
  metadata {
    name = "devops-api-service"
  }

  spec {
    selector = {
      app = "devops-api"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

# API Management API
resource "azurerm_api_management_api" "main" {
  name                = "devops-api"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "DevOps API"
  path                = "api"
  protocols           = ["https"]

  import {
    content_format = "openapi"
    content_value  = file("${path.module}/api-spec/openapi.json")
  }
}