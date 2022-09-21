variable "my_username" {
  description = "OTC human user name"
  type        = string
}
variable "my_access_key" {
  description = "Access key for human user"
  type        = string
}
variable "my_secret_key" {
  description = "Secret key for human user"
  type        = string
  sensitive   = true
}
#variable "system_account_ak" {
#  description = "Access key for OTC system account (otc-dev, otc-prod)"
#  type        = string
#}
#variable "system_account_sk" {
#  description = "Secret key for OTC system account (otc-dev, otc-prod)"
#  type        = string
#  sensitive   = true
#}
#variable "eventstore_vm_admin_pw" {
#  description = "Password for 'ubuntu' account on EventStore VMs"
#  type        = string
#  sensitive   = true
#}
#variable "mysql_root_pw" {
#  description = "Password for 'root' account in MySQL"
#  type        = string
#  sensitive   = true
#}
