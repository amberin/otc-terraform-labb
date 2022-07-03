terraform {
  required_providers {
    opentelekomcloud = {
      source = "opentelekomcloud/opentelekomcloud"
      version = "1.29.8"
    }
  }
  backend "s3" {
    endpoint                    = "obs.eu-de.otc.t-systems.com"
    region                      = "eu-de"
    bucket                      = "victortfstate" # name of OBS bucket
    key                         = "statefile"     # statefile filename in OBS bucket
    skip_region_validation      = true
    skip_credentials_validation = true
  }
}

provider "opentelekomcloud" {
  user_name   = "terraform-test"
  access_key  = var.otc_access_key
  secret_key  = var.otc_secret_key
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
