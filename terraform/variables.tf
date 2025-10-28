variable "environment" {
  description = "Environment name"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "devopsapi"
}

variable "deployment_target" {
  description = "Target deployment: webapp or aks"
  type        = string
}

variable "docker_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "acr_name" {
  description = "ACR name"
  type        = string
}

variable "acr_resource_group" {
  description = "ACR resource group"
  type        = string
}

variable "docker_image" {
  description = "Docker image name"
  type        = string
  default     = "devops-api"
}

variable "jwt_secret" {
  description = "JWT secret key"
  type        = string
  sensitive   = true
}