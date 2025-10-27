variable "docker_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "acr_username" {
  description = "ACR username"
  type        = string
  sensitive   = true
}

variable "acr_password" {
  description = "ACR password"
  type        = string
  sensitive   = true
}