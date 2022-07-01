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
  auth_url    = "https://iam.eu-de.otc.t-systems.com/v3"
}

resource "opentelekomcloud_vpc_v1" "network_1" {
  name = "network_1"
  cidr = "10.0.10.0/24"
}

resource "opentelekomcloud_vpc_subnet_v1" "subnet_1" {
  name       = "subnet_1"
  cidr       = "10.0.10.0/24"
  vpc_id     = opentelekomcloud_vpc_v1.network_1.id
  gateway_ip = "10.0.10.1"
}
