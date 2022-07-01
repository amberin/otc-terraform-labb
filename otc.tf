terraform {
  required_providers {
    opentelekomcloud = {
      source = "opentelekomcloud/opentelekomcloud"
      version = "1.29.8"
    }
  }
}

provider "opentelekomcloud" {
  user_name   = var.user_name
  access_key  = var.access_key
  secret_key  = var.secret_key
  tenant_name = "eu-de_test"
#  domain_name = "???"
  auth_url    = "https://iam.eu-de.otc.t-systems.com/v3"
}

resource "opentelekomcloud_networking_network_v2" "network_1" {
  name           = "network_1"
  admin_state_up = "true"
}

resource "opentelekomcloud_networking_subnet_v2" "subnet_1" {
  name       = "subnet_1"
  network_id = opentelekomcloud_networking_network_v2.network_1.id
  cidr       = "10.0.0.0/24"
  ip_version = 4
}
