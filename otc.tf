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
  user_name   = "terraform-${terraform.workspace}"
  access_key  = var.otc_access_key
  secret_key  = var.otc_secret_key
  tenant_name = "eu-de_${terraform.workspace}" # This is the project name (renamed in the v3 API)
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

resource "opentelekomcloud_cce_cluster_v3" "cluster1" {
  name        = "cluster1"
  description = "My toy cluster"

  cluster_type           = "VirtualMachine"
  flavor_id              = "cce.s1.small"
  vpc_id                 = opentelekomcloud_vpc_v1.network_1.id
  subnet_id              = opentelekomcloud_vpc_subnet_v1.subnet_1.id
  container_network_type = "overlay_l2"
  authentication_mode    = "rbac"
}
