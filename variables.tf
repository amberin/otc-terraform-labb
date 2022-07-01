variable "user_name" {
  description = "Login name for the OTC Terraform provider"
  type        = string
}

variable "access_key" {
  description = "Access key for var.user_name"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Secret key for var.user_name"
  type        = string
  sensitive   = true
}
