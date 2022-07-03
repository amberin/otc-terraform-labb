variable "otc_access_key" {
  description = "Access key for OTC user"
  type        = string
}
variable "otc_secret_key" {
  description = "Secret key for OTC user"
  type        = string
  sensitive   = true
}
